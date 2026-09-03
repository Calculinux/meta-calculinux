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
WIC_PATH=$(find "$ARTIFACTS_DIR" -name "calculinux-image-${MACHINE}*.wic.gz" | head -1 || true)
if [ -z "$BUNDLE_PATH" ] && [ -z "$WIC_PATH" ]; then
  echo "No RAUC bundle or WIC image found for machine ${MACHINE}; skipping PR publish"
  exit 0
fi

PR_FEED="${PR_CHANNEL_FEED:-${FEED_NAME:-${DISTRO_CODENAME:-}}}"
if [ -z "$PR_FEED" ]; then
  echo "PR_FEED could not be determined (set PR_CHANNEL_FEED, FEED_NAME, or DISTRO_CODENAME)." >&2
  exit 1
fi

PR_DIR="$OPKG_REPO_DIR/update/${PR_FEED}/pr"
IMAGE_DIR="$OPKG_REPO_DIR/image/${PR_FEED}/pr"
mkdir -p "$PR_DIR" "$IMAGE_DIR"

if [ -n "$BUNDLE_PATH" ]; then
  TARGET_BUNDLE="$PR_DIR/${MACHINE}-pr${PR_NUMBER}.raucb"
  bash "$(dirname "$0")/lib/copy-with-checksum.sh" "$BUNDLE_PATH" "$TARGET_BUNDLE"
  echo "Published PR bundle to ${TARGET_BUNDLE}"
else
  echo "No RAUC bundle found for machine ${MACHINE}; skipping bundle publish"
fi

if [ -n "$WIC_PATH" ]; then
  TARGET_WIC="$IMAGE_DIR/${MACHINE}-pr${PR_NUMBER}.wic.gz"
  bash "$(dirname "$0")/lib/copy-with-checksum.sh" "$WIC_PATH" "$TARGET_WIC"
  echo "Published PR WIC image to ${TARGET_WIC}"
else
  echo "No WIC image found for machine ${MACHINE}; skipping image publish"
fi

INDEX_ARGS=(
  --base-url "$UPDATE_BASE_URL"
  --update-dir "$PR_DIR"
  --image-dir "$IMAGE_DIR"
  --output "$PR_DIR/index.json"
  --feed-name "$PR_FEED"
  --subfolder "pr"
  --machine "$MACHINE"
  --is-pr-channel
)
if [ -f "$ARTIFACTS_DIR/version-manifest.env" ]; then
  INDEX_ARGS+=(--version-manifest "$ARTIFACTS_DIR/version-manifest.env")
fi
python3 .github/scripts/generate-artifact-index.py "${INDEX_ARGS[@]}"
