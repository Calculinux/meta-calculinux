#!/usr/bin/env bash
# Trim DL_DIR before it is saved as the shared downloads cache.
#
# A warm build fetches almost nothing, so "used by this build" would empty
# the cache. BitBake refreshes a download's <name>.done stamp whenever a fetch
# task uses it, so instead keep anything whose stamp was touched within
# <keep-days>, and drop leftovers of interrupted or failed fetches.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <dl-dir> <keep-days>" >&2
  exit 1
fi

DL_DIR="$1"
KEEP_DAYS="$2"

echo "downloads before pruning: $(du -sm "$DL_DIR" | cut -f1) MiB"

# Interrupted fetches, lock files and renamed checksum failures.
find "$DL_DIR" \( -name '*.tmp' -o -name '*.lock' -o -name '*_bad-checksum_*' \) -prune -exec rm -rf {} +

# Stale downloads: drop the stamp and what it covers (a file, or a git2/ or
# similar directory named the same without .done).
find "$DL_DIR" -name '*.done' -mtime "+$KEEP_DAYS" -print0 |
  while IFS= read -r -d '' stamp; do
    rm -rf "${stamp%.done}" "$stamp"
  done

echo "downloads after pruning: $(du -sm "$DL_DIR" | cut -f1) MiB"
