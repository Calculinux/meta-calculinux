#!/usr/bin/env bash
# Self-check: sweep keeps open-PR artifacts and the last N dated continuous builds.
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
repo="$tmpdir/opkg"

mkdir -p \
  "$repo/update/walnascar/pr" "$repo/image/walnascar/pr" "$repo/update/wrynose/pr" \
  "$repo/update/walnascar/continuous" "$repo/image/walnascar/continuous"

printf 'keep\n' > "$repo/update/walnascar/pr/luckfox-lyra-pr42.raucb"
printf 'keep\n' > "$repo/image/walnascar/pr/luckfox-lyra-pr42.wic.gz"
printf 'stale\n' > "$repo/update/walnascar/pr/luckfox-lyra-pr99.raucb"
printf 'stale\n' > "$repo/update/walnascar/pr/calculinux-pr71.raucb"
printf 'stale-wry\n' > "$repo/update/wrynose/pr/luckfox-lyra-pr162.raucb"
printf 'keep-wry\n' > "$repo/update/wrynose/pr/luckfox-lyra-pr149.raucb"

# Dated continuous builds (newest last) plus unversioned "latest"
for ts in 20260101000000 20260201000000 20260301000000 20260401000000 20260501000000 20260601000000; do
  printf 'c-%s\n' "$ts" > "$repo/update/walnascar/continuous/calculinux-bundle-luckfox-lyra-${ts}.raucb"
  printf 'c-%s\n' "$ts" > "$repo/image/walnascar/continuous/calculinux-image-luckfox-lyra.rootfs-${ts}.wic.gz"
done
printf 'latest\n' > "$repo/update/walnascar/continuous/calculinux-bundle-luckfox-lyra.raucb"
printf 'latest\n' > "$repo/image/walnascar/continuous/calculinux-image-luckfox-lyra.rootfs.wic.gz"

if unset KEEP_PR_NUMBERS; ! GH_TOKEN= GITHUB_TOKEN= bash .github/scripts/sweep-published-artifacts.sh \
    luckfox-lyra "$repo" https://opkg.example.test 2>/dev/null; then
  :
else
  echo "FAIL: missing GitHub token should refuse to sweep" >&2
  exit 1
fi
assert "[ -f '$repo/update/walnascar/pr/luckfox-lyra-pr99.raucb' ]" "failed fetch did not delete"
assert "[ -f '$repo/update/walnascar/continuous/calculinux-bundle-luckfox-lyra-20260101000000.raucb' ]" "failed fetch did not prune continuous"

KEEP_PR_NUMBERS="42 149" KEEP_CONTINUOUS=4 \
  bash .github/scripts/sweep-published-artifacts.sh \
    luckfox-lyra "$repo" https://opkg.example.test

walnascar_index="$repo/update/walnascar/pr/index.json"
wrynose_index="$repo/update/wrynose/pr/index.json"
cont_index="$repo/update/walnascar/continuous/index.json"

assert "[ -f '$repo/update/walnascar/pr/luckfox-lyra-pr42.raucb' ]" "sweep kept open PR RAUC"
assert "[ -f '$repo/image/walnascar/pr/luckfox-lyra-pr42.wic.gz' ]" "sweep kept open PR WIC"
assert "[ ! -f '$repo/update/walnascar/pr/luckfox-lyra-pr99.raucb' ]" "sweep removed closed PR RAUC"
assert "[ ! -f '$repo/update/walnascar/pr/calculinux-pr71.raucb' ]" "sweep removed old-name closed PR RAUC"
assert "[ ! -f '$repo/update/wrynose/pr/luckfox-lyra-pr162.raucb' ]" "sweep removed closed PR on other feed"
assert "[ -f '$repo/update/wrynose/pr/luckfox-lyra-pr149.raucb' ]" "sweep kept open PR on other feed"
assert "grep -q 'luckfox-lyra-pr42.raucb' '$walnascar_index'" "walnascar index still lists open PR"
assert "! grep -q 'pr99' '$walnascar_index'" "walnascar index dropped closed PR"
assert "grep -q 'luckfox-lyra-pr149.raucb' '$wrynose_index'" "wrynose index lists kept PR"

assert "[ -f '$repo/update/walnascar/continuous/calculinux-bundle-luckfox-lyra.raucb' ]" "kept unversioned latest RAUC"
assert "[ -f '$repo/image/walnascar/continuous/calculinux-image-luckfox-lyra.rootfs.wic.gz' ]" "kept unversioned latest WIC"
assert "[ ! -f '$repo/update/walnascar/continuous/calculinux-bundle-luckfox-lyra-20260101000000.raucb' ]" "dropped oldest continuous RAUC"
assert "[ ! -f '$repo/update/walnascar/continuous/calculinux-bundle-luckfox-lyra-20260201000000.raucb' ]" "dropped 2nd oldest continuous RAUC"
assert "[ -f '$repo/update/walnascar/continuous/calculinux-bundle-luckfox-lyra-20260301000000.raucb' ]" "kept 4th newest continuous RAUC"
assert "[ -f '$repo/update/walnascar/continuous/calculinux-bundle-luckfox-lyra-20260601000000.raucb' ]" "kept newest continuous RAUC"
assert "[ -f '$repo/image/walnascar/continuous/calculinux-image-luckfox-lyra.rootfs-20260601000000.wic.gz' ]" "kept matching newest WIC"
assert "[ ! -f '$repo/image/walnascar/continuous/calculinux-image-luckfox-lyra.rootfs-20260101000000.wic.gz' ]" "dropped matching oldest WIC"
assert "grep -q '20260601000000' '$cont_index'" "continuous index lists newest"
assert "! grep -q '20260101000000' '$cont_index'" "continuous index dropped oldest"

echo "OK: sweep-published-artifacts-check"
