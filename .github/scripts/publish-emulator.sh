#!/bin/bash
# Publish calculinux-emulator AppImages next to the SDKs on the webserver:
#   sdk/<feed>/<subfolder>/<arch>/calculinux-emulator-<arch>[-<tag>].AppImage
# and the disk image they download:
#   image/<feed>/<subfolder>/calculinux-image-<machine>.rootfs[-<tag>].qcow2
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

# Disk image fetched by the AppImage (EMULATOR_IMAGE_URL in
# calculinux-emulator.bb): image/<feed>/<subfolder>/, named like the Lyra
# images.
disk="$ARTIFACTS_DIR/emulator/image/calculinux-image-${MACHINE}.rootfs.qcow2"
if [ -f "$disk" ]; then
    mkdir -p "$IMAGE_DIR"
    if [ "$IS_TAGGED_RELEASE" = "true" ]; then
        publish "$disk" "$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs-${TAG_NAME}.qcow2"
        if [ "$IS_PRERELEASE" = "false" ]; then
            publish "$disk" "$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs.qcow2"
        fi
    else
        publish "$disk" "$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs.qcow2"
    fi
else
    echo "No emulator disk image found"
fi

echo "Emulator published to: https://opkg.calculinux.org/sdk/$FEED_NAME/$SUBFOLDER/"
echo "Emulator image published to: https://opkg.calculinux.org/image/$FEED_NAME/$SUBFOLDER/"
