#!/usr/bin/env bash
# Run one time-boxed pass of the CI build.
#
# A pass runs the whole build (image + packages, then optionally SDKs) until
# it finishes or the deadline arrives. Work finished before the deadline lands
# in SSTATE_DIR, so the next pass picks up where this one stopped: completed
# tasks come back as sstate hits and only the remainder is built.
#
# Writes done=true|false to $GITHUB_OUTPUT (or stdout outside Actions).
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 <kas-override-file> <deadline-epoch> <with-sdk:true|false>" >&2
  exit 1
fi

KAS_FILE="$1"
DEADLINE="$2"
WITH_SDK="$3"
# After SIGINT bitbake waits for running tasks; a big compile can outlast
# that, so hard-kill after this grace period.
KILL_GRACE=15m

emit() { echo "$1" >> "${GITHUB_OUTPUT:-/dev/stdout}"; }

# run_step <label> <command...>: run with whatever time is left.
# Returns 0 on success, 124 when the deadline cut it short, else the failure.
run_step() {
  local label="$1"; shift
  local left=$(( (DEADLINE - $(date +%s)) / 60 ))
  if [ "$left" -lt 5 ]; then
    echo "::notice::No time left for $label; deferring to next pass"
    return 124
  fi
  echo "::group::$label (${left} min left in this pass)"
  local rc=0
  timeout -s INT -k "$KILL_GRACE" "${left}m" "$@" || rc=$?
  echo "::endgroup::"
  # timeout reports 124 on SIGINT expiry and 137 when it had to SIGKILL.
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
    echo "::notice::$label hit the pass deadline; sstate so far is kept for the next pass"
    return 124
  fi
  return "$rc"
}

rc=0
run_step "Build image and packages" ./kas-container build "$KAS_FILE" || rc=$?

if [ "$rc" -eq 0 ] && [ "$WITH_SDK" = "true" ]; then
  for sdk_arch in x86_64 aarch64; do
    run_step "Build SDK ($sdk_arch)" bash .github/scripts/build-sdk.sh "$sdk_arch" "$KAS_FILE" || rc=$?
    [ "$rc" -eq 0 ] || break
  done
fi

case "$rc" in
  0)   emit "done=true" ;;
  124) emit "done=false" ;;
  *)   echo "::error::Build failed (exit $rc)"; exit "$rc" ;;
esac
