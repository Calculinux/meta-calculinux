SUMMARY = "Merge device tree overlays into zboot FIT for next boot"
DESCRIPTION = "Builds zboot_merged_<slot>.img (per RAUC slot A/B) from zboot.img and \
overlays in /etc/device-tree-overlays.conf, writes to OVERLAY_DATA so U-Boot loads \
the matching slot's image. Ensures correct kernel+DTB on update and on failover."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = " \
    file://merge-dt-overlays-boot.sh \
    file://merge-dt-overlays-boot.service \
    file://merge-dt-overlays-boot.path \
    file://clear-fit-rewritten.service \
    file://device-tree-overlays.conf \
"

S = "${UNPACKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "merge-dt-overlays-boot.path clear-fit-rewritten.service"
SYSTEMD_AUTO_ENABLE = "enable"

RDEPENDS:${PN} += "bash u-boot-tools dtc dtc-tools u-boot-fw-config"

do_install() {
    install -D -m 0755 ${S}/merge-dt-overlays-boot.sh ${D}${libdir}/systemd/merge-dt-overlays-boot.sh
    install -D -m 0644 ${S}/merge-dt-overlays-boot.service ${D}${systemd_system_unitdir}/merge-dt-overlays-boot.service
    install -D -m 0644 ${S}/merge-dt-overlays-boot.path ${D}${systemd_system_unitdir}/merge-dt-overlays-boot.path
    install -D -m 0644 ${S}/clear-fit-rewritten.service ${D}${systemd_system_unitdir}/clear-fit-rewritten.service
    install -D -m 0644 ${S}/device-tree-overlays.conf ${D}${sysconfdir}/device-tree-overlays.conf
}

FILES:${PN} = " \
    ${libdir}/systemd/merge-dt-overlays-boot.sh \
    ${systemd_system_unitdir}/merge-dt-overlays-boot.service \
    ${systemd_system_unitdir}/merge-dt-overlays-boot.path \
    ${systemd_system_unitdir}/clear-fit-rewritten.service \
    ${sysconfdir}/device-tree-overlays.conf \
"

COMPATIBLE_MACHINE = "luckfox-lyra"
