#!/usr/bin/env bash
# Remove PR RAUC/WIC artifacts whose PR is no longer open, then refresh indexes.
# KEEP_PR_NUMBERS="1 2 3" skips GitHub (for tests). Otherwise uses `gh pr list`.
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 <machine> <opkg-repo-dir> <update-base-url> [github-repo]" >&2
  exit 1
fi

MACHINE="$1"
OPKG_REPO_DIR="$2"
UPDATE_BASE_URL="$3"
REPO="${4:-${GITHUB_REPOSITORY:-}}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
declare -A KEEP=()

if [ -n "${KEEP_PR_NUMBERS:-}" ]; then
  for n in $KEEP_PR_NUMBERS; do
    KEEP["$n"]=1
  done
else
  if [ -z "$REPO" ]; then
    echo "github-repo or GITHUB_REPOSITORY is required when KEEP_PR_NUMBERS is unset" >&2
    exit 1
  fi
  while IFS= read -r n; do
    [ -n "$n" ] && KEEP["$n"]=1
  done < <(gh pr list --repo "$REPO" --state open --limit 1000 --json number --jq '.[].number')
fi

if [ ${#KEEP[@]} -eq 0 ]; then
  echo "Keeping PR artifacts for: none"
else
  echo "Keeping PR artifacts for: ${!KEEP[*]}"
fi

pr_number() {
  local name="$1"
  if [[ "$name" =~ pr([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

sweep_dir() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  local f base num
  shopt -s nullglob
  for f in "$dir"/*; do
    base="$(basename "$f")"
    [ "$base" = "index.json" ] && continue
    num="$(pr_number "$base" || true)"
    [ -n "$num" ] || continue
    if [ -z "${KEEP[$num]:-}" ]; then
      echo "Removing $f"
      rm -f "$f"
    fi
  done
}

reindex() {
  local feed="$1"
  local pr_dir="$OPKG_REPO_DIR/update/${feed}/pr"
  local image_dir="$OPKG_REPO_DIR/image/${feed}/pr"
  [ -d "$pr_dir" ] || return 0
  python3 "$SCRIPT_DIR/generate-artifact-index.py" \
    --base-url "$UPDATE_BASE_URL" \
    --update-dir "$pr_dir" \
    --image-dir "$image_dir" \
    --output "$pr_dir/index.json" \
    --feed-name "$feed" \
    --subfolder "pr" \
    --machine "$MACHINE" \
    --is-pr-channel
}

shopt -s nullglob
declare -A FEEDS=()
for pr_dir in "$OPKG_REPO_DIR"/update/*/pr "$OPKG_REPO_DIR"/image/*/pr; do
  [ -d "$pr_dir" ] || continue
  feed="$(basename "$(dirname "$pr_dir")")"
  FEEDS["$feed"]=1
  sweep_dir "$pr_dir"
done

for feed in "${!FEEDS[@]}"; do
  reindex "$feed"
done
