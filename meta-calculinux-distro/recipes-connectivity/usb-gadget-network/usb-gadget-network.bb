SUMMARY = "USB Gadget Network configuration for PicoCalc"
DESCRIPTION = "Configures USB gadget networking using ConfigFS to provide RNDIS and CDC-Ether connectivity"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://usb-gadget-network.sh \
    file://usb-gadget-network.service \
    file://usb0.network \
    file://usb-gadget-network.default \
    file://serial-getty@ttyGS0.service \
    file://README.md \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = "usb-gadget-network.service serial-getty@ttyGS0.service"
SYSTEMD_AUTO_ENABLE = "enable"

RDEPENDS:${PN} = " \
    bash \
    kernel-module-libcomposite \
    kernel-module-usb-f-rndis \
    kernel-module-usb-f-ecm \
    kernel-module-usb-f-fs \
    kernel-module-usb-f-acm \
    kernel-module-dwc2 \
    android-adbd \
    iproute2 \
    systemd \
"

do_install() {
    # Install the configuration script
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/usb-gadget-network.sh ${D}${bindir}/

    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/usb-gadget-network.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${UNPACKDIR}/serial-getty@ttyGS0.service ${D}${systemd_system_unitdir}/

    # Install systemd network configuration
    install -d ${D}${systemd_unitdir}/network
    install -m 0644 ${UNPACKDIR}/usb0.network ${D}${systemd_unitdir}/network/

    # Install documentation
    install -d ${D}${docdir}/${PN}
    install -m 0644 ${UNPACKDIR}/README.md ${D}${docdir}/${PN}/

    # Install defaults
    install -d ${D}${sysconfdir}/default
    install -m 0644 ${UNPACKDIR}/usb-gadget-network.default ${D}${sysconfdir}/default/usb-gadget-network
}

FILES:${PN} += " \
    ${systemd_system_unitdir}/usb-gadget-network.service \
    ${systemd_system_unitdir}/serial-getty@ttyGS0.service \
    ${systemd_unitdir}/network/usb0.network \
    ${docdir}/${PN}/README.md \
    ${sysconfdir}/default/usb-gadget-network \
"

# Only compatible with machines that have USB gadget support
COMPATIBLE_MACHINE = "luckfox-lyra"
