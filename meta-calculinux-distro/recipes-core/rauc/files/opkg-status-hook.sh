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

if [ ! -f "${IMAGE_STATUS_FILE}" ]; then
    log "image status file ${IMAGE_STATUS_FILE} not found for slot ${SLOT}"
    exit 0
fi

if [ ! -f "${WRITABLE_STATUS_FILE}" ]; then
    log "writable status file ${WRITABLE_STATUS_FILE} missing, skipping"
    exit 0
fi

# Temporary files for filtered status output and duplicate list.
tmp_file=$(mktemp /tmp/opkg-status-filter.XXXXXX)
dups_file=$(mktemp /tmp/opkg-status-duplicates.XXXXXX)
cleanup() {
    rm -f "${tmp_file}" "${dups_file}"
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

# AWK reads *both* files: it slurps ${IMAGE_STATUS_FILE} first (via getline
# with an explicit filename) to build a set of "Package:" names shipped with
# the image, then it falls back to the implicit input (the writable status
# file passed on the command line) and emits only stanzas that are NOT in that
# set. That means the output contains exclusively user-installed packages.
awk -v image="${IMAGE_STATUS_FILE}" '
BEGIN {
    RS="";                  # treat blank-line-separated paragraphs as records
    FS="\n";                # but keep line structure to hunt for Package: headers

    # Read the immutable snapshot explicitly: "getline ... < image" reads from
    # the file whose path was passed in via -v image=..., independent of the
    # default stdin/ARGV stream. Once finished, we close() it so the AWK engine
    # will later consume the writable file supplied on the shell command line.
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

    # Only emit records whose package name was not part of the immutable
    # snapshot; this preserves the paragraph structure by printing an extra
    # blank line between stanzas.
    if (!(pkg in imagepkgs)) {
        print $0;
        print "";
    }
}
' "${WRITABLE_STATUS_FILE}" > "${tmp_file}"

# Replace the writable status only when the filtered view actually changed.
if ! cmp -s "${tmp_file}" "${WRITABLE_STATUS_FILE}"; then
    cat "${tmp_file}" > "${WRITABLE_STATUS_FILE}"
    sync || true
fi

log "removed duplicate packages from ${WRITABLE_STATUS_FILE} using ${IMAGE_STATUS_FILE}"
exit 0
