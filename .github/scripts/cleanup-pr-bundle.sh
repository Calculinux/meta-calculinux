#!/usr/bin/env bash
# Remove a PR RAUC bundle and regenerate the channel index.
# Used when a PR is closed to clean up its published bundle.
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
TARGET="$PR_DIR/${MACHINE}-pr${PR_NUMBER}.raucb"

if [ -f "$TARGET" ]; then
  echo "Removing $TARGET"
  rm -f "$TARGET"
else
  echo "No RAUC bundle found for PR ${PR_NUMBER}"
fi
if [ -f "${TARGET}.sha256" ]; then
  rm -f "${TARGET}.sha256"
fi

python3 .github/scripts/generate-artifact-index.py \
  --base-url "$UPDATE_BASE_URL" \
  --update-dir "$PR_DIR" \
  --output "$PR_DIR/index.json" \
  --feed-name "$FEED_NAME" \
  --subfolder "pr" \
  --machine "$MACHINE" \
  --is-pr-channel
