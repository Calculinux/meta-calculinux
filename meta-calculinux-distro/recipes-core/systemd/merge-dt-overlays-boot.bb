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
"

S = "${UNPACKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "merge-dt-overlays-boot.path"
SYSTEMD_AUTO_ENABLE = "enable"

RDEPENDS:${PN} += "bash u-boot-tools dtc dtc-tools"

do_install() {
    install -D -m 0755 ${S}/merge-dt-overlays-boot.sh ${D}${libdir}/systemd/merge-dt-overlays-boot.sh
    install -D -m 0644 ${S}/merge-dt-overlays-boot.service ${D}${systemd_system_unitdir}/merge-dt-overlays-boot.service
    install -D -m 0644 ${S}/merge-dt-overlays-boot.path ${D}${systemd_system_unitdir}/merge-dt-overlays-boot.path
}

FILES:${PN} = " \
    ${libdir}/systemd/merge-dt-overlays-boot.sh \
    ${systemd_system_unitdir}/merge-dt-overlays-boot.service \
    ${systemd_system_unitdir}/merge-dt-overlays-boot.path \
"

COMPATIBLE_MACHINE = "luckfox-lyra"
