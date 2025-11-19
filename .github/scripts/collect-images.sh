#!/bin/bash
# Collect image build artifacts
# Copies WIC images, RAUC bundles, u-boot files, and manifests to artifacts directory

set -euo pipefail

MACHINE="${1:?Usage: $0 <machine> <artifacts_dir>}"
ARTIFACTS_DIR="${2:?Usage: $0 <machine> <artifacts_dir>}"

echo "Collecting build artifacts for machine: $MACHINE"

# Find the build directory
BUILD_DIR=$(find build -name "tmp" -type d | head -1 | sed 's|/tmp||')
DEPLOY_DIR="${BUILD_DIR}/tmp/deploy/images/${MACHINE}"

echo "Deploy directory: $DEPLOY_DIR"

if [ ! -d "$DEPLOY_DIR" ]; then
    echo "ERROR: Deploy directory not found: $DEPLOY_DIR"
    echo "Available directories:"
    find build -type d -name "deploy" || true
    exit 1
fi

# Create artifacts directory
mkdir -p "$ARTIFACTS_DIR"

# Copy image files
echo "Collecting WIC images..."
find "$DEPLOY_DIR" -name "*.wic.gz" -o -name "*.wic.bz2" -o -name "*.wic.xz" | \
    xargs -I {} cp {} "$ARTIFACTS_DIR/" || true

# Copy update bundles (RAUC bundles)
echo "Collecting RAUC bundles..."
find "$DEPLOY_DIR" -name "*.raucb" | \
    xargs -I {} cp {} "$ARTIFACTS_DIR/" || true

# Copy u-boot files
echo "Collecting u-boot files..."
cp "$DEPLOY_DIR"/uboot-"${MACHINE}"-*.bin "$ARTIFACTS_DIR/" 2>/dev/null || true
cp "$DEPLOY_DIR"/u-boot-*initial-env-"${MACHINE}"-* "$ARTIFACTS_DIR/" 2>/dev/null || true

# Copy other important files
echo "Collecting manifests and test data..."
find "$DEPLOY_DIR" -name "*.manifest" -o -name "*.testdata.json" | \
    xargs -I {} cp {} "$ARTIFACTS_DIR/" || true

# List what we collected
echo ""
echo "Collected artifacts:"
ls -lh "$ARTIFACTS_DIR/" || echo "No artifacts collected"

# Generate checksums
echo ""
echo "Generating SHA256 checksums..."
pushd "$ARTIFACTS_DIR" >/dev/null
shopt -s nullglob

for bundle in *.raucb; do
    [ -e "$bundle" ] || continue
    sha256sum "$bundle" > "$bundle.sha256"
    echo "  Generated checksum for $bundle"
done

for image in *.wic.gz *.wic.bz2 *.wic.xz; do
    [ -e "$image" ] || continue
    sha256sum "$image" > "$image.sha256"
    echo "  Generated checksum for $image"
done

popd >/dev/null

echo ""
echo "Image artifact collection complete"
