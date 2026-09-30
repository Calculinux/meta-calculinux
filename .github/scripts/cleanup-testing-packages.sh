#!/usr/bin/env bash
# Remove a closed PR's packages from the shared testing feed, keeping any
# file another open PR also published. See lib/testing-feed.sh.
set -euo pipefail
export LC_ALL=C

if [ $# -lt 3 ]; then
  echo "Usage: $0 <opkg-repo-dir> <feed-name> <pr-number>" >&2
  exit 1
fi

OPKG_REPO_DIR="$1"
FEED_NAME="$2"
PR_NUMBER="$3"

[[ "$PR_NUMBER" =~ ^[0-9]+$ ]] || { echo "Bad PR number: $PR_NUMBER" >&2; exit 1; }
[[ "$FEED_NAME" =~ ^[a-z0-9_-]+$ ]] || { echo "Bad feed name: $FEED_NAME" >&2; exit 1; }

TESTING_DIR="$OPKG_REPO_DIR/ipk/$FEED_NAME/testing"
MANIFEST="$TESTING_DIR/.manifests/pr${PR_NUMBER}.txt"
# shellcheck source=SCRIPTDIR/lib/testing-feed.sh
source "$(dirname "$0")/lib/testing-feed.sh"
lock_feed

if [ ! -f "$MANIFEST" ]; then
  echo "PR #$PR_NUMBER has no packages in the testing feed"
  exit 0
fi

candidates=$(mktemp)
cp "$MANIFEST" "$candidates"
rm -f "$MANIFEST"
touched=$(drop_unreferenced "$candidates" "$PR_NUMBER")
rm -f "$candidates"
# shellcheck disable=SC2086
reindex $touched
echo "Removed PR #$PR_NUMBER from the testing feed"
