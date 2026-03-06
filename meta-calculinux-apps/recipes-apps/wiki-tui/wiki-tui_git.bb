SUMMARY = "A simple and easy to use Wikipedia Text User Interface"
DESCRIPTION = "wiki-tui is a TUI client for browsing Wikipedia from the \
terminal. Features rich search results, table of contents, vim-like \
keybindings, multi-language support, and customizable themes."
HOMEPAGE = "https://wiki-tui.net"
SECTION = "console/utils"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0d4b70885d03e5f949ce9030bac50c5d"

SRC_URI = "git://github.com/Builditluc/wiki-tui.git;protocol=https;branch=main \
           file://0001-Pin-tui-logger-to-0.17.3-for-Rust-1.87-compat.patch"
SRCREV = "ff41c522ae89627ea4ba7e0d630ea7cae9d3374b"

S = "${WORKDIR}/git"

PV = "0.9.2+git${SRCPV}"

inherit cargo cargo-update-recipe-crates

DEPENDS = "openssl"

# Use --offline instead of --frozen: Cargo.lock may need to be updated to match
# Cargo.toml (e.g. after our tui-logger pin patch); --offline allows local
# lockfile updates without network access.
CARGO_BUILD_FLAGS:remove = "--frozen"
CARGO_BUILD_FLAGS += "--offline"

# Set up OpenSSL for Rust's openssl-sys crate (cross-compilation)
export OPENSSL_DIR = "${STAGING_DIR_HOST}${prefix}"
export OPENSSL_LIB_DIR = "${STAGING_DIR_HOST}${libdir}"
export OPENSSL_INCLUDE_DIR = "${STAGING_DIR_HOST}${includedir}"

# Include the auto-generated crates file (run 'bitbake -c update_crates wiki-tui' to regenerate)
# Note: tui-logger pinned to 0.17.3 in crates.inc; 0.17.4 requires Rust 1.87+ (is_multiple_of)
require ${BPN}-crates.inc
