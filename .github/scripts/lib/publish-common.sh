#!/bin/bash
# Shared argument parsing and helpers for publish scripts.
# Source this from publish-images.sh and publish-sdk.sh:
#   source "$(dirname "$0")/lib/publish-common.sh" "$@"
#
# Sets: OPKG_REPO_DIR, FEED_NAME, SUBFOLDER, MACHINE, ARTIFACTS_DIR,
#       IS_TAGGED_RELEASE, IS_PRERELEASE, TAG_NAME,
#       UPDATE_DIR, IMAGE_DIR, SDK_DIR
#
# Provides: copy_with_checksum SRC DEST

set -euo pipefail

_usage="Usage: <script> <opkg_repo_dir> <feed_name> <subfolder> <machine> <artifacts_dir> <is_tagged_release> <is_prerelease> [tag_name]"

OPKG_REPO_DIR="${1:?$_usage}"
FEED_NAME="${2:?$_usage}"
SUBFOLDER="${3:?$_usage}"
MACHINE="${4:?$_usage}"
ARTIFACTS_DIR="${5:?$_usage}"
IS_TAGGED_RELEASE="${6:?$_usage}"
IS_PRERELEASE="${7:?$_usage}"
TAG_NAME="${8:-}"

# Derived paths
UPDATE_DIR="$OPKG_REPO_DIR/update/$FEED_NAME/$SUBFOLDER"
IMAGE_DIR="$OPKG_REPO_DIR/image/$FEED_NAME/$SUBFOLDER"
SDK_DIR="$OPKG_REPO_DIR/sdk/$FEED_NAME/$SUBFOLDER"

# Shift args so caller's $1..$N are consumed (if sourcing and passing "$@")
# Caller should use: source lib/publish-common.sh "$@"  (no shift needed - we don't shift)
# The caller won't have access to remaining args after source, so we don't shift.

copy_with_checksum() {
    bash "$(dirname "$0")/copy-with-checksum.sh" "$1" "$2"
}
