#!/bin/bash
# Self-check for RAUC-slot FIT naming and kernel stamp matching.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=merge-dt-overlays-boot.sh
MERGE_DT_OVERLAYS_LIB=1
# The helper file is a bash script; `.` needs bash functions.
. "$DIR/merge-dt-overlays-boot.sh"

assert_eq() {
    [ "$1" = "$2" ] || { echo "FAIL: expected '$2' got '$1' ($3)" >&2; exit 1; }
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
echo "merge-dt-overlays-boot-check: OK"
