#!/usr/bin/env bash
# List the IPKs this workflow run built, as <arch>/<file>.ipk lines.
#
# Packages restored from sstate keep the mtime of the build that produced
# them, so anything at least as new as the run's start was built by this run
# (in this pass or an earlier one), i.e. is new or changed relative to the
# cache it started from.
#
# The SKIP_PKGS below rebuild on every commit: their content embeds
# DISTRO_VERSION or MACHINE, which track the built revision. Shipping them
# in every PR only adds noise to the PR comment, the testing feed and the
# close-time cleanup, so they are dropped here. The drop is lifted when the
# change list (4th arg) shows a recipe for that package among the ref's
# changes, so a PR that really does alter them still ships them.
set -euo pipefail

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "Usage: $0 <deploy-ipk-dir> <since-epoch> <output-file> [changed-files]" >&2
  echo "  changed-files: one path per line that this ref changed vs its base" >&2
  echo "                 (e.g. git diff --name-only origin/main...HEAD)," >&2
  echo "                 consulted to lift the SKIP_PKGS drop" >&2
  exit 1
fi

IPK_DIR="$1"
SINCE="$2"
OUT="$3"
CHANGED="${4:-}"
if [ -n "$CHANGED" ] && [ ! -r "$CHANGED" ]; then
  CHANGED=""
fi

# Recipe roots whose output embeds DISTRO_VERSION/MACHINE and therefore
# rebuilds on every commit. A root also covers its sub/split packages
# (base-files-dev/-dbg/-doc, os-release-initrd, ...).
SKIP_PKGS=(os-release base-files)

# True if CHANGED holds a plausible recipe file for $1: os-release.bb,
# os-release_3.0.bb, os-release_%.bbappend, os-release-initrd.bb, ...
changed_touched() {
  local root="$1" p base stem
  [ -n "$CHANGED" ] || return 1
  while IFS= read -r p; do
    base="${p##*/}"
    case "$base" in
      *.bb | *.bbappend | *.inc) ;;
      *) continue ;;
    esac
    stem="${base%.*}"
    if [ "$stem" = "$root" ]; then
      return 0
    elif [[ "$stem" == "$root"[-_.%]* ]]; then
      return 0
    fi
  done < "$CHANGED"
  return 1
}

BUILT="$(mktemp)"
SKIPPED="$(mktemp)"
trap 'rm -f "$BUILT" "$SKIPPED"' EXIT

: > "$OUT"
if [ -d "$IPK_DIR" ]; then
  (cd "$IPK_DIR" && find . -mindepth 2 -maxdepth 2 -name '*.ipk' -type f -newermt "@$SINCE" -printf '%P\n') \
    | sort > "$BUILT"
else
  : > "$BUILT"
fi

while IFS= read -r ipk; do
  [ -n "$ipk" ] || continue
  pn="${ipk##*/}"
  pn="${pn%%_*}"                      # package name (before _<version>)
  skip_root=""
  for s in "${SKIP_PKGS[@]}"; do
    if [ "$pn" = "$s" ] || [[ "$pn" == "$s"-* ]]; then
      skip_root="$s"
      break
    fi
  done
  if [ -n "$skip_root" ] && ! changed_touched "$skip_root"; then
    echo "$ipk" >> "$SKIPPED"
    continue
  fi
  echo "$ipk" >> "$OUT"
done < "$BUILT"

skipped_n=$(wc -l < "$SKIPPED")
echo "$(wc -l < "$OUT") packages built by this run"
if [ "$skipped_n" -gt 0 ]; then
  echo "Not publishing $skipped_n always-rebuilding package(s) untouched by this PR:"
  sed 's/^/  /' "$SKIPPED"
fi
