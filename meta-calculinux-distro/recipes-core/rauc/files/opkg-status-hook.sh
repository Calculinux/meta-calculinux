#!/bin/sh
set -eu

log() {
    echo "opkg-status-hook: $*" >&2
}

HOOK=${1:-}
SLOT=${2:-}

# Only run after RAUC finishes writing a new rootfs slot.
if [ "${HOOK}" != "slot-post-install" ]; then
    exit 0
fi

# Ignore hooks for other slot classes like bootloaders.
if [ "${RAUC_SLOT_CLASS:-}" != "rootfs" ]; then
    exit 0
fi

MOUNT_POINT=${RAUC_SLOT_MOUNT_POINT:-}
if [ -z "${MOUNT_POINT}" ]; then
    log "RAUC_SLOT_MOUNT_POINT not provided for slot ${SLOT}"
    exit 0
fi

# Snapshot lives inside the freshly installed slot; writable file is on the
# running system.
IMAGE_STATUS_FILE="${MOUNT_POINT}/var/lib/opkg/status.image"
WRITABLE_STATUS_FILE="/var/lib/opkg/status"
CURRENT_IMAGE_STATUS="/var/lib/opkg/status.image"
PENDING_REINSTALL_FILE="/var/lib/opkg/opkg-status-hook.pending-reinstalls"
PENDING_UPGRADE_FILE="/var/lib/opkg/opkg-status-hook.pending-upgrades"

if [ ! -f "${IMAGE_STATUS_FILE}" ]; then
    log "image status file ${IMAGE_STATUS_FILE} not found for slot ${SLOT}"
    exit 0
fi

if [ ! -f "${WRITABLE_STATUS_FILE}" ]; then
    log "writable status file ${WRITABLE_STATUS_FILE} missing, skipping"
    exit 0
fi

CURRENT_IMAGE_STATUS_COPY=""

find_booted_slot_device() {
    command -v rauc >/dev/null 2>&1 || return 1

    if ! status_output=$(rauc status --output-format=shell 2>/dev/null); then
        return 1
    fi

    eval "${status_output}"

    state1=${RAUC_SLOT_STATE_1:-}
    state2=${RAUC_SLOT_STATE_2:-}

    device=""
    if [ "${state1}" = "booted" ]; then
        device=${RAUC_SLOT_DEVICE_1}
    elif [ "${state2}" = "booted" ]; then
        device=${RAUC_SLOT_DEVICE_2}
    else
        return 1
    fi

    printf '%s\n' "${device}"
    return 0
}

snapshot_current_image_status() {
    device=$(find_booted_slot_device || true)

    if [ -z "${device}" ]; then
        return 1
    fi

    mount_dir=$(mktemp -d /tmp/opkg-slot-mount.XXXXXX)
    if ! mount -o ro "${device}" "${mount_dir}" 2>/dev/null; then
        rmdir "${mount_dir}"
        return 1
    fi

    lower_status="${mount_dir}/var/lib/opkg/status"
    if [ ! -f "${lower_status}" ]; then
        umount "${mount_dir}" >/dev/null 2>&1 || true
        rmdir "${mount_dir}"
        return 1
    fi

    tmp_copy=$(mktemp /tmp/opkg-status-current.XXXXXX)
    if ! cp "${lower_status}" "${tmp_copy}"; then
        rm -f "${tmp_copy}"
        umount "${mount_dir}" >/dev/null 2>&1 || true
        rmdir "${mount_dir}"
        return 1
    fi

    umount "${mount_dir}" >/dev/null 2>&1 || true
    rmdir "${mount_dir}"

    CURRENT_IMAGE_STATUS="${tmp_copy}"
    CURRENT_IMAGE_STATUS_COPY="${tmp_copy}"
    log "copied base image status from ${device}"
    return 0
}

prune_writable_status_against_image() {
    tmp_status=$(mktemp /tmp/opkg-status-writable.XXXXXX)
    awk -v image="${CURRENT_IMAGE_STATUS}" '
BEGIN {
    RS="";
    FS="\n";
    while ((getline line < image) > 0) {
        if (substr(line, 1, 9) == "Package: ") {
            pkg = substr(line, 10);
            sub(/\r$/, "", pkg);
            imagepkgs[pkg] = 1;
        }
    }
    close(image);
}
{
    keep = 1;
    pkg = "";
    for (i = 1; i <= NF; i++) {
        if (substr($i, 1, 9) == "Package: ") {
            pkg = substr($i, 10);
            sub(/\r$/, "", pkg);
            break;
        }
    }
    if (pkg != "" && (pkg in imagepkgs)) {
        keep = 0;
    }
    if (keep) {
        print $0 "\n";
    }
}
' "${WRITABLE_STATUS_FILE}" > "${tmp_status}"

    if ! cmp -s "${tmp_status}" "${WRITABLE_STATUS_FILE}"; then
        mv "${tmp_status}" "${WRITABLE_STATUS_FILE}"
        log "pruned writable status to drop packages provided by the base image"
    else
        rm -f "${tmp_status}"
    fi
}

status_normalized=0
if [ ! -f "${CURRENT_IMAGE_STATUS}" ]; then
    if snapshot_current_image_status; then
        status_normalized=1
    else
        log "could not snapshot current slot status; skipping duplicate removal"
    fi
else
    status_normalized=1
fi

if [ "${status_normalized}" -eq 1 ]; then
    prune_writable_status_against_image || log "warning: failed to prune writable status"
else
    exit 0
fi

# Temporary file that lists packages duplicated between writable and image layers.
dups_file=$(mktemp /tmp/opkg-status-duplicates.XXXXXX)
tmp_missing=""
tmp_upgrade=""
cleanup() {
    rm -f "${dups_file}"
    [ -n "${tmp_missing}" ] && rm -f "${tmp_missing}"
    [ -n "${tmp_upgrade}" ] && rm -f "${tmp_upgrade}"
    [ -n "${CURRENT_IMAGE_STATUS_COPY}" ] && rm -f "${CURRENT_IMAGE_STATUS_COPY}"
}
trap cleanup EXIT INT TERM

# First, figure out which packages exist both in the writable layer and the
# immutable snapshot; these are the ones we need to uninstall so they stop
# shadowing the version shipped inside the new image.
awk -v image="${IMAGE_STATUS_FILE}" '
BEGIN {
    RS="";
    FS="\n";
    while ((getline line < image) > 0) {
        if (substr(line, 1, 9) == "Package: ") {
            pkg = substr(line, 10);
            sub(/\r$/, "", pkg);
            imagepkgs[pkg] = 1;
        }
    }
    close(image);
}
{
    pkg="";
    for (i = 1; i <= NF; i++) {
        if (substr($i, 1, 9) == "Package: ") {
            pkg = substr($i, 10);
            sub(/\r$/, "", pkg);
            break;
        }
    }
    if (pkg != "" && (pkg in imagepkgs)) {
        print pkg;
    }
}
' "${WRITABLE_STATUS_FILE}" | sort -u > "${dups_file}"

if [ -s "${dups_file}" ]; then
    while IFS= read -r pkg; do
        log "removing package ${pkg} from writable rootfs overlay"
        if ! opkg remove --nodeps "${pkg}"; then
            log "warning: failed to remove ${pkg}; continuing"
        fi
    done < "${dups_file}"
fi

log "removed duplicate packages shadowing base image contents"

# Figure out which packages disappeared from the new image compared to the
# currently running slot and queue reinstalls so they remain available after
# reboot. Skip packages that are already installed in the writable layer.
tmp_missing=$(mktemp /tmp/opkg-status-missing.XXXXXX)
awk -v old_image="${CURRENT_IMAGE_STATUS}" \
    -v new_image="${IMAGE_STATUS_FILE}" \
    -v writable="${WRITABLE_STATUS_FILE}" '
BEGIN {
    RS="";
    FS="\n";
    while ((getline line < new_image) > 0) {
        if (substr(line, 1, 9) == "Package: ") {
            pkg = substr(line, 10);
            sub(/\r$/, "", pkg);
            newpkgs[pkg] = 1;
        }
    }
    close(new_image);

    while ((getline line < writable) > 0) {
        if (substr(line, 1, 9) == "Package: ") {
            pkg = substr(line, 10);
            sub(/\r$/, "", pkg);
            writablepkgs[pkg] = 1;
        }
    }
    close(writable);

    while ((getline line < old_image) > 0) {
        if (substr(line, 1, 9) == "Package: ") {
            pkg = substr(line, 10);
            sub(/\r$/, "", pkg);
            if (!(pkg in newpkgs) && !(pkg in writablepkgs)) {
                missing[pkg] = 1;
            }
        }
    }
    close(old_image);

    for (pkg in missing) {
        print pkg;
    }
}
' | sort -u > "${tmp_missing}"

if [ -s "${tmp_missing}" ]; then
    mv "${tmp_missing}" "${PENDING_REINSTALL_FILE}"
    count=$(wc -l < "${PENDING_REINSTALL_FILE}" | tr -d ' \t')
    log "queued reinstall for ${count} packages removed from new image"
else
    rm -f "${tmp_missing}" "${PENDING_REINSTALL_FILE}"
    log "no packages need reinstall after image pruning"
fi

# Record all writable-layer packages so we can upgrade them after reboot to pick
# up dependency changes introduced by the new image.
tmp_upgrade=$(mktemp /tmp/opkg-status-upgrade.XXXXXX)
awk '
BEGIN {
    RS="";
    FS="\n";
}
{
    pkg="";
    for (i = 1; i <= NF; i++) {
        if (substr($i, 1, 9) == "Package: ") {
            pkg = substr($i, 10);
            sub(/\r$/, "", pkg);
            print pkg;
            break;
        }
    }
}
}' "${WRITABLE_STATUS_FILE}" | sort -u > "${tmp_upgrade}"

if [ -s "${tmp_upgrade}" ]; then
    mv "${tmp_upgrade}" "${PENDING_UPGRADE_FILE}"
    upgrade_count=$(wc -l < "${PENDING_UPGRADE_FILE}" | tr -d ' \t')
    log "queued upgrade for ${upgrade_count} writable-layer packages after reboot"
else
    rm -f "${tmp_upgrade}" "${PENDING_UPGRADE_FILE}"
    log "no writable-layer packages require post-reboot upgrade"
fi

exit 0
