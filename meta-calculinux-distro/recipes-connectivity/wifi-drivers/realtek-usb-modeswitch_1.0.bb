SUMMARY = "Switch Realtek USB Wi-Fi dongles out of fake driver CD mode"
DESCRIPTION = "udev rules that eject the driver CD some Realtek USB Wi-Fi \
dongles present first, so they re-enumerate as a Wi-Fi device."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://realtek-usb-modeswitch.rules"

S = "${UNPACKDIR}"

inherit allarch

do_install() {
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${S}/realtek-usb-modeswitch.rules ${D}${sysconfdir}/udev/rules.d/
}

FILES:${PN} = "${sysconfdir}/udev/rules.d/realtek-usb-modeswitch.rules"

RDEPENDS:${PN} = "usb-modeswitch"
