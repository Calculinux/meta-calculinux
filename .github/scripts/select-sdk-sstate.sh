#!/usr/bin/env bash
# Stage the SDK lane's own sstate for its cache entry.
#
# The SDK lane starts from the image cache entry, so everything it needs from
# the image side is already cached there. Its entry only has to hold the rest
# (nativesdk toolchains and friends): objects not in the image entry that this
# pass created, was handed by an earlier pass, or reused. sstate_checkhashes
# touches every object the build's hashes refer to, and atimes were zeroed
# after restore, so "used" is mtime or atime newer than the pass marker.
# Objects are hardlinked, so staging costs no space.
#
# The hash equivalence database stays with the image entry; see the
# PERSISTENT_DIR note in yocto-pass.yml.
set -euo pipefail
# comm needs both lists in the same collation order as the workflow's.
export LC_ALL=C

if [ $# -lt 4 ]; then
  echo "Usage: $0 <sstate-dir> <image-file-list> <pass-marker> <out-dir>" >&2
  exit 1
fi

SSTATE_DIR="$1"
IMAGE_LIST="$2"
MARKER="$3"
OUT_DIR="$4"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

used=$(mktemp)
(cd "$SSTATE_DIR" && find . -type f ! -path './persistent/*' \( -newer "$MARKER" -o -anewer "$MARKER" \) | sort) > "$used"
comm -23 "$used" "$IMAGE_LIST" | while IFS= read -r f; do
  mkdir -p "$OUT_DIR/$(dirname "$f")"
  ln "$SSTATE_DIR/$f" "$OUT_DIR/$f"
done
rm -f "$used"

echo "SDK sstate staged: $(find "$OUT_DIR" -type f | wc -l) files, $(du -sm "$OUT_DIR" | cut -f1) MiB"
