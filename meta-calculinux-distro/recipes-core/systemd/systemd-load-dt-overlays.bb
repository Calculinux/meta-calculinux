SUMMARY = "Developer tool to load device tree overlays (ConfigFS)"
DESCRIPTION = "Provides a helper script to load device tree overlays listed in a config file using ConfigFS. Not enabled by default; intended for developer use."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = " \
    file://load-dt-overlays.sh \
    file://load-dt-overlays.service \
"

S = "${UNPACKDIR}"

inherit systemd

# Developer tool: installed, not started.
SYSTEMD_SERVICE:${PN} = "load-dt-overlays.service"
SYSTEMD_AUTO_ENABLE = "disable"

RDEPENDS:${PN} += "bash"

do_install() {
    install -D -m 0755 ${S}/load-dt-overlays.sh ${D}${bindir}/load-dt-overlays
    install -D -m 0644 ${S}/load-dt-overlays.service ${D}${systemd_system_unitdir}/load-dt-overlays.service
}

FILES:${PN} = " \
    ${bindir}/load-dt-overlays \
    ${systemd_system_unitdir}/load-dt-overlays.service \
"

COMPATIBLE_MACHINE = "luckfox-lyra"
