#!/usr/bin/env bash
# Regenerate Packages.gz for one opkg feed architecture directory, the same
# way the sync-packages action does. An empty directory gets an empty index.
set -euo pipefail

ARCH_DIR="${1:?Usage: $0 <feed-arch-dir>}"

cd "$ARCH_DIR"
opkg-make-index -p Packages .
gzip -f Packages
echo "Indexed $ARCH_DIR"
