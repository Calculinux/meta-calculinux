#!/bin/bash
# Self-check for RAUC-slot FIT naming, stamp policy, and invalidate-merged-fit.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=merge-dt-overlays-boot.sh
MERGE_DT_OVERLAYS_LIB=1
# The helper file is a bash script; `.` needs bash functions.
. "$DIR/merge-dt-overlays-boot.sh"

assert_eq() {
    [ "$1" = "$2" ] || { echo "FAIL: expected '$2' got '$1' ($3)" >&2; exit 1; }
}

assert_ok() {
    "$@" || { echo "FAIL: expected success: $*" >&2; exit 1; }
}

assert_fail() {
    if "$@"; then
        echo "FAIL: expected failure: $*" >&2
        exit 1
    fi
}

assert_eq "$(resolve_rauc_slot A '')" A "explicit A"
assert_eq "$(resolve_rauc_slot b '')" B "explicit b"
assert_eq "$(resolve_rauc_slot '' 'console=tty rauc.slot=B quiet')" B "cmdline B"
assert_eq "$(resolve_rauc_slot '' 'rauc.slot=A')" A "cmdline A"
assert_eq "$(resolve_rauc_slot '' '')" A "default A"
assert_eq "$(resolve_rauc_slot A 'rauc.slot=B')" A "explicit wins over cmdline"
assert_eq "$(merged_fit_name B '')" zboot_merged_b.img "name B"
assert_eq "$(merged_fit_name A '')" zboot_merged_a.img "name A"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
printf 'kernel\n' > "$tmpdir/k"
fit_kernel_stamp "$tmpdir/k" > "$tmpdir/s"
stamp_matches "$tmpdir/k" "$tmpdir/s" || { echo "FAIL: matching stamp" >&2; exit 1; }
printf 'other\n' > "$tmpdir/k2"
if stamp_matches "$tmpdir/k2" "$tmpdir/s"; then
    echo "FAIL: stamp should not match a different kernel" >&2
    exit 1
fi

# stamp_should_drop: match → keep (nonzero)
assert_fail stamp_should_drop "$tmpdir/k" "$tmpdir/s"
# mismatch → drop
assert_ok stamp_should_drop "$tmpdir/k2" "$tmpdir/s"
# missing stamp → drop
assert_ok stamp_should_drop "$tmpdir/k" "$tmpdir/missing.stamp"
# empty hash (nonexistent kernel) → keep (do not false-positive)
assert_fail stamp_should_drop "$tmpdir/no-such-kernel" "$tmpdir/s"

# invalidate-merged-fit: slot A via rootfs.0 / bootname env
INVALIDATE="$DIR/../../rauc/files/invalidate-merged-fit"
if [ ! -x "$INVALIDATE" ] && [ -f "$INVALIDATE" ]; then
    chmod +x "$INVALIDATE"
fi
if [ -f "$INVALIDATE" ]; then
    mkdir -p "$tmpdir/fit"
    touch "$tmpdir/fit/zboot_merged_a.img" "$tmpdir/fit/kernel-A.stamp" \
        "$tmpdir/fit/zboot_merged_b.img" "$tmpdir/fit/kernel-B.stamp"
    RAUC_TARGET_SLOTS=rootfs.0 \
        RAUC_SLOT_BOOTNAME_rootfs_0=A \
        DATA_FIT="$tmpdir/fit" \
        "$INVALIDATE"
    [ ! -e "$tmpdir/fit/zboot_merged_a.img" ] || { echo "FAIL: A FIT should be removed" >&2; exit 1; }
    [ ! -e "$tmpdir/fit/kernel-A.stamp" ] || { echo "FAIL: A stamp should be removed" >&2; exit 1; }
    [ -e "$tmpdir/fit/zboot_merged_b.img" ] || { echo "FAIL: B FIT should remain" >&2; exit 1; }
    [ -e "$tmpdir/fit/kernel-B.stamp" ] || { echo "FAIL: B stamp should remain" >&2; exit 1; }

    # empty slots → drop both
    touch "$tmpdir/fit/zboot_merged_a.img" "$tmpdir/fit/kernel-A.stamp"
    RAUC_TARGET_SLOTS= \
        DATA_FIT="$tmpdir/fit" \
        "$INVALIDATE"
    [ ! -e "$tmpdir/fit/zboot_merged_a.img" ] || { echo "FAIL: empty slots should drop A" >&2; exit 1; }
    [ ! -e "$tmpdir/fit/zboot_merged_b.img" ] || { echo "FAIL: empty slots should drop B" >&2; exit 1; }
else
    echo "WARN: invalidate-merged-fit not found at $INVALIDATE, skipped" >&2
fi

# ROOT-anchored inputs (issue #239): the RAUC post-install merge pairs the
# installed slot's kernel with its own .dtbo files; user-added overlays live
# on the persistent /data overlay layer and fall back to the live system.
SLOT_ROOT="$tmpdir/slot-root"
mkdir -p "$SLOT_ROOT/boot/devicetree"
printf 'placeholder-kernel\n' > "$SLOT_ROOT/boot/fit_kernel"
printf 'placeholder-dtb\n' > "$SLOT_ROOT/boot/fit_fdt.dtb"
printf 'KERNEL_LOAD_ADDR=0x00A00800\nFDT_LOAD_ADDR=0xA1000000\n' > "$SLOT_ROOT/boot/fit_loadaddr.env"
printf 'board-dtbo\n' > "$SLOT_ROOT/boot/devicetree/board.dtbo"
printf 'user-dtbo\n' > "$tmpdir/user.dtbo"

# Name lookup under ROOT prefers the fresh slot's copy (LIB-mode functions)
ROOT="$SLOT_ROOT"
assert_eq "$(resolve_overlay board)" "$SLOT_ROOT/boot/devicetree/board.dtbo" "ROOT-first name lookup"
# Absolute user file absent from the raw slot rootfs resolves from the live system
assert_eq "$(resolve_overlay "$tmpdir/user.dtbo")" "$tmpdir/user.dtbo" "live fallback for absolute user file"
# Outside ROOT the fresh-slot copy is not reachable
ROOT=""
assert_fail resolve_overlay board

# Full run with a config entry that exists nowhere: must fail by name,
# before packing, so no mkimage needed.
MERGE_SH="$DIR/merge-dt-overlays-boot.sh"
printf 'missing\n' > "$tmpdir/conf-anchor"
if out=$("$MERGE_SH" "$tmpdir/conf-anchor" "$tmpdir/out-data" A "$SLOT_ROOT" 2>&1); then
    echo "FAIL: overlay missing everywhere should fail" >&2
    exit 1
fi
case "$out" in
    *"overlay not found: missing"*) : ;;
    *) echo "FAIL: expected 'overlay not found: missing', got: $out" >&2; exit 1 ;;
esac

: > "$tmpdir/conf-none"  # existing config without overlays

# Happy-path merge packed from the ROOT (dummy kernel, no overlays); needs the
# host's mkimage, otherwise skipped (covered end-to-end by the QEMU boot test).
if command -v mkimage >/dev/null 2>&1; then
    if ! out=$("$MERGE_SH" "$tmpdir/conf-none" "$tmpdir/out-data" B "$SLOT_ROOT" 2>&1); then
        echo "FAIL: ROOT-anchored merge failed: $out" >&2
        exit 1
    fi
    [ -f "$tmpdir/out-data/fit/zboot_merged_b.img" ] || { echo "FAIL: ROOT-anchored merge wrote no FIT" >&2; exit 1; }
    assert_eq "$(cat "$tmpdir/out-data/fit/kernel-B.stamp")" \
        "$(sha256sum "$SLOT_ROOT/boot/fit_kernel" | cut -d' ' -f1)" "stamp tracks the ROOT's kernel"
else
    echo "WARN: mkimage not found, skipped ROOT-anchored merge packing" >&2
fi

# rebuild-merged-fit: env handling (stub stands in for the real merge script)
REBUILD="$DIR/../../rauc/files/rebuild-merged-fit"
if [ -f "$REBUILD" ]; then
    chmod +x "$REBUILD" 2>/dev/null || true
    STUB="$tmpdir/merge-stub.sh"
    ARGS_LOG="$tmpdir/merge-stub.args"
    printf '#!/bin/sh\necho "$@" >> "%s"\n' "$ARGS_LOG" > "$STUB"
    chmod +x "$STUB"
    CONF_PRESENT="$tmpdir/conf-none"

    # rootfs slot, mounted -> merge called with (CONFIG, DATA_MP, SLOT, MOUNT)
    mkdir -p "$tmpdir/mnt/rootfs.0"
    rm -f "$ARGS_LOG"
    RAUC_TARGET_SLOTS=0 \
        RAUC_SLOT_NAME_0=rootfs.0 RAUC_SLOT_CLASS_0=rootfs RAUC_SLOT_BOOTNAME_0=A \
        RAUC_MOUNT_PREFIX="$tmpdir/mnt" \
        MERGE_SCRIPT="$STUB" OVERLAY_CONF="$CONF_PRESENT" OVERLAY_DATA="$tmpdir/out-data" \
        "$REBUILD" || { echo "FAIL: rebuild-merged-fit exited nonzero" >&2; exit 1; }
    assert_eq "$(cat "$ARGS_LOG" 2>/dev/null)" \
        "$CONF_PRESENT $tmpdir/out-data A $tmpdir/mnt/rootfs.0" "rebuild merge argv"

    # non-rootfs class -> untouched
    rm -f "$ARGS_LOG"
    RAUC_TARGET_SLOTS=0 \
        RAUC_SLOT_NAME_0=boot.0 RAUC_SLOT_CLASS_0=boot \
        RAUC_MOUNT_PREFIX="$tmpdir/mnt" \
        MERGE_SCRIPT="$STUB" OVERLAY_CONF="$CONF_PRESENT" OVERLAY_DATA="$tmpdir/out-data" \
        "$REBUILD"
    [ -f "$ARGS_LOG" ] && { echo "FAIL: non-rootfs slot must be skipped" >&2; exit 1; }

    # slot not mounted -> warn and skip, still exit 0 (degrade, never abort)
    rm -f "$ARGS_LOG"
    RAUC_TARGET_SLOTS=0 \
        RAUC_SLOT_NAME_0=rootfs.0 RAUC_SLOT_CLASS_0=rootfs RAUC_SLOT_BOOTNAME_0=B \
        RAUC_MOUNT_PREFIX="$tmpdir/not-mounted" \
        MERGE_SCRIPT="$STUB" OVERLAY_CONF="$CONF_PRESENT" OVERLAY_DATA="$tmpdir/out-data" \
        "$REBUILD" || { echo "FAIL: unmounted slot must not fail rebuild" >&2; exit 1; }
    [ -f "$ARGS_LOG" ] && { echo "FAIL: unmounted slot must be skipped" >&2; exit 1; }
else
    echo "WARN: rebuild-merged-fit not found at $REBUILD, skipped" >&2
fi

echo "merge-dt-overlays-boot-check: OK"
