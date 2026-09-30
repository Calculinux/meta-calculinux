#!/usr/bin/env bash
# Shrink SSTATE_DIR to what the next warm build needs before it is saved as
# the shared Actions cache (repo limit 50 GB; the two newest entries are kept).
#
# Keeps only sstate objects this build's task hashes refer to: sstate.bbclass
# touches every object it finds while checking hashes (sstate_checkhashes),
# and atimes were zeroed after restore so relatime records any other read.
# Objects left by older hashes are dropped, and so are image-level objects,
# which can never be reused.
#
# If that is still over budget, do_package objects go next: a warm build
# only needs them when do_package_write_ipk reruns for an unchanged recipe,
# and then that recipe recompiles instead.
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 <sstate-dir> <pass-marker-file> <budget-MiB>" >&2
  exit 1
fi

SSTATE_DIR="$1"
MARKER="$2"
BUDGET_MIB="$3"

size_mib() { du -sm "$SSTATE_DIR" | cut -f1; }

echo "sstate before pruning: $(size_mib) MiB"

# Objects neither written, refreshed nor read by this pass.
find "$SSTATE_DIR" -type f ! -path "$SSTATE_DIR/persistent/*" \
  ! -newer "$MARKER" ! -anewer "$MARKER" -delete

# Image and bundle objects: DISTRO_VERSION carries the commit hash, so these
# are rebuilt on every commit and never hit.
find "$SSTATE_DIR" -type f \( -name 'sstate:calculinux-image:*' -o -name 'sstate:calculinux-bundle:*' \) -delete

find "$SSTATE_DIR" -type d -empty -delete

size=$(size_mib)
if [ "$size" -gt "$BUDGET_MIB" ]; then
  echo "${size} MiB is over budget; dropping do_package objects"
  find "$SSTATE_DIR" -type f -name 'sstate:*_package.tar.zst*' -delete
  size=$(size_mib)
fi
echo "sstate after pruning: ${size} MiB (budget ${BUDGET_MIB} MiB)"
echo "by task:"
find "$SSTATE_DIR" -name '*.tar.zst' -printf '%s %f\n' \
  | sed -E 's/^([0-9]+) .*[0-9a-f]{64}_([a-z_]+)\.tar\.zst$/\2 \1/' \
  | awk '{s[$1]+=$2} END {for (k in s) printf "  %8.0f MiB  %s\n", s[k]/2^20, k}' \
  | sort -rn | head -8

if [ "$size" -gt "$BUDGET_MIB" ]; then
  echo "::warning::Pruned sstate (${size} MiB) exceeds the cache budget (${BUDGET_MIB} MiB); the save may be rejected or evict everything else"
fi
