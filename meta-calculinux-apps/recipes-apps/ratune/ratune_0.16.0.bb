SUMMARY = "Terminal music player for Subsonic-compatible servers"
DESCRIPTION = "Ratune is a modern, highly-customizable Subsonic TUI client built in Rust \
(ratatui for the UI, rodio for playback). Needs a Subsonic-compatible server such as Navidrome."
HOMEPAGE = "https://github.com/acmagn/ratune"
SECTION = "multimedia"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=cd1c5dce701b57dd50b765c1c438804c"

# GitHub archive tarballs are rejected by src-uri-bad QA; fetch the tag via git.
SRC_URI = "git://github.com/acmagn/ratune.git;protocol=https;branch=main"
SRCREV = "cf635ffe1fa7abb428749a55ccd6600d12f6f21b"

S = "${WORKDIR}/git"

inherit cargo cargo-update-recipe-crates pkgconfig

# bitbake vendors the crates; use --offline rather than --frozen so cargo does
# not fail strict lockfile checks against the directory source (same as glkcli).
CARGO_BUILD_FLAGS:remove = "--frozen"
CARGO_BUILD_FLAGS += "--offline"

# cpal 0.17.3 computes `tv_sec * 1_000_000_000` with 32-bit integers on 32-bit
# targets (c_long == i32), so the product silently wraps for any monotonic
# timestamp beyond ~2.1 s of uptime. The ALSA backend then sees a "negative"
# elapsed time on every poll, reports a backend error each time and stops
# feeding audio - playback dies within seconds on the Lyra (ARMv7), e.g.
# "get_htstamp `16041.0` was earlier than get_trigger_htstamp `15915.0`"
# despite the first value being later. Mirrors the upstream fix (RustAudio/cpal
# master, see RustAudio/cpal#1157): widen both operands to i64. The patch is
# applied to the bitbake-vendored crate, which is fully unpacked by
# do_compile time.
do_compile:prepend () {
	local cpal=${CARGO_VENDORING_DIRECTORY}/cpal-0.17.3
	if [ ! -f ${WORKDIR}/.cpal-0.17.3-i64-timestamp-patched ]; then
		if [ ! -d ${cpal} ]; then
			bbfatal "cpal-0.17.3 not found under ${CARGO_VENDORING_DIRECTORY}"
		fi
		patch -d ${cpal} -p1 -N < ${THISDIR}/files/cpal-0.17.3-timespec-32bit-overflow.patch
		touch ${WORKDIR}/.cpal-0.17.3-i64-timestamp-patched
	fi
}

# alsa-sys (rodio/cpal), libdbus-sys (keyring secret-service), openssl-sys
DEPENDS = "alsa-lib dbus openssl"

export OPENSSL_DIR = "${STAGING_DIR_HOST}${prefix}"
export OPENSSL_LIB_DIR = "${STAGING_DIR_HOST}${libdir}"
export OPENSSL_INCLUDE_DIR = "${STAGING_DIR_HOST}${includedir}"

# Cargo release profile already strips (strip = "symbols").
INSANE_SKIP:${PN} += "already-stripped"

require ${BPN}-crates.inc
