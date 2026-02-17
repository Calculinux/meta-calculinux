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

# Working directory
S = "${WORKDIR}/git"

# Extract version from Cargo.toml dynamically
python do_get_cargo_version() {
    import re
    cargo_toml = os.path.join(d.getVar('S'), 'Cargo.toml')
    if os.path.exists(cargo_toml):
        with open(cargo_toml, 'r') as f:
            for line in f:
                match = re.match(r'^version\s*=\s*"([^"]+)"', line.strip())
                if match:
                    version = match.group(1)
                    d.setVar('PV', version + '+git${SRCPV}')
                    bb.plain("Extracted version from Cargo.toml: %s" % version)
                    break
}
addtask do_get_cargo_version after do_unpack before do_patch

# Rust build system - use cargo-update-recipe-crates for proper dependency management
inherit cargo cargo-update-recipe-crates

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
