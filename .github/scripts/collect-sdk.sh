#!/bin/bash
# Collect SDK build artifacts
# Organizes SDK installers and manifests by architecture (x86_64, aarch64)

set -euo pipefail

ARTIFACTS_DIR="${1:?Usage: $0 <artifacts_dir>}"

echo "Collecting SDK artifacts..."

# Find build directory
BUILD_DIR=$(find build -name "tmp" -type d | head -1)
DEPLOY_SDK_DIR="${BUILD_DIR}/deploy/sdk"

# Always create SDK directory structure, even if empty
mkdir -p "$ARTIFACTS_DIR/sdk/x86_64" "$ARTIFACTS_DIR/sdk/aarch64"

if [ ! -d "$DEPLOY_SDK_DIR" ]; then
    echo "No SDK directory found at $DEPLOY_SDK_DIR"
    echo "This is expected when SDK build was skipped"
    echo ""
    echo "SDK Summary:"
    echo "  x86_64 SDKs: 0 (SDK build skipped)"
    echo "  aarch64 SDKs: 0 (SDK build skipped)"
    echo "  Total SDKs: 0 (SDK build skipped)"
    exit 0
fi

echo "Found SDK directory: $DEPLOY_SDK_DIR"

# Process each SDK file to determine its architecture and organize accordingly
find "$DEPLOY_SDK_DIR" -name "*.sh" -type f | while read sdk_file; do
    if [ -f "$sdk_file" ]; then
        sdk_basename=$(basename "$sdk_file")
        echo "Processing SDK installer: $sdk_basename"
        
        # Determine architecture from filename
        # SDK filenames typically contain architecture info, e.g.:
        # calculinux-distro-glibc-x86_64-calculinux-image-armv7at2hf-neon-vfpv4-luckfox-lyra-toolchain-5.2.3.sh
        if [[ "$sdk_basename" =~ -x86_64- ]]; then
            echo "  -> x86_64 SDK: $sdk_basename"
            cp "$sdk_file" "$ARTIFACTS_DIR/sdk/x86_64/"
            SDK_ARCH="x86_64"
        elif [[ "$sdk_basename" =~ -aarch64- ]]; then
            echo "  -> aarch64 SDK: $sdk_basename"
            cp "$sdk_file" "$ARTIFACTS_DIR/sdk/aarch64/"
            SDK_ARCH="aarch64"
        else
            echo "  -> Unknown architecture, defaulting to x86_64: $sdk_basename"
            cp "$sdk_file" "$ARTIFACTS_DIR/sdk/x86_64/"
            SDK_ARCH="x86_64"
        fi
        
        # Look for corresponding manifest file
        manifest_file="${sdk_file%.sh}.manifest"
        if [ -f "$manifest_file" ]; then
            manifest_basename=$(basename "$manifest_file")
            echo "    Found manifest: $manifest_basename"
            cp "$manifest_file" "$ARTIFACTS_DIR/sdk/$SDK_ARCH/"
        fi
    fi
done

# Also look for standalone manifest files
find "$DEPLOY_SDK_DIR" -name "*.manifest" -type f | while read manifest_file; do
    if [ -f "$manifest_file" ]; then
        manifest_basename=$(basename "$manifest_file")
        # Skip if we already copied it above
        if [ ! -f "$ARTIFACTS_DIR/sdk/x86_64/$manifest_basename" ] && \
           [ ! -f "$ARTIFACTS_DIR/sdk/aarch64/$manifest_basename" ]; then
            echo "Processing standalone manifest: $manifest_basename"
            
            # Determine architecture from manifest filename
            if [[ "$manifest_basename" =~ -x86_64- ]]; then
                echo "  -> x86_64 manifest: $manifest_basename"
                cp "$manifest_file" "$ARTIFACTS_DIR/sdk/x86_64/"
            elif [[ "$manifest_basename" =~ -aarch64- ]]; then
                echo "  -> aarch64 manifest: $manifest_basename"
                cp "$manifest_file" "$ARTIFACTS_DIR/sdk/aarch64/"
            else
                echo "  -> Unknown architecture manifest, defaulting to x86_64: $manifest_basename"
                cp "$manifest_file" "$ARTIFACTS_DIR/sdk/x86_64/"
            fi
        fi
    fi
done

# Show what we collected for each architecture
echo ""
echo "Collected SDK artifacts:"
echo ""
echo "x86_64 SDKs:"
if [ "$(ls -A "$ARTIFACTS_DIR/sdk/x86_64" 2>/dev/null)" ]; then
    ls -lh "$ARTIFACTS_DIR/sdk/x86_64/"
    echo "x86_64 SDK sizes:"
    du -sh "$ARTIFACTS_DIR/sdk/x86_64"/* 2>/dev/null || echo "No x86_64 SDK files"
else
    echo "  No x86_64 SDK files found"
fi

echo ""
echo "aarch64 SDKs:"
if [ "$(ls -A "$ARTIFACTS_DIR/sdk/aarch64" 2>/dev/null)" ]; then
    ls -lh "$ARTIFACTS_DIR/sdk/aarch64/"
    echo "aarch64 SDK sizes:"
    du -sh "$ARTIFACTS_DIR/sdk/aarch64"/* 2>/dev/null || echo "No aarch64 SDK files"
else
    echo "  No aarch64 SDK files found"
fi

# Create summary
echo ""
echo "SDK Summary:"
X86_COUNT=$(find "$ARTIFACTS_DIR/sdk/x86_64" -name "*.sh" -type f 2>/dev/null | wc -l)
AARCH64_COUNT=$(find "$ARTIFACTS_DIR/sdk/aarch64" -name "*.sh" -type f 2>/dev/null | wc -l)
echo "  x86_64 SDKs: $X86_COUNT"
echo "  aarch64 SDKs: $AARCH64_COUNT"
echo "  Total SDKs: $((X86_COUNT + AARCH64_COUNT))"

echo ""
echo "SDK artifact collection complete"
