#!/bin/bash
# Determine feed configuration based on branch/tag
# This script determines:
# - feed_name: The name of the feed (codename or "develop")
# - subfolder: The subfolder within the feed (continuous, release, or branch)
# - is_prerelease: Whether this is a prerelease
# - is_tagged_release: Whether this is a tagged release
# - is_published_branch: Whether packages should be published
# - distro_codename: The distro codename
# - feed_subfolder: The subfolder for package URLs

set -euo pipefail

# Required parameters
KAS_FILE="${1:?Usage: $0 <kas_file> <ref_name> <ref_type>}"
REF_NAME="${2:?Usage: $0 <kas_file> <ref_name> <ref_type>}"
REF_TYPE="${3:?Usage: $0 <kas_file> <ref_name> <ref_type>}"  # "branch" or "tag"

# Get distro codename for all scenarios
echo "Extracting distro codename from kas configuration..." >&2
DISTRO_CODENAME=$(./kas-container shell "$KAS_FILE" -c "bitbake -e | grep '^DISTRO_CODENAME=' | cut -d'\"' -f2")

if [ -z "$DISTRO_CODENAME" ]; then
    echo "ERROR: Could not determine DISTRO_CODENAME from build configuration" >&2
    exit 1
fi

echo "Distro codename: $DISTRO_CODENAME" >&2

# Determine feed configuration based on ref
if [ "$REF_NAME" = "main" ]; then
    # Use distro codename for stable releases (e.g., walnascar, scarthgap)
    echo "feed_name=${DISTRO_CODENAME}"
    echo "subfolder=continuous"
    echo "is_prerelease=false"
    echo "is_tagged_release=false"
    echo "is_published_branch=true"
    echo "distro_codename=${DISTRO_CODENAME}"
    echo "feed_subfolder=continuous"
    
elif [ "$REF_NAME" = "develop" ]; then
    # Use "develop" for all development builds
    echo "feed_name=develop"
    echo "subfolder=continuous"
    echo "is_prerelease=false"
    echo "is_tagged_release=false"
    echo "is_published_branch=true"
    echo "distro_codename=develop"
    echo "feed_subfolder=continuous"
    
elif [ "$REF_TYPE" = "tag" ]; then
    # Tagged releases - publish to release folder
    echo "feed_name=${DISTRO_CODENAME}"
    echo "subfolder=release"
    echo "is_published_branch=true"
    echo "distro_codename=${DISTRO_CODENAME}"
    echo "feed_subfolder=release"
    
    # Check if this is a prerelease (contains rc, beta, or alpha)
    if [[ "$REF_NAME" =~ (rc|beta|alpha) ]]; then
        echo "is_prerelease=true"
    else
        echo "is_prerelease=false"
    fi
    echo "is_tagged_release=true"
    
else
    # Pull requests or other refs - don't publish
    echo "feed_name=${DISTRO_CODENAME}"
    echo "subfolder=branch"
    echo "is_prerelease=false"
    echo "is_tagged_release=false"
    echo "is_published_branch=false"
    echo "distro_codename=${DISTRO_CODENAME}"
    echo "feed_subfolder=continuous"
fi

echo "" >&2
echo "Feed configuration complete:" >&2
echo "  Feed URL: https://opkg.calculinux.org/ipk/${DISTRO_CODENAME}/continuous/" >&2
