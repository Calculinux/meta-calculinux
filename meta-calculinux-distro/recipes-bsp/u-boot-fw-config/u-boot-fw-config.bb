SUMMARY = "U-Boot environment location for fw_printenv/fw_setenv"
DESCRIPTION = "Installs /etc/fw_env.config. The file itself is board specific: \
each BSP layer supplies it from a u-boot-fw-config.bbappend."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

PACKAGE_ARCH = "${MACHINE_ARCH}"

SRC_URI = " \
    file://fw_env.config \
"
S = "${UNPACKDIR}"

RDEPENDS:${PN} += "u-boot-fw-utils"

do_install () {
    install -d ${D}${sysconfdir}
    install -m 0644 ${UNPACKDIR}/fw_env.config ${D}${sysconfdir}/
}

FILES:${PN} += "${sysconfdir}/"
