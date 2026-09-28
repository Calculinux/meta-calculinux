#!/bin/bash
# Publish calculinux-emulator AppImages next to the SDKs on the webserver:
#   sdk/<feed>/<subfolder>/<arch>/calculinux-emulator-<arch>[-<tag>].AppImage
# Arguments are the same as publish-sdk.sh (see lib/publish-common.sh).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/publish-common.sh" "$@"

publish() {
    src="$1"
    dest="$2"
    cp "$src" "$dest"
    (cd "$(dirname "$dest")" && sha256sum "$(basename "$dest")" > "$(basename "$dest").sha256")
    echo "  Published: $dest"
}

for arch in x86_64 aarch64; do
    appimage=$(find "$ARTIFACTS_DIR/emulator/$arch" -name '*.AppImage' -type f 2>/dev/null | head -1)
    if [ -z "$appimage" ]; then
        echo "No $arch emulator AppImage found"
        continue
    fi
    mkdir -p "$SDK_DIR/$arch"
    if [ "$IS_TAGGED_RELEASE" = "true" ]; then
        publish "$appimage" "$SDK_DIR/$arch/calculinux-emulator-${arch}-${TAG_NAME}.AppImage"
        if [ "$IS_PRERELEASE" = "false" ]; then
            publish "$appimage" "$SDK_DIR/$arch/calculinux-emulator-${arch}.AppImage"
        fi
    else
        publish "$appimage" "$SDK_DIR/$arch/calculinux-emulator-${arch}.AppImage"
    fi
done

echo "Emulator published to: https://opkg.calculinux.org/sdk/$FEED_NAME/$SUBFOLDER/"
