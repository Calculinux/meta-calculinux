#!/bin/bash
# Publish SDK artifacts to webserver
# Organizes SDKs by architecture with consistent naming

set -euo pipefail

OPKG_REPO_DIR="${1:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
FEED_NAME="${2:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
SUBFOLDER="${3:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
MACHINE="${4:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
ARTIFACTS_DIR="${5:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
IS_TAGGED_RELEASE="${6:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
IS_PRERELEASE="${7:?Usage: $0 <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> <tag_name>}"
TAG_NAME="${8:-}"

echo "Publishing SDK to webserver..."

SDK_DIR="$OPKG_REPO_DIR/sdk/$FEED_NAME/$SUBFOLDER"

# Create target directory
mkdir -p "$SDK_DIR"

# Check if we have SDK artifacts
if [ ! -d "$ARTIFACTS_DIR/sdk" ] || [ "$(find "$ARTIFACTS_DIR/sdk" -name "*.sh" -type f 2>/dev/null | wc -l)" -eq 0 ]; then
    echo "Warning: No SDK artifacts found to publish"
    echo "Expected to find SDK installer files (.sh) in $ARTIFACTS_DIR/sdk/{x86_64,aarch64}/"
    exit 0
fi

echo "Processing SDK artifacts for multiple architectures..."

# Process each architecture
for arch in x86_64 aarch64; do
    if [ ! -d "$ARTIFACTS_DIR/sdk/$arch" ] || [ ! "$(ls -A "$ARTIFACTS_DIR/sdk/$arch" 2>/dev/null)" ]; then
        echo "  No $arch SDK artifacts found"
        continue
    fi
    
    echo ""
    echo "Publishing $arch SDK artifacts..."
    
    # Create architecture-specific directory
    mkdir -p "$SDK_DIR/$arch"
    
    if [ "$IS_TAGGED_RELEASE" = "true" ]; then
        echo "Publishing tagged release SDK for $arch..."
        
        # Find SDK installer file for this architecture
        SDK_FILE=$(find "$ARTIFACTS_DIR/sdk/$arch" -name "*.sh" -type f | head -1)
        
        if [ -n "$SDK_FILE" ]; then
            SDK_BASENAME=$(basename "$SDK_FILE")
            
            # Create a consistent SDK filename using Calculinux versioning
            CALCULINUX_SDK_NAME="calculinux-sdk-${MACHINE}-${arch}-${TAG_NAME}.sh"
            CALCULINUX_SDK_LATEST="calculinux-sdk-${MACHINE}-${arch}.sh"
            
            # Copy SDK with Calculinux versioned name
            cp "$SDK_FILE" "$SDK_DIR/$arch/$CALCULINUX_SDK_NAME"
            echo "  Published $arch SDK: $CALCULINUX_SDK_NAME"
            
            # If not a prerelease, also copy with latest name for easy discovery
            if [ "$IS_PRERELEASE" = "false" ]; then
                cp "$SDK_FILE" "$SDK_DIR/$arch/$CALCULINUX_SDK_LATEST"
                echo "  Published $arch SDK: $CALCULINUX_SDK_LATEST (latest)"
            fi
            
            # Also keep the original SDK filename for advanced users who need the detailed info
            cp "$SDK_FILE" "$SDK_DIR/$arch/$SDK_BASENAME"
            echo "  Published $arch SDK: $SDK_BASENAME (detailed)"
            
            # Copy SDK manifest if available
            SDK_MANIFEST=$(find "$ARTIFACTS_DIR/sdk/$arch" -name "*.manifest" -type f | head -1)
            if [ -n "$SDK_MANIFEST" ]; then
                MANIFEST_BASENAME=$(basename "$SDK_MANIFEST")
                
                # Create consistent manifest names to match SDK names
                CALCULINUX_MANIFEST_NAME="calculinux-sdk-${MACHINE}-${arch}-${TAG_NAME}.manifest"
                CALCULINUX_MANIFEST_LATEST="calculinux-sdk-${MACHINE}-${arch}.manifest"
                
                cp "$SDK_MANIFEST" "$SDK_DIR/$arch/$CALCULINUX_MANIFEST_NAME"
                echo "  Published $arch SDK manifest: $CALCULINUX_MANIFEST_NAME"
                
                if [ "$IS_PRERELEASE" = "false" ]; then
                    cp "$SDK_MANIFEST" "$SDK_DIR/$arch/$CALCULINUX_MANIFEST_LATEST"
                    echo "  Published $arch SDK manifest: $CALCULINUX_MANIFEST_LATEST (latest)"
                fi
                
                # Also keep the original manifest filename
                cp "$SDK_MANIFEST" "$SDK_DIR/$arch/$MANIFEST_BASENAME"
                echo "  Published $arch SDK manifest: $MANIFEST_BASENAME (detailed)"
            fi
        else
            echo "  Warning: No $arch SDK installer (.sh) files found"
        fi
    else
        echo "Publishing continuous development SDK for $arch..."
        
        # Copy all SDK files for this architecture to SDK directory
        if ls "$ARTIFACTS_DIR/sdk/$arch"/*.sh 1> /dev/null 2>&1; then
            echo "  Copying $arch SDK installers to $SDK_DIR/$arch"
            
            # For continuous builds, use consistent naming but without version tags
            for sdk_file in "$ARTIFACTS_DIR/sdk/$arch"/*.sh; do
                if [ -f "$sdk_file" ]; then
                    SDK_BASENAME=$(basename "$sdk_file")
                    
                    # Create consistent SDK filename for continuous builds
                    CALCULINUX_SDK_NAME="calculinux-sdk-${MACHINE}-${arch}.sh"
                    
                    # Copy with both names
                    cp "$sdk_file" "$SDK_DIR/$arch/$CALCULINUX_SDK_NAME"
                    cp "$sdk_file" "$SDK_DIR/$arch/$SDK_BASENAME"
                    
                    echo "    Published: $CALCULINUX_SDK_NAME"
                    echo "    Published: $SDK_BASENAME (detailed)"
                fi
            done
        else
            echo "  No $arch SDK installer files found"
        fi
        
        # Copy SDK manifests if available
        if ls "$ARTIFACTS_DIR/sdk/$arch"/*.manifest 1> /dev/null 2>&1; then
            echo "  Copying $arch SDK manifests to $SDK_DIR/$arch"
            
            for manifest_file in "$ARTIFACTS_DIR/sdk/$arch"/*.manifest; do
                if [ -f "$manifest_file" ]; then
                    MANIFEST_BASENAME=$(basename "$manifest_file")
                    
                    # Create consistent manifest filename for continuous builds
                    CALCULINUX_MANIFEST_NAME="calculinux-sdk-${MACHINE}-${arch}.manifest"
                    
                    # Copy with both names
                    cp "$manifest_file" "$SDK_DIR/$arch/$CALCULINUX_MANIFEST_NAME"
                    cp "$manifest_file" "$SDK_DIR/$arch/$MANIFEST_BASENAME"
                    
                    echo "    Published: $CALCULINUX_MANIFEST_NAME"
                    echo "    Published: $MANIFEST_BASENAME (detailed)"
                fi
            done
        fi
    fi
done

echo ""
echo "SDK publishing summary:"
echo "SDK published to: https://opkg.calculinux.org/sdk/$FEED_NAME/$SUBFOLDER/"

# Show final directory structure
for arch in x86_64 aarch64; do
    if [ -d "$SDK_DIR/$arch" ] && [ "$(ls -A "$SDK_DIR/$arch" 2>/dev/null)" ]; then
        SDK_COUNT=$(find "$SDK_DIR/$arch" -name "*.sh" -type f | wc -l)
        MANIFEST_COUNT=$(find "$SDK_DIR/$arch" -name "*.manifest" -type f | wc -l)
        echo "  $arch: $SDK_COUNT SDK installer(s), $MANIFEST_COUNT manifest(s)"
        echo "    URL: https://opkg.calculinux.org/sdk/$FEED_NAME/$SUBFOLDER/$arch/"
    else
        echo "  $arch: No files published"
    fi
done

# Legacy compatibility: create symlinks for backward compatibility with simple names
if [ -d "$SDK_DIR/x86_64" ] && [ "$(ls -A "$SDK_DIR/x86_64" 2>/dev/null)" ]; then
    echo ""
    echo "Creating legacy compatibility links for x86_64 SDK..."
    # Create symlinks in the root SDK directory pointing to the consistent Calculinux names
    cd "$SDK_DIR"
    if [ -f "x86_64/calculinux-sdk-${MACHINE}-x86_64.sh" ]; then
        ln -sf "x86_64/calculinux-sdk-${MACHINE}-x86_64.sh" "calculinux-sdk-${MACHINE}.sh"
        echo "  Created legacy link: calculinux-sdk-${MACHINE}.sh -> x86_64/calculinux-sdk-${MACHINE}-x86_64.sh"
    fi
    if [ -f "x86_64/calculinux-sdk-${MACHINE}-x86_64.manifest" ]; then
        ln -sf "x86_64/calculinux-sdk-${MACHINE}-x86_64.manifest" "calculinux-sdk-${MACHINE}.manifest"
        echo "  Created legacy link: calculinux-sdk-${MACHINE}.manifest -> x86_64/calculinux-sdk-${MACHINE}-x86_64.manifest"
    fi
    cd - > /dev/null
fi

echo "SDK published successfully"
