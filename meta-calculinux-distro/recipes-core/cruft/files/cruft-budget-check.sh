#!/bin/sh
# On-device budget / Unicode smoke check for cruft on PicoCalc / Luckfox Lyra.
#
# Usage (on device, as root on the LCD console or over SSH):
#   cruft-budget-check
# Font profiles (also via /etc/default/console CONSOLE_FONT=...):
#   default / miniwi / unifont — or set CRUFT_FONT=/path/to.cruftfont
set -eu

MAX_RSS_KB_IDLE=${MAX_RSS_KB_IDLE:-1536}
MAX_RSS_KB_CJK=${MAX_RSS_KB_CJK:-4096}
FONT=${CRUFT_FONT:-${YAFT_FONT:-/usr/share/cruft/console.cruftfont}}

if ! command -v cruft >/dev/null; then
	echo "cruft-budget-check: cruft not installed" >&2
	exit 1
fi

if [ ! -r "$FONT" ]; then
	echo "cruft-budget-check: missing $FONT" >&2
	exit 1
fi

# Header: magic[8] + cell_w/cell_h/glyph_bytes/page_shift (u32 LE each)
u32le_at() {
	set -- $(od -An -t u1 -N 4 -j "$1" -v "$2")
	echo $(( $1 + ($2 << 8) + ($3 << 16) + ($4 << 24) ))
}

magic=$(dd if="$FONT" bs=1 count=8 2>/dev/null)
cw=$(u32le_at 8 "$FONT")
ch=$(u32le_at 12 "$FONT")
gs=$(u32le_at 16 "$FONT")
ps=$(u32le_at 20 "$FONT")
if [ "$magic" != "CRUFTFN1" ]; then
	echo "cruft-budget-check: bad magic '$magic'" >&2
	exit 1
fi
if [ "$ps" != "8" ]; then
	echo "cruft-budget-check: unexpected page_shift $ps" >&2
	exit 1
fi
case "$cw:$ch:$gs" in
4:8:24|6:12:32|8:16:40) ;;
*)
	echo "cruft-budget-check: unexpected metrics ${cw}x${ch} glyph=${gs}" >&2
	exit 1
	;;
esac
echo "font header ok: $FONT ${cw}x${ch} glyph=${gs} page_shift=${ps}"

rss_of() {
	awk '/^VmRSS:/ {print $2; exit}' "/proc/$1/status" 2>/dev/null || echo 0
}

pid=$(pidof cruft 2>/dev/null | awk '{print $1}')
if [ -n "${pid:-}" ]; then
	rss=$(rss_of "$pid")
	echo "cruft pid=$pid VmRSS=${rss}kB (idle budget ${MAX_RSS_KB_IDLE}kB, CJK budget ${MAX_RSS_KB_CJK}kB)"
	if [ "$rss" -gt "$MAX_RSS_KB_CJK" ]; then
		echo "cruft-budget-check: RSS over CJK budget" >&2
		exit 1
	fi
	if [ "$rss" -gt "$MAX_RSS_KB_IDLE" ]; then
		echo "cruft-budget-check: note: RSS above idle budget (ok if CJK pages faulted in)"
	fi
else
	echo "cruft not running (skip live RSS); font header check passed"
fi

printf 'budget-check: Latin café — dash – quotes “” bullet •\n'
printf 'budget-check: CJK 漢字カナ한글\n'
printf 'budget-check: box ┌─┐│└─┘\n'

echo "cruft-budget-check: ok"
case "$FONT" in
*/console.cruftfont|*/miniwi.cruftfont)
	echo "note: Han ideographs may tofu; set CONSOLE_FONT=unifont (or CRUFT_FONT=.../unifont.cruftfont) for full BMP"
	;;
esac
echo "Manual on Lyra: kill cruft (fbcon returns); run picocalc-kbd-test and switch back"
