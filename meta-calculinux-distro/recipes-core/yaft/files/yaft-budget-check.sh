#!/bin/sh
# On-device budget / Unicode smoke check for yaft on PicoCalc / Luckfox Lyra.
#
# Usage (on device, as root on the LCD console or over SSH):
#   yaft-budget-check
# Font profiles (also via /etc/default/console CONSOLE_FONT=...):
#   default / miniwi / unifont — or set YAFT_FONT=/path/to.yaftfont
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

# Header: magic[8] + cell_w/cell_h/glyph_bytes/reserved (u32 LE each)
u32le_at() {
	# $1=offset $2=file
	set -- $(od -An -t u1 -N 4 -j "$1" -v "$2")
	echo $(( $1 + ($2 << 8) + ($3 << 16) + ($4 << 24) ))
}

magic=$(dd if="$FONT" bs=1 count=8 2>/dev/null)
cw=$(u32le_at 8 "$FONT")
ch=$(u32le_at 12 "$FONT")
gs=$(u32le_at 16 "$FONT")
if [ "$magic" != "YAFTFNT1" ]; then
	echo "yaft-budget-check: bad magic '$magic'" >&2
	exit 1
fi
case "$cw:$ch:$gs" in
4:8:24|6:12:32|8:16:40) ;;
*)
	echo "yaft-budget-check: unexpected metrics ${cw}x${ch} glyph=${gs}" >&2
	exit 1
	;;
esac
echo "font header ok: $FONT ${cw}x${ch} glyph=${gs}"

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
case "$FONT" in
*/console.yaftfont|*/miniwi.yaftfont)
	echo "note: Han ideographs may tofu; set CONSOLE_FONT=unifont (or YAFT_FONT=.../unifont.yaftfont) for full BMP"
	;;
esac
echo "Manual on Lyra: kill yaft (fbcon returns); run picocalc-kbd-test and switch back"
