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

# alsa-sys (rodio/cpal), libdbus-sys (keyring secret-service), openssl-sys
DEPENDS = "alsa-lib dbus openssl"

export OPENSSL_DIR = "${STAGING_DIR_HOST}${prefix}"
export OPENSSL_LIB_DIR = "${STAGING_DIR_HOST}${libdir}"
export OPENSSL_INCLUDE_DIR = "${STAGING_DIR_HOST}${includedir}"

# Cargo release profile already strips (strip = "symbols").
INSANE_SKIP:${PN} += "already-stripped"

require ${BPN}-crates.inc
