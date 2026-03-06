SUMMARY = "Developer tool to load device tree overlays (ConfigFS)"
DESCRIPTION = "Provides a helper script to load device tree overlays listed in a config file using ConfigFS. Not enabled by default; intended for developer use."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = " \
    file://load-dt-overlays.sh \
"

S = "${UNPACKDIR}"

# Add bash as a runtime dependency
RDEPENDS:${PN} += "bash"

do_install() {
    install -D -m 0755 ${S}/load-dt-overlays.sh ${D}${bindir}/load-dt-overlays
}

FILES:${PN} = " \
    ${bindir}/load-dt-overlays \
"

COMPATIBLE_MACHINE = "luckfox-lyra"
