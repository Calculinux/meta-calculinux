#!/bin/bash
# Collect calculinux-emulator AppImages into <artifacts_dir>/emulator/<arch>/
# (arch from the file name: calculinux-emulator-<arch>-<version>.AppImage)

set -euo pipefail

ARTIFACTS_DIR="${1:?Usage: $0 <artifacts_dir>}"

# Look for the files directly (build/tmp/deploy/sdk or build/<x>/tmp/deploy/sdk).
found=0
for appimage in $(find build -maxdepth 5 -path '*/deploy/sdk/calculinux-emulator-*.AppImage' 2>/dev/null); do
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
