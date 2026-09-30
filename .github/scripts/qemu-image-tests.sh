#!/usr/bin/env bash
# post_build hook for the calculinux-qemuarm image lane: boot the image with
# runqemu inside the kas environment and run the end-to-end checks.
#   qemu-boot-test.py     U-Boot -> boot.scr (RAUC A/B) -> merged DT-overlay
#                         FIT -> preinit/overlayfs, per-slot FIT on /data
#   qemu-overlay-test.py  overlayfs upper-layer ioctl test
# Serial logs go to $RUNNER_TEMP/test-logs.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <kas-override-file> <output-dir>" >&2
  exit 1
fi

KAS_FILE="$1"
LOG_DIR="${RUNNER_TEMP:-/tmp}/test-logs"
mkdir -p "$LOG_DIR"

rc=0
for test in qemu-boot-test qemu-overlay-test; do
  echo "::group::$test"
  # kas-container mounts the checkout at /work, so the log lands in ./
  ./kas-container shell "$KAS_FILE" -c \
    "python3 /repo/.github/scripts/$test.py --log /work/$test.log" || rc=1
  echo "::endgroup::"
  cp -f "$test.log" "$LOG_DIR/" 2>/dev/null || true
done
exit "$rc"
