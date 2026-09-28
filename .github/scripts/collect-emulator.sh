#!/bin/bash
# Collect calculinux-emulator AppImages into <artifacts_dir>/emulator/<arch>/
# (arch from the file name: calculinux-emulator-<arch>-<version>.AppImage)

set -euo pipefail

ARTIFACTS_DIR="${1:?Usage: $0 <artifacts_dir>}"

BUILD_DIR=$(bash "$(dirname "$0")/build-dir.sh" --optional)
DEPLOY_SDK_DIR="${BUILD_DIR:+$BUILD_DIR/}deploy/sdk"
if [ -z "$BUILD_DIR" ] || [ ! -d "$DEPLOY_SDK_DIR" ]; then
    echo "No SDK deploy directory found; no emulator AppImages to collect"
    exit 0
fi

found=0
for appimage in "$DEPLOY_SDK_DIR"/calculinux-emulator-*.AppImage; do
    [ -f "$appimage" ] || continue
    name=$(basename "$appimage")
    arch=${name#calculinux-emulator-}
    arch=${arch%%-*}
    mkdir -p "$ARTIFACTS_DIR/emulator/$arch"
    cp "$appimage" "$ARTIFACTS_DIR/emulator/$arch/"
    (cd "$ARTIFACTS_DIR/emulator/$arch" && sha256sum "$name" > "$name.sha256")
    echo "Collected $arch emulator: $name ($(du -h "$appimage" | cut -f1))"
    found=$((found + 1))
done
echo "Emulator AppImages collected: $found"
