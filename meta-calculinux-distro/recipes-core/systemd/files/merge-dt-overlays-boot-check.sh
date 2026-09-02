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

echo "merge-dt-overlays-boot-check: OK"
