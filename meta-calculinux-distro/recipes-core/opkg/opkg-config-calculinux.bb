SUMMARY = "Opkg configuration for Calculinux"
DESCRIPTION = "Configuration files for opkg package manager"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Machine-specific configuration files
FILESEXTRAPATHS:prepend := "${THISDIR}/${MACHINE}:"

SRC_URI = " \
    file://opkg.conf \
    file://arch.conf \
"

# No source directory needed for config-only recipes
S = "${UNPACKDIR}"

do_install() {
    install -d ${D}${sysconfdir}/opkg
    install -m 0644 ${UNPACKDIR}/opkg.conf ${D}${sysconfdir}/opkg/opkg.conf
    install -m 0644 ${UNPACKDIR}/arch.conf ${D}${sysconfdir}/opkg/arch.conf
}

FILES:${PN} = "${sysconfdir}/opkg/*"

CONFFILES:${PN} = "${sysconfdir}/opkg/opkg.conf ${sysconfdir}/opkg/arch.conf"

RDEPENDS:${PN} = "opkg"