# Shared FIT kernel-stamp helpers (POSIX sh).
# Sourced by merge-dt-overlays-boot.sh, preinit, and the self-check.
#
# stamp_should_drop KERNEL STAMP
#   0 = drop the merged FIT (stale or unstamped)
#   1 = keep (match, or hash unavailable — do not false-positive)

fit_kernel_stamp() {
	sha256sum "$1" | awk '{print $1}'
}

stamp_matches() {
	[ -f "$1" ] && [ -f "$2" ] || return 1
	[ "$(fit_kernel_stamp "$1")" = "$(cat "$2")" ]
}

# Returns 0 if the FIT should be removed, 1 if it should be kept.
stamp_should_drop() {
	_kernel="$1"
	_stamp="$2"
	[ -f "$_kernel" ] || return 1
	_cur=$(fit_kernel_stamp "$_kernel" 2>/dev/null) || _cur=
	# Hash failed or empty — never drop (avoids reboot/delete loops)
	[ -n "$_cur" ] || return 1
	# Missing stamp — untrusted FIT for next boot
	[ -f "$_stamp" ] || return 0
	_old=$(cat "$_stamp" 2>/dev/null) || _old=
	[ "$_cur" = "$_old" ] && return 1
	return 0
}
