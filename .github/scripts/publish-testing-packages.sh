#!/usr/bin/env bash
# Publish a PR's newly built packages to the shared testing feed,
# ipk/<feed>/testing/<arch>/, replacing what that PR published before.
#
# The artifact comes from a PR build, so names are validated before anything
# touches the feed. See lib/testing-feed.sh for how shared files are tracked.
set -euo pipefail
export LC_ALL=C

if [ $# -lt 4 ]; then
  echo "Usage: $0 <opkg-repo-dir> <feed-name> <pr-number> <artifacts-dir>" >&2
  exit 1
fi

OPKG_REPO_DIR="$1"
FEED_NAME="$2"
PR_NUMBER="$3"
ARTIFACTS_DIR="$4"

[[ "$PR_NUMBER" =~ ^[0-9]+$ ]] || { echo "Bad PR number: $PR_NUMBER" >&2; exit 1; }
[[ "$FEED_NAME" =~ ^[a-z0-9_-]+$ ]] || { echo "Bad feed name: $FEED_NAME" >&2; exit 1; }

TESTING_DIR="$OPKG_REPO_DIR/ipk/$FEED_NAME/testing"
MANIFEST="$TESTING_DIR/.manifests/pr${PR_NUMBER}.txt"
# shellcheck source=SCRIPTDIR/lib/testing-feed.sh
source "$(dirname "$0")/lib/testing-feed.sh"
mkdir -p "$TESTING_DIR/.manifests"
lock_feed

new=$(mktemp)
if [ -d "$ARTIFACTS_DIR/packages" ]; then
  (cd "$ARTIFACTS_DIR/packages" && find . -mindepth 2 -maxdepth 2 -name '*.ipk' -type f -printf '%P\n') \
    | sort > "$new"
fi
while IFS= read -r entry; do
  if ! [[ "$entry" =~ ^[A-Za-z0-9._+-]+/[A-Za-z0-9._+-]+\.ipk$ ]] || [[ "$entry" == *..* ]]; then
    echo "Refusing unexpected package path: $entry" >&2
    exit 1
  fi
done < "$new"

echo "PR #$PR_NUMBER publishes $(wc -l < "$new") packages"
touched=$(mktemp)
while IFS= read -r entry; do
  mkdir -p "$TESTING_DIR/$(dirname "$entry")"
  cp "$ARTIFACTS_DIR/packages/$entry" "$TESTING_DIR/$entry"
  dirname "$entry" >> "$touched"
done < "$new"

# Files this PR published last time but not now.
dropped=$(mktemp)
if [ -f "$MANIFEST" ]; then
  comm -23 <(sort "$MANIFEST") "$new" > "$dropped"
fi
if [ -s "$new" ]; then
  cp "$new" "$MANIFEST"
else
  rm -f "$MANIFEST"
fi
drop_unreferenced "$dropped" "$PR_NUMBER" >> "$touched"

# shellcheck disable=SC2046
reindex $(cat "$touched")
rm -f "$new" "$dropped" "$touched"
