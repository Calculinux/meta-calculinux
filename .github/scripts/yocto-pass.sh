#!/usr/bin/env bash
# Run one time-boxed pass of the CI build.
#
# A pass runs its lane until it finishes or the deadline arrives. Work
# finished before the deadline lands in SSTATE_DIR, so the next pass picks up
# where this one stopped: completed tasks come back as sstate hits and only
# the remainder is built.
#
# Lanes:
#   image  the image, bundle and package feed (kas targets)
#   sdk    the SDK for each SDKMACHINE in turn; an SDK finished in an earlier
#          pass is all sstate hits, so rerunning it costs little
#
# Writes done=true|false to $GITHUB_OUTPUT (or stdout outside Actions).
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 <kas-override-file> <deadline-epoch> <image|sdk>" >&2
  exit 1
fi

KAS_FILE="$1"
DEADLINE="$2"
LANE="$3"
SDK_MACHINES="x86_64 aarch64"
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
    echo "::notice::No time left for $label; deferring to the next pass"
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
case "$LANE" in
  image)
    run_step "Build image and packages" ./kas-container build "$KAS_FILE" || rc=$?
    ;;
  sdk)
    for sdk_machine in $SDK_MACHINES; do
      run_step "Build SDK ($sdk_machine)" bash .github/scripts/build-sdk.sh "$sdk_machine" "$KAS_FILE" || rc=$?
      [ "$rc" -eq 0 ] || break
    done
    ;;
  *)
    echo "Unknown lane: $LANE" >&2
    exit 1
    ;;
esac

case "$rc" in
  0)   emit "done=true" ;;
  124) emit "done=false" ;;
  *)   echo "::error::Build failed (exit $rc)"; exit "$rc" ;;
esac
