#!/usr/bin/env bash
# Keep the public source mirror (https://opkg.calculinux.org/.sources/) current.
#
# Runs on a self-hosted runner with a persistent DL_DIR. Fetches every source
# the CI targets need (cheap when DL_DIR is warm) with mirror tarballs enabled
# so version-controlled sources become plain files too, then copies new
# top-level files into the mirror directory. Its leading dot keeps it out of
# the site's root listing. Hosted builds use it as their first PREMIRROR.
#
# Env: DL_DIR, SSTATE_DIR (for kas-container)
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <kas-file> <mirror-dir>" >&2
  exit 1
fi

KAS_FILE="$1"
MIRROR_DIR="$2"
: "${DL_DIR:?DL_DIR must be set}"

overlay="kas-source-mirror.yaml"
cat > "$overlay" <<EOF
header:
  version: 18
  includes:
    - $KAS_FILE

local_conf_header:
  source_mirror: |
    # Pack git and other VCS checkouts as tarballs a plain HTTP mirror can serve.
    BB_GENERATE_MIRROR_TARBALLS = "1"
EOF

# Targets mirror the kas target list.
./kas-container shell "$overlay" \
  -c "bitbake --runall=fetch calculinux-bundle packagegroup-meta-calculinux-apps"

mkdir -p "$MIRROR_DIR"
list=$(mktemp)
# Top-level regular files only: tarballs and git2_*.tar.gz mirror tarballs.
# Skip BitBake's bookkeeping and leftovers of failed fetches; clone dirs such
# as git2/ are covered by their mirror tarballs.
find "$DL_DIR" -maxdepth 1 -type f \
  ! -name '*.done' ! -name '*.lock' ! -name '*.tmp' ! -name '*_bad-checksum_*' \
  -printf '%f\n' | sort > "$list"
echo "Source files in DL_DIR: $(wc -l < "$list")"

# --ignore-existing: sources are immutable by name (checksummed, or keyed by
# revision for mirror tarballs), so never rewrite what clients may be reading.
rsync -a --ignore-existing --itemize-changes --files-from="$list" "$DL_DIR"/ "$MIRROR_DIR"/ \
  | awk '{n++} END {print n+0 " new files copied to the mirror"}'
rm -f "$list" "$overlay"

du -sh "$MIRROR_DIR"
