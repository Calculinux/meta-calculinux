#!/usr/bin/env bash
# Check the image launcher bundled in the x86_64 emulator AppImage: list,
# download and remove an image through a local index of the disk image just
# built, and open the launcher window on SDL's dummy video driver.
# Usage: emulator-launcher-test.sh <appimage> <disk image>
set -euo pipefail

appimage="$(readlink -f "${1:?Usage: $0 <appimage> <disk image>}")"
disk="$(readlink -f "${2:?Usage: $0 <appimage> <disk image>}")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() {
    echo "::error::emulator launcher: $*"
    exit 1
}

# A feed laid out like the webserver, indexed by the script the publish job runs.
feed="$work/feed/image/walnascar/continuous"
name="calculinux-image-calculinux-qemuarm.rootfs.qcow2"
mkdir -p "$feed"
cp "$disk" "$feed/$name"
(cd "$feed" && sha256sum "$name" > "$name.sha256")
python3 "$SCRIPT_DIR/generate-emulator-index.py" --repo-dir "$work/feed" --base-url "file://$work/feed"

export APPIMAGE_EXTRACT_AND_RUN=1
export CALCULINUX_EMULATOR_HOME="$work/state"
export CALCULINUX_EMULATOR_INDEX_URL="file://$work/feed/emulator/calculinux-qemuarm/index.json"

"$appimage" --list > "$work/list"
grep -q '^continuous-main  *Not downloaded' "$work/list" || fail "--list: $(cat "$work/list")"

"$appimage" --download continuous-main
cmp -s "$disk" "$work/state/images/continuous-main/base.qcow2" || fail "--download: image differs"
"$appimage" --list | grep -q '^continuous-main  *Downloaded' || fail "--list after --download"

# The window: draws, then closes itself (the emulator exits 0 without booting).
SDL_VIDEODRIVER=dummy CALCULINUX_LAUNCHER_SMOKE=10 "$appimage" || fail "launcher window (exit $?)"

"$appimage" --remove continuous-main
[ ! -e "$work/state/images/continuous-main" ] || fail "--remove left the image"

# The real index over HTTPS: bundled TLS, CA certificates, name resolution.
# Not fatal: the runner may have no route to the server.
unset CALCULINUX_EMULATOR_INDEX_URL
if "$appimage" --list 2>&1 >/dev/null | grep -q 'cannot fetch the image index'; then
    echo "::warning::emulator launcher could not fetch the published index over HTTPS"
fi

echo "Emulator launcher checks passed"
