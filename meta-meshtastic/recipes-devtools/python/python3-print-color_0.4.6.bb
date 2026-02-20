SUMMARY = "A useful module for printing colored text and styling in Python"
HOMEPAGE = "https://github.com/MrParoạ/print_color"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=86d3f3a95c324c9479bd8986968f4327"

SRC_URI[sha256sum] = "d3aafc1666c8d31a85fffa6ee8e4f269f5d5e338d685b4e6179915c71867c585"

PYPI_PACKAGE = "print_color"

inherit pypi python_poetry_core

DEPENDS += " \
    python3-poetry-core-native \
"
