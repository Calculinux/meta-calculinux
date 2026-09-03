#!/usr/bin/env bash
# Remove a PR RAUC bundle and WIC image, then regenerate the channel index.
# Used when a PR is closed to clean up its published artifacts.
set -euo pipefail

if [ $# -lt 5 ]; then
  echo "Usage: $0 <machine> <pr-number> <opkg-repo-dir> <feed-name> <update-base-url>" >&2
  exit 1
fi

MACHINE="$1"
PR_NUMBER="$2"
OPKG_REPO_DIR="$3"
FEED_NAME="$4"
UPDATE_BASE_URL="$5"

PR_DIR="$OPKG_REPO_DIR/update/${FEED_NAME}/pr"
IMAGE_DIR="$OPKG_REPO_DIR/image/${FEED_NAME}/pr"
TARGET="$PR_DIR/${MACHINE}-pr${PR_NUMBER}.raucb"
TARGET_WIC="$IMAGE_DIR/${MACHINE}-pr${PR_NUMBER}.wic.gz"

remove_published() {
  local path="$1"
  local label="$2"
  if [ -f "$path" ]; then
    echo "Removing $path"
    rm -f "$path"
  else
    echo "No $label found for PR ${PR_NUMBER}"
  fi
  rm -f "${path}.sha256"
}

remove_published "$TARGET" "RAUC bundle"
remove_published "$TARGET_WIC" "WIC image"

python3 .github/scripts/generate-artifact-index.py \
  --base-url "$UPDATE_BASE_URL" \
  --update-dir "$PR_DIR" \
  --image-dir "$IMAGE_DIR" \
  --output "$PR_DIR/index.json" \
  --feed-name "$FEED_NAME" \
  --subfolder "pr" \
  --machine "$MACHINE" \
  --is-pr-channel
