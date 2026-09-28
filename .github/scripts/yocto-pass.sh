#!/usr/bin/env bash
# Run one time-boxed pass of the CI build.
#
# A pass runs the build until it finishes or the deadline arrives. Work
# finished before the deadline lands in SSTATE_DIR, so the next pass picks up
# where this one stopped: completed tasks come back as sstate hits and only
# the remainder is built.
#
# With an SDK machine given, the pass builds that SDK instead of the image.
#
# Writes done=true|false to $GITHUB_OUTPUT (or stdout outside Actions).
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <kas-override-file> <deadline-epoch> [sdkmachine]" >&2
  exit 1
fi

KAS_FILE="$1"
DEADLINE="$2"
SDK_ARCH="${3:-}"
# After SIGINT bitbake waits for running tasks; a big compile can outlast
# that, so hard-kill after this grace period.
KILL_GRACE=15m

emit() { echo "$1" >> "${GITHUB_OUTPUT:-/dev/stdout}"; }

left=$(( (DEADLINE - $(date +%s)) / 60 ))
if [ "$left" -lt 5 ]; then
  echo "::notice::No time left in this pass; deferring to the next one"
  emit "done=false"
  exit 0
fi

if [ -n "$SDK_ARCH" ]; then
  label="Build SDK ($SDK_ARCH)"
  cmd=(bash .github/scripts/build-sdk.sh "$SDK_ARCH" "$KAS_FILE")
else
  label="Build image and packages"
  cmd=(./kas-container build "$KAS_FILE")
fi

echo "::group::$label (${left} min left in this pass)"
rc=0
timeout -s INT -k "$KILL_GRACE" "${left}m" "${cmd[@]}" || rc=$?
echo "::endgroup::"

case "$rc" in
  0)
    emit "done=true" ;;
  # timeout reports 124 on SIGINT expiry and 137 when it had to SIGKILL.
  124|137)
    echo "::notice::$label hit the pass deadline; sstate so far is kept for the next pass"
    emit "done=false" ;;
  *)
    echo "::error::$label failed (exit $rc)"
    exit "$rc" ;;
esac
