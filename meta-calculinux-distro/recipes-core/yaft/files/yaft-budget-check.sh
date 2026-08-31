#!/bin/sh
# On-device budget / Unicode smoke check for yaft on PicoCalc / Luckfox Lyra.
#
# Usage (on device, as root on the LCD console or over SSH):
#   yaft-budget-check
# For full BMP/CJK (Han ideographs), restart yaft with:
#   YAFT_FONT=/usr/share/yaft/unifont.yaftfont
set -eu

MAX_RSS_KB_IDLE=${MAX_RSS_KB_IDLE:-2560}
MAX_RSS_KB_CJK=${MAX_RSS_KB_CJK:-5120}
FONT=${YAFT_FONT:-/usr/share/yaft/console.yaftfont}

if ! command -v yaft >/dev/null; then
	echo "yaft-budget-check: yaft not installed" >&2
	exit 1
fi

if [ ! -r "$FONT" ]; then
	echo "yaft-budget-check: missing $FONT" >&2
	exit 1
fi

python3 - "$FONT" <<'PY'
import struct, sys
path = sys.argv[1]
with open(path, "rb") as f:
    hdr = f.read(24)
magic, cw, ch, gs, _ = struct.unpack("<8sIIII", hdr)
assert magic == b"YAFTFNT1", magic
assert (cw, ch, gs) in ((6, 12, 32), (8, 16, 40)), (cw, ch, gs)
print("font header ok:", path, f"{cw}x{ch}", f"glyph={gs}")
PY

rss_of() {
	awk '/^VmRSS:/ {print $2; exit}' "/proc/$1/status" 2>/dev/null || echo 0
}

pid=$(pidof yaft 2>/dev/null | awk '{print $1}')
if [ -n "${pid:-}" ]; then
	rss=$(rss_of "$pid")
	echo "yaft pid=$pid VmRSS=${rss}kB (idle budget ${MAX_RSS_KB_IDLE}kB, CJK budget ${MAX_RSS_KB_CJK}kB)"
	if [ "$rss" -gt "$MAX_RSS_KB_CJK" ]; then
		echo "yaft-budget-check: RSS over CJK budget" >&2
		exit 1
	fi
	if [ "$rss" -gt "$MAX_RSS_KB_IDLE" ]; then
		echo "yaft-budget-check: note: RSS above idle budget (ok if CJK pages faulted in)"
	fi
else
	echo "yaft not running (skip live RSS); font header check passed"
fi

printf 'budget-check: Latin café — dash – quotes “” bullet •\n'
printf 'budget-check: CJK 漢字カナ한글\n'
printf 'budget-check: box ┌─┐│└─┘\n'

echo "yaft-budget-check: ok"
if [ "$FONT" = "/usr/share/yaft/console.yaftfont" ]; then
	echo "note: Han ideographs may tofu on default 6x12; use YAFT_FONT=/usr/share/yaft/unifont.yaftfont for full BMP"
fi
echo "Manual on Lyra: kill yaft (fbcon returns); run picocalc-kbd-test and switch back"
