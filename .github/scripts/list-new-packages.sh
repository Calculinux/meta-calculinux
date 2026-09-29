#!/usr/bin/env bash
# List the IPKs this workflow run built, as <arch>/<file>.ipk lines.
#
# Packages restored from sstate keep the mtime of the build that produced
# them, so anything at least as new as the run's start was built by this run
# (in this pass or an earlier one), i.e. is new or changed relative to the
# cache it started from. Includes the few packages that embed DISTRO_VERSION
# and therefore rebuild on every commit (e.g. os-release).
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 <deploy-ipk-dir> <since-epoch> <output-file>" >&2
  exit 1
fi

IPK_DIR="$1"
SINCE="$2"
OUT="$3"

: > "$OUT"
if [ -d "$IPK_DIR" ]; then
  (cd "$IPK_DIR" && find . -mindepth 2 -maxdepth 2 -name '*.ipk' -type f -newermt "@$SINCE" -printf '%P\n') \
    | sort > "$OUT"
fi
echo "$(wc -l < "$OUT") packages built by this run"
