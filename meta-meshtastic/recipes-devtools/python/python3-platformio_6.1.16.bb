SUMMARY = "Cross-platform build system for embedded development"
HOMEPAGE = "https://platformio.org/"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=da91308434891f8f5b486c6ab9317309"

SRC_URI[sha256sum] = "79387b45ca7df9c0c51cae82b3b0a40ba78d11d87cea385db47e1033d781e959"

PYPI_PACKAGE = "platformio"

inherit pypi python_setuptools_build_meta

DEPENDS += " \
    python3-click \
    python3-semantic-version \
    python3-requests \
    python3-tabulate \
    python3-pyserial \
    python3-pyelftools \
"

RDEPENDS:${PN} += " \
    python3-click \
    python3-semantic-version \
    python3-requests \
    python3-tabulate \
    python3-pyserial \
    python3-pyelftools \
"

BBCLASSEXTEND = "native"
