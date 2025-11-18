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

find_overlay_lower_dir() {
    overlay="$1"
    overlay_rel=${overlay#/}
    if [ -z "${overlay_rel}" ]; then
        return 1
    fi

    pattern="/overlay/${overlay_rel}/lower"
    legacy_pattern="/overlay//${overlay_rel}/lower"

    while IFS=" " read -r _ target _ _ _ _; do
        [ -z "${target}" ] && continue
        mountpoint=$(printf '%b' "${target}")
        case "${mountpoint}" in
            *"${pattern}"|*"${legacy_pattern}")
                if [ -d "${mountpoint}" ]; then
                    printf '%s\n' "${mountpoint}"
                    return 0
                fi
                ;;
        esac
    done < /proc/self/mounts

    for base in /data /mnt/data /persist /mnt/persist; do
        lower="${base}/overlay/${overlay_rel}/lower"
        if [ -d "${lower}" ]; then
            printf '%s\n' "${lower}"
            return 0
        fi

        legacy="${base}/overlay//${overlay_rel}/lower"
        if [ -d "${legacy}" ]; then
            printf '%s\n' "${legacy}"
            return 0
        fi
    done

    return 1
}

restore_status_from_exposed_lower() {
    lower_dir=$(find_overlay_lower_dir "/var" 2>/dev/null || true)
    if [ -z "${lower_dir}" ]; then
        return 1
    fi

    lower_status="${lower_dir}/lib/opkg/status"
    if [ ! -f "${lower_status}" ]; then
        return 1
    fi

    CURRENT_IMAGE_STATUS="${lower_status}"
    log "using base image status from exposed overlay ${CURRENT_IMAGE_STATUS}"
    return 0
}

# When upgrading from images that did not yet provide a split status file, we
# have to reconstruct /var/lib/opkg/status.image from the lower (read-only)
# rootfs so we can safely distinguish overlay packages.
reconstruct_current_image_status() {
    if restore_status_from_exposed_lower; then
        return 0
    fi

    lowerdir=$(awk '$2=="/" && $3=="overlay" { if (match($0, /lowerdir=([^ ,]+)/, m)) { print m[1]; exit } }' /proc/self/mounts || true)
    lowerdir=${lowerdir%%:*}
    if [ -z "${lowerdir}" ]; then
        return 1
    fi

    lower_status="${lowerdir}/var/lib/opkg/status"
    if [ ! -f "${lower_status}" ]; then
        return 1
    fi

    CURRENT_IMAGE_STATUS="${lower_status}"
    log "using base image status from ${CURRENT_IMAGE_STATUS}"
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
    if reconstruct_current_image_status; then
        status_normalized=1
    else
        log "could not reconstruct ${CURRENT_IMAGE_STATUS}; skipping duplicate removal"
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
