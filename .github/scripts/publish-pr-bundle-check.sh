#!/usr/bin/env bash
# Self-check: PR publish copies RAUC + WIC and cleanup removes both.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

assert() {
  local cond="$1"
  local msg="$2"
  if ! eval "$cond"; then
    echo "FAIL: $msg" >&2
    exit 1
  fi
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

artifacts="$tmpdir/artifacts"
repo="$tmpdir/opkg"
mkdir -p "$artifacts"
printf 'rauc-bundle\n' > "$artifacts/calculinux-bundle-luckfox-lyra-test.raucb"
printf 'wic-image\n' > "$artifacts/calculinux-image-luckfox-lyra.rootfs.wic.gz"

FEED_NAME=walnascar \
  bash .github/scripts/publish-pr-bundle.sh \
    luckfox-lyra 42 "$artifacts" "$repo" https://opkg.example.test

bundle="$repo/update/walnascar/pr/luckfox-lyra-pr42.raucb"
wic="$repo/image/walnascar/pr/luckfox-lyra-pr42.wic.gz"
index="$repo/update/walnascar/pr/index.json"

assert "[ -f '$bundle' ]" "published RAUC bundle"
assert "[ -f '${bundle}.sha256' ]" "published RAUC checksum"
assert "[ -f '$wic' ]" "published WIC image"
assert "[ -f '${wic}.sha256' ]" "published WIC checksum"
assert "[ -f '$index' ]" "wrote PR index"
assert "grep -q 'luckfox-lyra-pr42.raucb' '$index'" "index lists RAUC bundle"
assert "grep -q 'luckfox-lyra-pr42.wic.gz' '$index'" "index lists WIC image"
assert "grep -q '/image/walnascar/pr/luckfox-lyra-pr42.wic.gz' '$index'" "index WIC URL uses image/pr"

bash .github/scripts/cleanup-pr-bundle.sh \
  luckfox-lyra 42 "$repo" walnascar https://opkg.example.test

assert "[ ! -f '$bundle' ]" "cleanup removed RAUC bundle"
assert "[ ! -f '${bundle}.sha256' ]" "cleanup removed RAUC checksum"
assert "[ ! -f '$wic' ]" "cleanup removed WIC image"
assert "[ ! -f '${wic}.sha256' ]" "cleanup removed WIC checksum"

echo "OK: publish-pr-bundle-check"
