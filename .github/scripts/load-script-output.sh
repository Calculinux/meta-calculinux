#!/usr/bin/env bash
# Run a script that outputs key=value lines (or read from file) and load into GITHUB_OUTPUT.
# Optionally also set specific keys as environment variables.
#
# Usage:
#   load-script-output.sh [--env KEY:ENV_VAR]... -- <command> [args...]
#   load-script-output.sh [--env KEY:ENV_VAR]... --from-file <path>
#
# Example:
#   load-script-output.sh -- bash .github/scripts/determine-feed-config.sh kas.yaml main branch
#   load-script-output.sh --env distro_version:DISTRO_VERSION -- bash .github/scripts/prepare-build-config.sh ...
#   load-script-output.sh --from-file workflow-metadata.env
set -euo pipefail

ENV_MAPPINGS=()
FROM_FILE=""
ENV_ALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_MAPPINGS+=("$2")
      shift 2
      ;;
    --env-all)
      ENV_ALL=true
      shift
      ;;
    --from-file)
      FROM_FILE="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ -n "$FROM_FILE" ]]; then
  if [[ ! -f "$FROM_FILE" ]]; then
    echo "File not found: $FROM_FILE" >&2
    exit 1
  fi
  TMP_FILE="$FROM_FILE"
  cat "$TMP_FILE"
else
  if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [--env KEY:ENV_VAR]... -- <command> [args...]" >&2
    exit 1
  fi
  TMP_FILE=$(mktemp)
  trap 'rm -f "$TMP_FILE"' EXIT
  "$@" > "$TMP_FILE"
  cat "$TMP_FILE"
fi

while IFS='=' read -r key value; do
  [[ -z "$key" ]] && continue
  echo "$key=$value" >> "$GITHUB_OUTPUT"
  if [[ "$ENV_ALL" == "true" ]]; then
    echo "$key=$value" >> "$GITHUB_ENV"
  fi
  for mapping in "${ENV_MAPPINGS[@]}"; do
    output_key="${mapping%%:*}"
    env_var="${mapping#*:}"
    if [[ "$key" == "$output_key" ]]; then
      echo "${env_var}=${value}" >> "$GITHUB_ENV"
    fi
  done
done < "$TMP_FILE"
