SUMMARY = "Monobit bitmap font library and converter"
DESCRIPTION = "Tools and Python library for working with bitmap fonts. Supports \
conversion between many formats including YAFF, PSF, BDF, PCF, and others."

HOMEPAGE = "https://github.com/robhagemans/monobit"
SECTION = "devel/python"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=ed50c98c6b2b3ee8c4be296b3eddc37f"

SRC_URI = "git://github.com/robhagemans/monobit.git;protocol=https;branch=master"
SRCREV = "${AUTOREV}"

S = "${WORKDIR}/git"

inherit python_setuptools_build_meta native

DEPENDS += "python3-hatchling-native python3-setuptools-scm-native"

BBCLASSEXTEND = "native nativesdk"
