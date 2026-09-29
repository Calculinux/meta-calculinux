#!/usr/bin/env bash
# Keep only the newest <keep> Actions cache entries with <prefix> on this ref,
# once <new-key> is confirmed saved. Scoped by ref so a branch never deletes
# main's caches. Needs GH_TOKEN with actions: write.
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 <key-prefix> <new-key> <keep-count>" >&2
  exit 1
fi

PREFIX="$1"
NEW_KEY="$2"
KEEP="$3"

keys=$(gh cache list -R "$GITHUB_REPOSITORY" --ref "$GITHUB_REF" --key "$PREFIX" \
  --sort created_at --order desc --limit 100 --json key -q '.[].key')

if ! grep -qxF "$NEW_KEY" <<< "$keys"; then
  echo "::warning::$NEW_KEY was not saved; keeping older $PREFIX caches"
  exit 0
fi

tail -n "+$((KEEP + 1))" <<< "$keys" | while read -r k; do
  [ -n "$k" ] || continue
  echo "Deleting $k"
  gh cache delete -R "$GITHUB_REPOSITORY" "$k"
done
