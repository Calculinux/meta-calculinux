FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# FILESEXTRAPATHS replaces poky's journald.conf; base do_install ships it.
SRC_URI += " \
    file://wlan.network \
    file://ttyblank.conf \
"

do_install:append() {
    install -d ${D}${systemd_unitdir}/network
    install -m 644 ${UNPACKDIR}/wlan.network ${D}${systemd_unitdir}/network

    install -d ${D}${systemd_unitdir}/system/getty@tty1.service.d
    install -m 0644 ${UNPACKDIR}/ttyblank.conf \
        ${D}${systemd_unitdir}/system/getty@tty1.service.d/20-ttyblank.conf
}

FILES:${PN} += "\
    ${systemd_unitdir}/system/getty@tty1.service.d \
"
