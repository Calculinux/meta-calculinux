#!/usr/bin/env bash
# Manual sweep: keep open-PR artifacts and the last KEEP_CONTINUOUS dated continuous builds.
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
KEEP_CONTINUOUS="${KEEP_CONTINUOUS:-4}"

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
  echo "No open PRs; removing all PR-channel artifacts"
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

sweep_pr_dir() {
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

reindex_pr() {
  local feed="$1"
  local pr_dir="$OPKG_REPO_DIR/update/${feed}/pr"
  local image_dir="$OPKG_REPO_DIR/image/${feed}/pr"
  # Index always lives under update/<feed>/pr (same as publish-pr-bundle.sh).
  # Image-only feeds still need that dir so WIC entries are indexed after a sweep.
  if [ ! -d "$pr_dir" ] && [ ! -d "$image_dir" ]; then
    return 0
  fi
  mkdir -p "$pr_dir"
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

reindex_continuous() {
  local feed="$1"
  local update_dir="$OPKG_REPO_DIR/update/${feed}/continuous"
  local image_dir="$OPKG_REPO_DIR/image/${feed}/continuous"
  [ -d "$update_dir" ] || return 0
  python3 "$SCRIPT_DIR/generate-artifact-index.py" \
    --base-url "$UPDATE_BASE_URL" \
    --update-dir "$update_dir" \
    --image-dir "$image_dir" \
    --output "$update_dir/index.json" \
    --feed-name "$feed" \
    --subfolder "continuous" \
    --machine "$MACHINE"
}

# Dated continuous files look like ...-YYYYMMDDHHMMSS.raucb / .wic.gz
continuous_stamp() {
  local name="$1"
  if [[ "$name" =~ -([0-9]{14})\. ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

prune_continuous_feed() {
  local feed="$1"
  local update_dir="$OPKG_REPO_DIR/update/${feed}/continuous"
  local image_dir="$OPKG_REPO_DIR/image/${feed}/continuous"
  local dir stamp
  declare -A stamps=()

  shopt -s nullglob
  for dir in "$update_dir" "$image_dir"; do
    [ -d "$dir" ] || continue
    local f
    for f in "$dir"/*; do
      stamp="$(continuous_stamp "$(basename "$f")" || true)"
      [ -n "$stamp" ] && stamps["$stamp"]=1
    done
  done

  if [ ${#stamps[@]} -eq 0 ]; then
    return 0
  fi

  local keep_list
  keep_list="$(printf '%s\n' "${!stamps[@]}" | sort -r | head -n "$KEEP_CONTINUOUS")"
  declare -A keep_stamp=()
  while IFS= read -r stamp; do
    [ -n "$stamp" ] && keep_stamp["$stamp"]=1
  done <<<"$keep_list"

  echo "Feed $feed: keeping $KEEP_CONTINUOUS newest continuous stamps: ${!keep_stamp[*]}"

  for dir in "$update_dir" "$image_dir"; do
    [ -d "$dir" ] || continue
    local f base
    for f in "$dir"/*; do
      base="$(basename "$f")"
      [ "$base" = "index.json" ] && continue
      stamp="$(continuous_stamp "$base" || true)"
      [ -n "$stamp" ] || continue
      if [ -z "${keep_stamp[$stamp]:-}" ]; then
        echo "Removing $f"
        rm -f "$f"
      fi
    done
  done
}

shopt -s nullglob
declare -A PR_FEEDS=()
for pr_dir in "$OPKG_REPO_DIR"/update/*/pr "$OPKG_REPO_DIR"/image/*/pr; do
  [ -d "$pr_dir" ] || continue
  feed="$(basename "$(dirname "$pr_dir")")"
  PR_FEEDS["$feed"]=1
  sweep_pr_dir "$pr_dir"
done
if [ ${#PR_FEEDS[@]} -gt 0 ]; then
  for feed in "${!PR_FEEDS[@]}"; do
    reindex_pr "$feed"
  done
fi

declare -A CONT_FEEDS=()
for cont_dir in "$OPKG_REPO_DIR"/update/*/continuous "$OPKG_REPO_DIR"/image/*/continuous; do
  [ -d "$cont_dir" ] || continue
  feed="$(basename "$(dirname "$cont_dir")")"
  CONT_FEEDS["$feed"]=1
done
if [ ${#CONT_FEEDS[@]} -gt 0 ]; then
  for feed in "${!CONT_FEEDS[@]}"; do
    prune_continuous_feed "$feed"
    reindex_continuous "$feed"
  done
fi
