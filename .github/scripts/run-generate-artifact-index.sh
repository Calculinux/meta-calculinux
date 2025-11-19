#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 8 ]; then
  echo "Usage: $0 <opkg-repo-dir> <feed-name> <subfolder> <machine> <distro-version> <git-sha> <artifacts-dir> <base-url>" >&2
  exit 1
fi

OPKG_REPO_DIR="$1"
FEED_NAME="$2"
SUBFOLDER="$3"
MACHINE="$4"
DISTRO_VERSION="$5"
GIT_SHA="$6"
ARTIFACTS_DIR="$7"
BASE_URL="$8"

UPDATE_DIR="$OPKG_REPO_DIR/update/$FEED_NAME/$SUBFOLDER"
IMAGE_DIR="$OPKG_REPO_DIR/image/$FEED_NAME/$SUBFOLDER"
OUTPUT_FILE="$UPDATE_DIR/index.json"

mkdir -p "$UPDATE_DIR" "$IMAGE_DIR" "$ARTIFACTS_DIR"

python3 .github/scripts/generate-artifact-index.py \
  --base-url "$BASE_URL" \
  --update-dir "$UPDATE_DIR" \
  --image-dir "$IMAGE_DIR" \
  --output "$OUTPUT_FILE" \
  --feed-name "$FEED_NAME" \
  --subfolder "$SUBFOLDER" \
  --machine "$MACHINE" \
  --distro-version "$DISTRO_VERSION" \
  --git-sha "$GIT_SHA"

if [ -f "$OUTPUT_FILE" ]; then
  cp "$OUTPUT_FILE" "$ARTIFACTS_DIR/index.json"
  echo "Generated artifact index at $OUTPUT_FILE"
else
  echo "Artifact index was not created" >&2
  exit 1
fi
