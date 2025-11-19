#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 6 ]; then
  echo "Usage: $0 <output-file> <config-name> <machine> <target> <kas-file> <dockerfile>" >&2
  exit 1
fi

OUTPUT_FILE="$1"
CONFIG_NAME="$2"
MACHINE="$3"
TARGET="$4"
KAS_FILE="$5"
DOCKERFILE="$6"

mkdir -p "$(dirname "$OUTPUT_FILE")"

cat > "$OUTPUT_FILE" <<EOF
Build Information
=================
Repository: ${GITHUB_REPOSITORY}
Commit: ${GITHUB_SHA}
Branch/Tag: ${GITHUB_REF_NAME}
Build Date: $(date -u)
Configuration: ${CONFIG_NAME}
Machine: ${MACHINE}
Target: ${TARGET}
Kas File: ${KAS_FILE}
Dockerfile: ${DOCKERFILE}
Workflow: ${GITHUB_WORKFLOW}
Run Number: ${GITHUB_RUN_NUMBER}
EOF

if git log -1 --format="%H %s" >> "$OUTPUT_FILE" 2>/dev/null; then
  LAST_COMMIT=$(git log -1 --format='%H %s')
  echo "Last Commit: ${LAST_COMMIT}" >> "$OUTPUT_FILE"
fi

echo "Wrote build metadata to ${OUTPUT_FILE}"
