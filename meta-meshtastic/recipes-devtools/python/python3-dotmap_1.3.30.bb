SUMMARY = "dotmap - Ordered, Immutable, and Typed Dot-accessible Dictionary"
HOMEPAGE = "https://github.com/drgrib/dotmap"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=0db53f0f62afdd84d4fa95f46d274c6d"

SRC_URI[sha256sum] = "5821a7933f075fb47563417c0e92e0b7c031158b4c9a6a7e56163479b658b368"

PYPI_PACKAGE = "dotmap"

inherit pypi python_setuptools_build_meta

DEPENDS += " \
    python3-setuptools-scm-native \
"
