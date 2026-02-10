SUMMARY = "Hibernate support for PicoCalc"
DESCRIPTION = "Systemd configuration for hibernation support on PicoCalc devices"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://sleep.conf"

S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"

RDEPENDS:${PN} = "systemd util-linux-swapon"

do_install() {
    # Install systemd sleep configuration
    install -d ${D}${sysconfdir}/systemd
    install -m 0644 ${UNPACKDIR}/sleep.conf ${D}${sysconfdir}/systemd/sleep.conf
}

FILES:${PN} = "${sysconfdir}/systemd/sleep.conf"
