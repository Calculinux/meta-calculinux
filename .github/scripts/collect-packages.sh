#!/bin/bash
# Collect IPK package build artifacts
# Copies all IPK packages from deploy directory maintaining architecture structure

set -euo pipefail

ARTIFACTS_DIR="${1:?Usage: $0 <artifacts_dir>}"

echo "Collecting IPK packages..."

# Find build directory
BUILD_DIR=$(find build -name "tmp" -type d | head -1)
DEPLOY_IPK_DIR="${BUILD_DIR}/deploy/ipk"

if [ ! -d "$DEPLOY_IPK_DIR" ]; then
    echo "Warning: No IPK packages directory found at $DEPLOY_IPK_DIR"
    exit 0
fi

PACKAGE_COUNT=$(find "$DEPLOY_IPK_DIR" -name "*.ipk" -type f | wc -l)
echo "Found $PACKAGE_COUNT IPK packages"

# Create packages directory in artifacts
mkdir -p "$ARTIFACTS_DIR/packages"

# Copy all packages maintaining architecture structure
echo "Copying packages with architecture structure..."
cp -r "$DEPLOY_IPK_DIR"/* "$ARTIFACTS_DIR/packages/"

echo ""
echo "Collected packages by architecture:"
for arch_dir in "$ARTIFACTS_DIR/packages"/*/; do
    if [ -d "$arch_dir" ]; then
        arch=$(basename "$arch_dir")
        count=$(find "$arch_dir" -name "*.ipk" -type f | wc -l)
        size=$(du -sh "$arch_dir" | cut -f1)
        echo "  $arch: $count packages ($size)"
    fi
done

echo ""
echo "Package artifact collection complete"
