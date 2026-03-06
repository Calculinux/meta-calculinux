SUMMARY = "A memory-safe Rust CLI launcher for GLK-based interactive fiction interpreters"
DESCRIPTION = "Automatically detects game file formats and launches the appropriate interpreter \
from the glkterm package. This provides a convenient single command-line interface for running \
various types of text adventure games without needing to know which specific interpreter to use \
for each game format."
HOMEPAGE = "https://github.com/benklop/glkcli"
SECTION = "games"

# License information
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=42c55472c018a92c8089e3971fb6f602"

# Source from git repository (live version)
SRC_URI = "git://github.com/benklop/glkcli.git;protocol=https;branch=main \
           file://0001-Remove-panic-abort-for-cross-compilation-compatibility.patch"
SRCREV = "${AUTOREV}"

# Version (git live version) - bumped to 1.1 for glkterm path configuration
PV = "1.2.1+git${SRCPV}"

# Working directory
S = "${WORKDIR}/git"

# Rust build system - use cargo-update-recipe-crates for proper dependency management
inherit cargo cargo-update-recipe-crates

# Use --offline instead of --frozen so cargo uses the bitbake-vendored crates
# without strict lockfile checks that can fail when directory source resolution
# differs slightly from the registry (e.g. after crate/rust updates).
CARGO_BUILD_FLAGS:remove = "--frozen"
CARGO_BUILD_FLAGS += "--offline"

# Build dependencies
DEPENDS = "glkterm openssl criu"

# Runtime dependencies
RDEPENDS:${PN} = "glkterm"

# Set up OpenSSL for Rust's openssl-sys crate
export OPENSSL_DIR = "${STAGING_DIR_HOST}${prefix}"
export OPENSSL_LIB_DIR = "${STAGING_DIR_HOST}${libdir}"
export OPENSSL_INCLUDE_DIR = "${STAGING_DIR_HOST}${includedir}"

# Configure glkterm interpreter location at compile time
export GLKTERM_BIN_DIR = "${datadir}/glkterm/bin"

# Include the auto-generated crates file
require ${BPN}-crates.inc

# Package files
FILES:${PN} = "${bindir}/glkcli"

# This is a CLI tool, no development or library files expected
FILES:${PN}-dev = ""

# Documentation
FILES:${PN}-doc = "${docdir}/* \
                   ${mandir}/*"
