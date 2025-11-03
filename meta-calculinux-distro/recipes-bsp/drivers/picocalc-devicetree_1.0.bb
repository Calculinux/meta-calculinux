SUMMARY = "PicoCalc device tree data"
DESCRIPTION = "Device tree overlays and fragments for the PicoCalc hardware platform"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

require picocalc-drivers-source.inc

COMPATIBLE_MACHINE = "luckfox-lyra"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${datadir}/picocalc
    install -m 0644 ${S}/picocalc-luckfox-lyra.dtsi ${D}${datadir}/picocalc/
}

SYSROOT_DIRS += "${datadir}/picocalc"

FILES:${PN} = "${datadir}/picocalc/picocalc-luckfox-lyra.dtsi"
