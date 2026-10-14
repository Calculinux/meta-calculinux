#!/bin/sh
# Handler for /usr/lib/udev/rules.d/99-calculinux-sdcard.rules.
#
# Invoked by systemd-udevd with a trimmed environment: ACTION, KERNEL,
# DEVNAME, ID_FS_* and friends arrive as variables. Diagnostic messages
# go to stderr, which systemd-udevd routes to the journal.
#
# The boot card is mmcblk0 (ROOT_A/ROOT_B/SWAP/OVERLAY_DATA, all
# load-bearing for preinit/RAUC/overlayfs); the external slot is
# mmcblk1. One fixed mountpoint, /run/media/sdcard: single external
# slot, and the read-only rootfs rules out creating /media entries at
# runtime (upstream QA likewise reserves /media for runtime population
# by a media manager).

PATH=/sbin:/usr/sbin:/bin:/usr/bin

MP=/run/media/sdcard
LOCKFILE=/run/calculinux-sdcard.lock

# Strip the partition suffix: mmcblk1p1 -> mmcblk1.
disk="${KERNEL%%p[0-9]*}"

case "${ACTION:-}" in
remove)
    # Detach whatever this slot may have mounted. Deliberately does not
    # consult /sys: by the whole-disk remove event the sysfs entry is
    # already gone, and the mountpoint is fixed anyway.
    if findmnt -rn --mountpoint "$MP" >/dev/null 2>&1; then
        sync
        # -l: the card is physically disappearing; drop the mount from
        # the namespace even if a process still holds fds. The kernel
        # releases the device when the last reference closes.
        umount -l "$MP" 2>/dev/null || umount -f "$MP" 2>/dev/null || true
    fi
    exit 0
    ;;
esac

[ "${ACTION:-}" = "add" ] || exit 0

# Additive-only gate: the card must be a removable one, so the boot card
# can never be caught here even if bus numbers shift on a future DTB.
[ "$(cat "/sys/block/${disk}/removable" 2>/dev/null)" = "1" ] || exit 0

# The partition must expose a mountable filesystem. Filters out swap,
# boot/EFI and encrypted partitions, and cards still blank or wiped.
[ "${ID_FS_USAGE:-}" = "filesystem" ] || exit 0
[ -n "${ID_FS_TYPE:-}" ] || exit 0

# Serialize overlapping add/remove events (reseats, uevent bursts).
exec 9>"$LOCKFILE" || exit 0
flock -n 9 || exit 0

# The mountpoint is on the /run tmpfs and does not pre-exist in the
# image; this handler is the thing that brings it into being.
[ -d "$MP" ] || mkdir -p "$MP" || {
    echo "calculinux-sdcard: cannot create $MP" >&2
    exit 1
}

if findmnt -rn --mountpoint "$MP" >/dev/null 2>&1; then
    exit 0
fi

case "$ID_FS_TYPE" in
ext2|ext3|ext4)
    # Fast auto-repair for cards that were pulled unclean. Refuse the
    # mount rather than carry a damaged filesystem into read-write use.
    if ! e2fsck -pf "${DEVNAME:?}" >/dev/null 2>&1; then
        echo "calculinux-sdcard: e2fsck failed on ${DEVNAME}, leaving unmounted" >&2
        exit 1
    fi
    ;;
esac

if mount -o noatime "${DEVNAME:?}" "$MP"; then
    echo "calculinux-sdcard: mounted ${DEVNAME} (${ID_FS_TYPE}) on $MP"
else
    echo "calculinux-sdcard: mount of ${DEVNAME} (${ID_FS_TYPE}) failed" >&2
    exit 1
fi
