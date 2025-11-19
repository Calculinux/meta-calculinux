#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <sdkmachine> <kas-override-file> [target-recipe]" >&2
  exit 1
fi

SDKMACHINE="$1"
BASE_KAS_FILE="$2"
TARGET_RECIPE="${3:-calculinux-image}"

if [ -z "$SDKMACHINE" ] || [ -z "$BASE_KAS_FILE" ]; then
  echo "sdkmachine and kas override file are required" >&2
  exit 1
fi

OUTPUT_KAS="kas-sdk-${SDKMACHINE}.yaml"

cat > "$OUTPUT_KAS" <<EOF
header:
  version: 18
  includes:
    - $BASE_KAS_FILE

local_conf_header:
  sdk_${SDKMACHINE}: |
    SDKMACHINE = "$SDKMACHINE"
EOF

echo "Building SDK for SDKMACHINE=$SDKMACHINE using $BASE_KAS_FILE"
./kas-container --ssh-dir ~/.ssh build --update "$OUTPUT_KAS" --target "$TARGET_RECIPE" -c populate_sdk

echo "SDK build for $SDKMACHINE completed"
