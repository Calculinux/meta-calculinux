#!/bin/bash
# Copy a file and generate its .sha256 checksum.
# Usage: copy-with-checksum.sh <src> <dest>
set -euo pipefail

src="${1:?Usage: $0 <src> <dest>}"
dest="${2:?Usage: $0 <src> <dest>}"

cp "$src" "$dest"
sha256sum "$dest" > "${dest}.sha256"
