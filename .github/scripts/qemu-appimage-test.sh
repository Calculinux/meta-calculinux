#!/usr/bin/env bash
# post_build hook for the emulator lane: boot the collected x86_64 AppImage
# on its disk image, on the runner itself (as users run it), and run the
# end-to-end boot checks. Serial log goes to $RUNNER_TEMP/test-logs.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <kas-override-file> <output-dir>" >&2
  exit 1
fi

OUT_DIR="$2"
LOG_DIR="${RUNNER_TEMP:-/tmp}/test-logs"
mkdir -p "$LOG_DIR"

appimage=$(find "$OUT_DIR/emulator/x86_64" -name '*.AppImage' -type f -print -quit)
disk="$OUT_DIR/emulator/image/calculinux-image-calculinux-qemuarm.rootfs.qcow2"
if [ -z "$appimage" ] || [ ! -f "$disk" ]; then
  echo "::error::Missing x86_64 AppImage or disk image in $OUT_DIR/emulator"
  exit 1
fi

# Runs without FUSE; keep emulator state out of the home directory.
export APPIMAGE_EXTRACT_AND_RUN=1
export CALCULINUX_EMULATOR_HOME="${RUNNER_TEMP:-/tmp}/emulator-state"
python3 .github/scripts/qemu-boot-test.py \
  --cmd "$appimage --image $disk --nographic --ssh-port off" \
  --log "$LOG_DIR/qemu-appimage-test.log"
