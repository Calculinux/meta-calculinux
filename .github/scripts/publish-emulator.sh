#!/bin/bash
# Publish calculinux-emulator AppImages next to the SDKs on the webserver:
#   sdk/<feed>/<subfolder>/<arch>/calculinux-emulator-<arch>[-<tag>].AppImage
# and the disk image they download:
#   image/<feed>/<subfolder>/calculinux-image-<machine>.rootfs[-<tag>].qcow2
# then regenerate the index of those images (emulator/<machine>/index.json,
# see generate-emulator-index.py).
# Arguments are the same as publish-sdk.sh (see lib/publish-common.sh).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/publish-common.sh" "$@"

# Copy under a temporary name and rename, so a client never downloads a
# half-written file.
publish() {
    src="$1"
    dest="$2"
    cp "$src" "$dest.tmp"
    sum=$(sha256sum "$dest.tmp" | cut -d' ' -f1)
    mv "$dest.tmp" "$dest"
    printf '%s  %s\n' "$sum" "$(basename "$dest")" > "$dest.sha256.tmp"
    mv "$dest.sha256.tmp" "$dest.sha256"
    echo "  Published: $dest"
}

# <image>.json: what generate-emulator-index.py cannot tell from the path.
write_sidecar() {
    python3 - "$1.json" "$2" "$3" "$VERSION" "${GITHUB_SHA:-}" "${GITHUB_REF_NAME:-}" <<'EOF'
import json, os, sys
from datetime import datetime, timezone

path, image_id, channel, version, git_sha, ref = sys.argv[1:7]
with open(path + ".tmp", "w") as out:
    json.dump({
        "id": image_id,
        "channel": channel,
        "version": version,
        "git_sha": git_sha,
        "ref": ref,
        "published_at": datetime.now(timezone.utc).isoformat(),
    }, out, indent=2)
    out.write("\n")
os.replace(path + ".tmp", path)
EOF
}

# DISTRO_VERSION of this build, from calculinux-emulator-<arch>-<version>.AppImage.
VERSION="$TAG_NAME"
for arch in x86_64 aarch64; do
    appimage=$(find "$ARTIFACTS_DIR/emulator/$arch" -name 'calculinux-emulator-*.AppImage' -type f 2>/dev/null | head -1 || true)
    if [ -n "$appimage" ]; then
        VERSION=$(basename "$appimage" .AppImage)
        VERSION=${VERSION#calculinux-emulator-"$arch"-}
        break
    fi
done

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
            write_sidecar "$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs-${TAG_NAME}.qcow2" "$TAG_NAME" release
            # "Latest release", for AppImages older than the index.
            publish "$disk" "$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs.qcow2"
        else
            write_sidecar "$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs-${TAG_NAME}.qcow2" "$TAG_NAME" prerelease
        fi
    else
        publish "$disk" "$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs.qcow2"
        if [ "$FEED_NAME" = "develop" ]; then
            channel=continuous-develop
        else
            channel=continuous-main
        fi
        write_sidecar "$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs.qcow2" "$channel" "$channel"
    fi
else
    echo "No emulator disk image found"
fi

# main, develop and tags publish separately, so the index is rebuilt from
# what is on the server; the lock keeps two publishes from interleaving.
mkdir -p "$OPKG_REPO_DIR/emulator"
flock "$OPKG_REPO_DIR/emulator/.index.lock" \
    python3 "$SCRIPT_DIR/generate-emulator-index.py" --repo-dir "$OPKG_REPO_DIR" --machine "$MACHINE"

echo "Emulator published to: https://opkg.calculinux.org/sdk/$FEED_NAME/$SUBFOLDER/"
echo "Emulator image published to: https://opkg.calculinux.org/image/$FEED_NAME/$SUBFOLDER/"
echo "Emulator image index: https://opkg.calculinux.org/emulator/$MACHINE/index.json"
