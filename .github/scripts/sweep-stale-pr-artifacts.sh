#!/usr/bin/env bash
# Remove PR RAUC/WIC artifacts whose PR is no longer open, then refresh indexes.
# KEEP_PR_NUMBERS="1 2 3" skips GitHub (for tests). Otherwise lists open PRs via the API.
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

fetch_open_pr_numbers() {
  local token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  if [ -z "$token" ]; then
    echo "GH_TOKEN or GITHUB_TOKEN is required to list open PRs" >&2
    return 1
  fi
  if [ -z "$REPO" ]; then
    echo "github-repo or GITHUB_REPOSITORY is required" >&2
    return 1
  fi
  local page=1 body
  while true; do
    body="$(curl -fsS \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/${REPO}/pulls?state=open&per_page=100&page=${page}")"
    local nums
    nums="$(python3 -c 'import json,sys; data=json.load(sys.stdin); print("\n".join(str(p["number"]) for p in data))' <<<"$body")"
    if [ -z "$nums" ]; then
      break
    fi
    local n
    while IFS= read -r n; do
      [ -n "$n" ] && KEEP["$n"]=1
    done <<<"$nums"
    if [ "$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' <<<"$body")" -lt 100 ]; then
      break
    fi
    page=$((page + 1))
  done
}

if [ -v KEEP_PR_NUMBERS ]; then
  for n in $KEEP_PR_NUMBERS; do
    KEEP["$n"]=1
  done
else
  fetch_open_pr_numbers
fi

if [ ${#KEEP[@]} -eq 0 ]; then
  echo "Refusing to sweep: open-PR list is empty (that would delete every PR artifact)" >&2
  exit 1
fi

echo "Keeping PR artifacts for: ${!KEEP[*]}"

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
