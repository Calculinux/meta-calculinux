#!/bin/bash
# Output the Yocto build directory (the one containing tmp/deploy).
# Used by collect-*.sh scripts.
#
# Outputs: path to build/<machine>/tmp (e.g. build/armv7at2hf-neon/tmp)
# With --optional: exit 0 with no output if not found (for collect-packages, collect-sdk)
# Otherwise: exit 1 if not found (for collect-images)
set -euo pipefail

OPTIONAL=false
[[ "${1:-}" = "--optional" ]] && OPTIONAL=true

BUILD_TMP=$(find build -name "tmp" -type d 2>/dev/null | head -1)
if [ -z "$BUILD_TMP" ]; then
    if [ "$OPTIONAL" = "true" ]; then
        exit 0
    fi
    echo "ERROR: No build directory found (expected build/*/tmp)" >&2
    exit 1
fi
echo "$BUILD_TMP"
