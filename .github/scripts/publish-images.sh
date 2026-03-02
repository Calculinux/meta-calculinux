#!/bin/bash
# Publish image artifacts to webserver
# Handles both continuous and tagged releases with appropriate naming

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/publish-common.sh" "$@"

echo "Publishing images to webserver..."

# Create target directories
mkdir -p "$UPDATE_DIR" "$IMAGE_DIR"

if [ "$IS_TAGGED_RELEASE" = "true" ]; then
    echo "Publishing tagged release images..."
    
    # Find the specific RAUC bundle and WIC image files
    RAUCB_FILE=$(find "$ARTIFACTS_DIR" -name "calculinux-bundle-${MACHINE}.raucb" | head -1)
    WIC_FILE=$(find "$ARTIFACTS_DIR" -name "calculinux-image-${MACHINE}.rootfs.wic.gz" | head -1)
    
    if [ -n "$RAUCB_FILE" ]; then
        # Copy RAUC bundle with versioned name
        VERSIONED_BUNDLE="$UPDATE_DIR/calculinux-bundle-${MACHINE}-${TAG_NAME}.raucb"
        copy_with_checksum "$RAUCB_FILE" "$VERSIONED_BUNDLE"
        echo "Published RAUC bundle: calculinux-bundle-${MACHINE}-${TAG_NAME}.raucb"
        
        # If not a prerelease, also copy with original name for latest release
        if [ "$IS_PRERELEASE" = "false" ]; then
            LATEST_BUNDLE="$UPDATE_DIR/calculinux-bundle-${MACHINE}.raucb"
            copy_with_checksum "$RAUCB_FILE" "$LATEST_BUNDLE"
            echo "Published RAUC bundle: calculinux-bundle-${MACHINE}.raucb (latest)"
        fi
    else
        echo "Warning: calculinux-bundle-${MACHINE}.raucb not found"
    fi
    
    if [ -n "$WIC_FILE" ]; then
        # Copy WIC image with versioned name
        VERSIONED_WIC="$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs-${TAG_NAME}.wic.gz"
        copy_with_checksum "$WIC_FILE" "$VERSIONED_WIC"
        echo "Published WIC image: calculinux-image-${MACHINE}.rootfs-${TAG_NAME}.wic.gz"
        
        # If not a prerelease, also copy with original name for latest release
        if [ "$IS_PRERELEASE" = "false" ]; then
            LATEST_WIC="$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs.wic.gz"
            copy_with_checksum "$WIC_FILE" "$LATEST_WIC"
            echo "Published WIC image: calculinux-image-${MACHINE}.rootfs.wic.gz (latest)"
        fi
    else
        echo "Warning: calculinux-image-${MACHINE}.rootfs.wic.gz not found"
    fi
else
    echo "Publishing continuous development images..."
    
    # Copy RAUC bundles to update directory
    if ls "$ARTIFACTS_DIR"/*.raucb 1> /dev/null 2>&1; then
        echo "Copying RAUC bundles to $UPDATE_DIR"
        cp "$ARTIFACTS_DIR"/*.raucb "$UPDATE_DIR/"
        if ls "$ARTIFACTS_DIR"/*.raucb.sha256 1> /dev/null 2>&1; then
            cp "$ARTIFACTS_DIR"/*.raucb.sha256 "$UPDATE_DIR/"
        fi
        echo "Published RAUC bundles:"
        ls -lh "$UPDATE_DIR"/*.raucb
    else
        echo "No RAUC bundles found to publish"
    fi
    
    # Copy WIC images to image directory
    if ls "$ARTIFACTS_DIR"/*.wic.gz 1> /dev/null 2>&1; then
        echo "Copying WIC images to $IMAGE_DIR"
        cp "$ARTIFACTS_DIR"/*.wic.gz "$IMAGE_DIR/"
        if ls "$ARTIFACTS_DIR"/*.wic.gz.sha256 1> /dev/null 2>&1; then
            cp "$ARTIFACTS_DIR"/*.wic.gz.sha256 "$IMAGE_DIR/"
        fi
        echo "Published WIC images:"
        ls -lh "$IMAGE_DIR"/*.wic.gz
    else
        echo "No WIC images found to publish"
    fi
fi

echo "Images published successfully"
