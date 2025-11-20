#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 5 ]; then
  echo "Usage: $0 <machine> <pr-number> <artifacts-dir> <opkg-repo-dir> <update-base-url>" >&2
  exit 1
fi

MACHINE="$1"
PR_NUMBER="$2"
ARTIFACTS_DIR="$3"
OPKG_REPO_DIR="$4"
UPDATE_BASE_URL="$5"

if [ -z "$MACHINE" ] || [ -z "$PR_NUMBER" ] || [ -z "$ARTIFACTS_DIR" ] || [ -z "$OPKG_REPO_DIR" ] || [ -z "$UPDATE_BASE_URL" ]; then
  echo "All arguments are required" >&2
  exit 1
fi

BUNDLE_PATH=$(find "$ARTIFACTS_DIR" -name "calculinux-bundle-${MACHINE}-*.raucb" | head -1 || true)
if [ -z "$BUNDLE_PATH" ]; then
  echo "No RAUC bundle found for machine ${MACHINE}; skipping PR publish"
  exit 0
fi

PR_FEED="${PR_CHANNEL_FEED:-${FEED_NAME:-${DISTRO_CODENAME:-}}}"
if [ -z "$PR_FEED" ]; then
  echo "PR_FEED could not be determined (set PR_CHANNEL_FEED, FEED_NAME, or DISTRO_CODENAME)." >&2
  exit 1
fi

PR_DIR="$OPKG_REPO_DIR/update/${PR_FEED}/pr"
mkdir -p "$PR_DIR"

TARGET_BUNDLE="$PR_DIR/calculinux-pr${PR_NUMBER}.raucb"
cp "$BUNDLE_PATH" "$TARGET_BUNDLE"
sha256sum "$TARGET_BUNDLE" > "${TARGET_BUNDLE}.sha256"

echo "Published PR bundle to ${TARGET_BUNDLE}"

CHANNEL_PATH="/update/${PR_FEED}/pr"

python3 .github/scripts/refresh_pr_channel_index.py \
  --root "$PR_DIR" \
  --base-url "$UPDATE_BASE_URL" \
  --channel-path "$CHANNEL_PATH" \
  --machine "$MACHINE" \
  --feed "$PR_FEED" \
  --subfolder "pr"
