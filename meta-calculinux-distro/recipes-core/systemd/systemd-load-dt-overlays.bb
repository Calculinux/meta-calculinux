SUMMARY = "Systemd integration for loading device tree overlays"
DESCRIPTION = "Provides systemd unit and helper script to load device tree overlays listed in /etc/device-tree-overlays.conf"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = " \
    file://load-dt-overlays.sh \
    file://load-dt-overlays.service \
    file://device-tree-overlays.conf \
"

S = "${UNPACKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "load-dt-overlays.service"
SYSTEMD_AUTO_ENABLE = "enable"

do_install() {
    install -D -m 0755 ${S}/load-dt-overlays.sh ${D}${libdir}/systemd/load-dt-overlays.sh
    install -D -m 0644 ${S}/load-dt-overlays.service ${D}${systemd_system_unitdir}/load-dt-overlays.service
    install -D -m 0644 ${S}/device-tree-overlays.conf ${D}${sysconfdir}/device-tree-overlays.conf
}

FILES:${PN} = " \
    ${libdir}/systemd/load-dt-overlays.sh \
    ${systemd_system_unitdir}/load-dt-overlays.service \
    ${sysconfdir}/device-tree-overlays.conf \
"

COMPATIBLE_MACHINE = "luckfox-lyra"
