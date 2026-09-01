SUMMARY = "A pure python QR Code generator"
HOMEPAGE = "https://github.com/pyqrcode/pyqrcode"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://setup.py;md5=1f16cc7e299e73e285c42038f795f834;beginline=1;endline=24"

SRC_URI[sha256sum] = "fdbf7634733e56b72e27f9bce46e4550b75a3a2c420414035cae9d9d26b234d5"

PYPI_PACKAGE = "PyQRCode"

inherit pypi python_setuptools_build_meta

DEPENDS += " \
    python3-setuptools-scm-native \
"
