#!/bin/bash
# Publish image artifacts to webserver
# Handles both continuous and tagged releases with appropriate naming

set -euo pipefail

OPKG_REPO_DIR="${1:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
FEED_NAME="${2:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
SUBFOLDER="${3:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
MACHINE="${4:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
ARTIFACTS_DIR="${5:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
IS_TAGGED_RELEASE="${6:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
IS_PRERELEASE="${7:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
TAG_NAME="${8:-}"

echo "Publishing images to webserver..."

UPDATE_DIR="$OPKG_REPO_DIR/update/$FEED_NAME/$SUBFOLDER"
IMAGE_DIR="$OPKG_REPO_DIR/image/$FEED_NAME/$SUBFOLDER"

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
        cp "$RAUCB_FILE" "$VERSIONED_BUNDLE"
        sha256sum "$VERSIONED_BUNDLE" > "${VERSIONED_BUNDLE}.sha256"
        echo "Published RAUC bundle: calculinux-bundle-${MACHINE}-${TAG_NAME}.raucb"
        
        # If not a prerelease, also copy with original name for latest release
        if [ "$IS_PRERELEASE" = "false" ]; then
            LATEST_BUNDLE="$UPDATE_DIR/calculinux-bundle-${MACHINE}.raucb"
            cp "$RAUCB_FILE" "$LATEST_BUNDLE"
            sha256sum "$LATEST_BUNDLE" > "${LATEST_BUNDLE}.sha256"
            echo "Published RAUC bundle: calculinux-bundle-${MACHINE}.raucb (latest)"
        fi
    else
        echo "Warning: calculinux-bundle-${MACHINE}.raucb not found"
    fi
    
    if [ -n "$WIC_FILE" ]; then
        # Copy WIC image with versioned name
        VERSIONED_WIC="$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs-${TAG_NAME}.wic.gz"
        cp "$WIC_FILE" "$VERSIONED_WIC"
        sha256sum "$VERSIONED_WIC" > "${VERSIONED_WIC}.sha256"
        echo "Published WIC image: calculinux-image-${MACHINE}.rootfs-${TAG_NAME}.wic.gz"
        
        # If not a prerelease, also copy with original name for latest release
        if [ "$IS_PRERELEASE" = "false" ]; then
            LATEST_WIC="$IMAGE_DIR/calculinux-image-${MACHINE}.rootfs.wic.gz"
            cp "$WIC_FILE" "$LATEST_WIC"
            sha256sum "$LATEST_WIC" > "${LATEST_WIC}.sha256"
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
