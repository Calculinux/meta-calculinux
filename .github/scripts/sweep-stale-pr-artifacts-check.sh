#!/usr/bin/env bash
# Self-check: sweep keeps open-PR artifacts across feeds and drops the rest.
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

mkdir -p "$repo/update/walnascar/pr" "$repo/image/walnascar/pr" "$repo/update/wrynose/pr"
printf 'keep\n' > "$repo/update/walnascar/pr/luckfox-lyra-pr42.raucb"
printf 'keep\n' > "$repo/image/walnascar/pr/luckfox-lyra-pr42.wic.gz"
printf 'stale\n' > "$repo/update/walnascar/pr/luckfox-lyra-pr99.raucb"
printf 'stale\n' > "$repo/update/walnascar/pr/calculinux-pr71.raucb"
printf 'stale-wry\n' > "$repo/update/wrynose/pr/luckfox-lyra-pr162.raucb"
printf 'keep-wry\n' > "$repo/update/wrynose/pr/luckfox-lyra-pr149.raucb"

if KEEP_PR_NUMBERS= bash .github/scripts/sweep-stale-pr-artifacts.sh \
    luckfox-lyra "$repo" https://opkg.example.test 2>/dev/null; then
  echo "FAIL: empty KEEP_PR_NUMBERS should refuse to sweep" >&2
  exit 1
fi
assert "[ -f '$repo/update/walnascar/pr/luckfox-lyra-pr99.raucb' ]" "empty keep list did not delete"

KEEP_PR_NUMBERS="42 149" \
  bash .github/scripts/sweep-stale-pr-artifacts.sh \
    luckfox-lyra "$repo" https://opkg.example.test

walnascar_index="$repo/update/walnascar/pr/index.json"
wrynose_index="$repo/update/wrynose/pr/index.json"

assert "[ -f '$repo/update/walnascar/pr/luckfox-lyra-pr42.raucb' ]" "sweep kept open PR RAUC"
assert "[ -f '$repo/image/walnascar/pr/luckfox-lyra-pr42.wic.gz' ]" "sweep kept open PR WIC"
assert "[ ! -f '$repo/update/walnascar/pr/luckfox-lyra-pr99.raucb' ]" "sweep removed closed PR RAUC"
assert "[ ! -f '$repo/update/walnascar/pr/calculinux-pr71.raucb' ]" "sweep removed old-name closed PR RAUC"
assert "[ ! -f '$repo/update/wrynose/pr/luckfox-lyra-pr162.raucb' ]" "sweep removed closed PR on other feed"
assert "[ -f '$repo/update/wrynose/pr/luckfox-lyra-pr149.raucb' ]" "sweep kept open PR on other feed"
assert "grep -q 'luckfox-lyra-pr42.raucb' '$walnascar_index'" "walnascar index still lists open PR"
assert "grep -q 'luckfox-lyra-pr42.wic.gz' '$walnascar_index'" "walnascar index lists kept WIC"
assert "! grep -q 'pr99' '$walnascar_index'" "walnascar index dropped closed PR"
assert "grep -q 'luckfox-lyra-pr149.raucb' '$wrynose_index'" "wrynose index lists kept PR"
assert "! grep -q 'pr162' '$wrynose_index'" "wrynose index dropped closed PR"

echo "OK: sweep-stale-pr-artifacts-check"
