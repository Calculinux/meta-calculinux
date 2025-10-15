SUMMARY = "Calculinux system management tools"
DESCRIPTION = "Helper scripts and utilities for managing Calculinux system"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://calculinux-upgrade-check \
"

S = "${UNPACKDIR}"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${UNPACKDIR}/calculinux-upgrade-check ${D}${sbindir}/calculinux-upgrade-check
}

FILES:${PN} = "${sbindir}/calculinux-upgrade-check"

RDEPENDS:${PN} = "opkg bash"
