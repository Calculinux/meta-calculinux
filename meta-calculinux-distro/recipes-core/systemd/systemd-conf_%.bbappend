FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://journald.conf \
    file://wlan.network \
    file://98-wifi.link \
    file://ttyblank.conf \
"

do_install() {
    install -d ${D}${systemd_unitdir}/network
    install -m 644 ${UNPACKDIR}/wlan.network ${D}${systemd_unitdir}/network
    install -m 644 ${UNPACKDIR}/98-wifi.link ${D}${systemd_unitdir}/network

    install -d ${D}${systemd_unitdir}/system/getty@tty1.service.d
    install -m 0644 ${UNPACKDIR}/ttyblank.conf \
        ${D}${systemd_unitdir}/system/getty@tty1.service.d/20-ttyblank.conf
}

FILES:${PN} += "\
    ${systemd_unitdir} \
"
