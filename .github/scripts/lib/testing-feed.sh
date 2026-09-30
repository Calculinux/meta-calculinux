#!/usr/bin/env bash
# Shared helpers for the PR testing feed (ipk/<feed>/testing/<arch>/).
#
# Every open PR that published packages has a manifest,
# .manifests/pr<N>.txt, listing the <arch>/<file>.ipk it put in the feed. A
# file stays while any manifest lists it; two PRs publishing the same file
# name share it and the last publish wins.
#
# Source this file; callers set TESTING_DIR.

# lock_feed: serialize writers (both self-hosted runners share the NFS feed).
# GitHub concurrency groups would cancel a queued publish, so lock instead.
lock_feed() {
  mkdir -p "$TESTING_DIR"
  exec 9>"$TESTING_DIR/.lock"
  if ! flock -w 1800 9; then
    echo "Timed out waiting for the testing feed lock" >&2
    exit 1
  fi
}

# drop_unreferenced <candidates-file> <pr-number>
# Delete candidate files no other PR's manifest lists; print their arch dirs.
drop_unreferenced() {
  local candidates="$1" pr="$2" others entry
  others=$(mktemp)
  find "$TESTING_DIR/.manifests" -name 'pr*.txt' ! -name "pr${pr}.txt" -exec cat {} + 2>/dev/null \
    | sort -u > "$others" || true
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    if ! grep -qxF "$entry" "$others"; then
      echo "Removing $entry" >&2
      rm -f "${TESTING_DIR:?}/$entry"
      dirname "$entry"
    fi
  done < "$candidates"
  rm -f "$others"
}

# reindex <arch>...: regenerate indexes for the given arch dirs, once each.
reindex() {
  local arch
  for arch in $(printf '%s\n' "$@" | sort -u); do
    [ -d "$TESTING_DIR/$arch" ] || continue
    bash "$(dirname "${BASH_SOURCE[0]}")/index-feed.sh" "$TESTING_DIR/$arch"
  done
}
