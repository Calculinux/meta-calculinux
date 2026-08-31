SUMMARY = "Native kbitx to BDF converter"
DESCRIPTION = "Converts BitsNPicas .kbitx bitmap fonts to BDF without Java. \
Used when building Calculinux yaft console fonts from Fairfax.kbitx."
HOMEPAGE = "https://github.com/Calculinux/kbitx2bdf"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${WORKDIR}/git/LICENSE;md5=0c1ca00017fe02adea99b8b709ff179b"

inherit native

SRC_URI = "git://github.com/Calculinux/kbitx2bdf.git;protocol=https;branch=main"
SRCREV = "6c35fe83051b9ed96726bb2bb4871a108e0ae7c3"
PV = "1.0+git${SRCPV}"

S = "${WORKDIR}/git"

do_configure[noexec] = "1"

do_compile() {
    oe_runmake CC='${BUILD_CC}' CFLAGS='${BUILD_CFLAGS} -std=c11 -pedantic -Wall -Wextra -O2'
}

do_install() {
    oe_runmake install DESTDIR=${D} PREFIX=${STAGING_DIR_NATIVE}${prefix}
}

FILES:${PN} = "${bindir}/kbitx2bdf"
