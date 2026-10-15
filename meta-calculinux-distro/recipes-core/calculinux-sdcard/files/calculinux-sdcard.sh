#!/bin/sh
# Handler for the external SD card, invoked by the calculinux-sdcard@.
# template unit (see 99-calculinux-sdcard.rules):
#
#     calculinux-sdcard.sh mount   <kname>
#     calculinux-sdcard.sh unmount <kname>
#
# kname is the partition's kernel name (e.g. mmcblk1p1). The unit runs
# under systemd, so stdout/stderr goes to the journal directly.
#
# The boot card is mmcblk0 (ROOT_A/ROOT_B/SWAP/OVERLAY_DATA, all
# load-bearing for preinit/RAUC/overlayfs); the external slot is
# mmcblk1. One fixed mountpoint, /run/media/sdcard: single external
# slot, and the /run tmpfs admits a mountpoint that appears and
# disappears with the card (the read-only rootfs would not).
#
# mount:   probe -> (fsck for ext) -> mount, with takeover of a stale
#          mount of a previous card at the same path.
# unmount: only when the mount at the path is actually owned by the
#          device this instance handles, so a late remove uevent of
#          card A can never tear down a card B mount.

PATH=/sbin:/usr/sbin:/bin:/usr/bin
set -u

MP=/run/media/sdcard
LOCKFILE=/run/calculinux-sdcard.lock
MODE="${1:-}"
KNAME="${2:-}"

log() { echo "calculinux-sdcard: $*"; }

[ -n "$MODE" ] && [ -n "$KNAME" ] || {
    log "usage: calculinux-sdcard.sh <mount|unmount> <kname>" >&2
    exit 2
}

# Strip the partition suffix: mmcblk1p1 -> mmcblk1.
disk="${KNAME%%p[0-9]*}"

# Serialized per system, not per card: both modes touch the one
# mountpoint, and a remove of A can race an add of B.
exec 9>"$LOCKFILE" || { log "cannot open $LOCKFILE"; exit 1; }
flock -n 9 || { log "another handler instance holds the lock, skipping"; exit 0; }

case "$MODE" in
mount)
    dev="/dev/$KNAME"
    [ -b "$dev" ] || { log "$dev is not a block device, skipping"; exit 0; }

    # No /sys/block/<disk>/removable check here, on purpose: the kernel
    # MMC core never sets GENHD_FL_REMOVABLE for any mmcblk* device -
    # by design an MMC block device is a "permanent block device with
    # removable media", so the flag stays 0 for eMMC and SD cards alike
    # and the kernel steers userspace to the block add/remove hotplug
    # events instead. Presence is exactly what the udev rule tracks:
    # this unit only ever starts on the partition add uevent, and the
    # KERNEL=="mmcblk[1-9]p[0-9]*" match already keeps the boot card
    # (mmcblk0) out of this handler's reach.

    # Physical probe: the udev event environment does not reach the
    # service, so ask blkid directly. Filters out swap, boot/EFI and
    # encrypted partitions, and still-blank or wiped cards.
    fs_usage="$(blkid -p -o value -s USAGE "$dev" 2>/dev/null)"
    fs_type="$(blkid -p -o value -s TYPE "$dev" 2>/dev/null)"
    if [ "$fs_usage" != "filesystem" ] || [ -z "$fs_type" ]; then
        log "$dev has no mountable filesystem (usage='$fs_usage' type='$fs_type'), skipping"
        exit 0
    fi

    [ -d "$MP" ] || mkdir -p "$MP" || { log "cannot create $MP"; exit 1; }

    # Reconcile occupancy: this slot's cards share one path, so a
    # previous card's mount may still be there (late remove event, or
    # its ExecStop ran before this add). Take it over. Anything that
    # is not one of our own mmc mounts stays undisturbed.
    src="$(findmnt -n -r -o SOURCE --mountpoint "$MP" 2>/dev/null)"
    if [ -n "$src" ]; then
        case "$src" in
            /dev/mmcblk[1-9]*)
                sync
                umount -l "$MP" 2>/dev/null || true
                log "took over stale mount of $src at $MP"
                ;;
            *)
                log "$MP is mounted from $src (not ours), leaving it alone"
                exit 0
                ;;
        esac
    fi

    case "$fs_type" in
        ext2|ext3|ext4)
            # Fast auto-repair for cards pulled unclean. e2fsck(8) exit
            # codes: 0 clean, 1 or 2 errors were corrected (mountable),
            # anything higher means uncorrected/tool errors (refuse).
            e2fsck -pf "$dev" >/dev/null 2>&1
            rc=$?
            if [ "$rc" -gt 2 ]; then
                log "e2fsck on $dev failed (rc=$rc), leaving unmounted"
                exit 1
            fi
            ;;
    esac

    # nosuid/nodev: externally controlled media, keep the usual
    # removable-media restrictions in force.
    if mount -o noatime,nosuid,nodev "$dev" "$MP"; then
        log "mounted $dev ($fs_type) on $MP"
    else
        log "mount of $dev ($fs_type) failed"
        exit 1
    fi
    ;;

unmount)
    # Ownership-checked: only tear down a mount that belongs to this
    # partition (or its whole disk, in case a disk mount is in play).
    # A delayed remove of card A must not unmount card B at the same
    # path.
    src="$(findmnt -n -r -o SOURCE --mountpoint "$MP" 2>/dev/null)"
    case "$src" in
        "/dev/$KNAME"|"/dev/$disk")
            sync
            # -l: the card may be physically gone; drop the mount from
            # the namespace even if a process still holds fds. The
            # kernel releases the device when the last reference
            # closes.
            umount -l "$MP" 2>/dev/null || umount -f "$MP" 2>/dev/null || true
            log "unmounted $src from $MP"
            ;;
        "")
            : # nothing mounted here, nothing to do
            ;;
        *)
            log "$MP is mounted from $src, not from /dev/$KNAME - leaving it alone"
            ;;
    esac
    ;;

*)
    log "unknown mode '$MODE'" >&2
    exit 2
    ;;
esac
