SUMMARY = "BitsNPicas bitmap font tools (native)"
DESCRIPTION = "Native build of Kreative Software BitsNPicas for converting \
.kbitx/.ttf bitmap fonts to BDF during Calculinux image builds."
HOMEPAGE = "https://github.com/kreativekorp/bitsnpicas"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${WORKDIR}/git/LICENSE;md5=3be7b8b182ccd96e48989b4e57311193"

inherit native

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = "git://github.com/kreativekorp/bitsnpicas.git;protocol=https;branch=master \
           file://bitsnpicas-native.sh \
           "
SRCREV = "6eb4d3b5e7983d9e99906bf26561ca32d6b36c30"

S = "${WORKDIR}/git/main/java/BitsNPicas"

DEPENDS = "openjdk-native"

do_configure[noexec] = "1"

do_compile() {
    oe_runmake BitsNPicas.jar
}

do_install() {
    install -d ${D}${bindir} ${D}${datadir}/bitsnpicas
    install -m 0644 ${S}/BitsNPicas.jar ${D}${datadir}/bitsnpicas/
    install -m 0755 ${UNPACKDIR}/bitsnpicas-native.sh ${D}${bindir}/bitsnpicas
}

FILES:${PN} = "${bindir}/bitsnpicas ${datadir}/bitsnpicas"
