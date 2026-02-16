SUMMARY = "Python publish-subscribe messaging API"
HOMEPAGE = "https://github.com/schollii/pypubsub"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=2fedfd31700f60e5c8d6499d70311882"

SRC_URI[sha256sum] = "ec8b5cb147624958320e992602380cc5d0e4b36b1c59844d05e425a3003c09dc"

PYPI_PACKAGE = "pypubsub"

inherit pypi python_setuptools_build_meta

DEPENDS += " \
    python3-setuptools-scm-native \
"

RDEPENDS:${PN} += " \
    python3-setuptools-scm \
"
