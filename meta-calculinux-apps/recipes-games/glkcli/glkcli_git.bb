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

# Version (git live version)
PV = "1.0+git${SRCPV}"

# Working directory
S = "${WORKDIR}/git"

# Rust build system - use cargo-update-recipe-crates for proper dependency management
inherit cargo cargo-update-recipe-crates

# Build dependencies
DEPENDS = "glkterm"

# Runtime dependencies
RDEPENDS:${PN} = "glkterm"

# Include the auto-generated crates file
require ${BPN}-crates.inc

# Package files
FILES:${PN} = "${bindir}/glkcli"

# This is a CLI tool, no development or library files expected
FILES:${PN}-dev = ""

# Documentation
FILES:${PN}-doc = "${docdir}/* \
                   ${mandir}/*"