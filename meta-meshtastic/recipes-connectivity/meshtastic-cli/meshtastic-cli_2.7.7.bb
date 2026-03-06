SUMMARY = "Meshtastic Python CLI tool"
DESCRIPTION = "Command-line interface for interacting with Meshtastic mesh nodes. Provides tools for configuration, messaging, and device management."
HOMEPAGE = "https://meshtastic.org/"
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=75d892af193fd5a298f724c4377d8f62"

PV = "2.7.7"

SRC_URI[sha256sum] = "6e2dc663e61841235966f04fe4c3257445e643f8dc7b8eaf7286c4b71a106511"

PYPI_PACKAGE = "meshtastic"

inherit pypi python_poetry_core

DEPENDS += " \
    python3-poetry-core-native \
    python3-setuptools-scm-native \
"

RDEPENDS:${PN} += " \
    python3-argcomplete \
    python3-dotmap \
    python3-packaging \
    python3-print-color \
    python3-protobuf \
    python3-pypubsub \
    python3-pyqrcode \
    python3-pyserial \
    python3-pyyaml \
    python3-requests \
    python3-tabulate \
    python3-wcwidth \
"
