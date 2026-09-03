SUMMARY = "PicoCalc device tree data"
DESCRIPTION = "Device tree overlays and fragments for the PicoCalc hardware platform"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

require picocalc-drivers-source.inc

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://vbus-always-on.dtsi.patch"

COMPATIBLE_MACHINE = "luckfox-lyra"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${datadir}/picocalc
    install -m 0644 ${S}/picocalc-luckfox-lyra.dtsi ${D}${datadir}/picocalc/
    install -m 0644 ${S}/linux-rk3506-luckfox-lyra.dtsi ${D}${datadir}/picocalc/rk3506-luckfox-lyra.dtsi
    install -m 0644 ${S}/linux-rk3506g-luckfox-lyra.dts ${D}${datadir}/picocalc/rk3506g-luckfox-lyra.dts
    install -m 0644 ${S}/uboot-rk3506-luckfox.dtsi ${D}${datadir}/picocalc/rk3506-luckfox.dtsi
    install -m 0644 ${S}/uboot-rk3506-luckfox.dts ${D}${datadir}/picocalc/rk3506-luckfox.dts

    # Overlay symbol whitelist – consumed by the kernel recipe to inject only
    # the needed __symbols__ entries into the base DTB.
    OVERLAY_SYMS=""
    for candidate in \
        "${S}/overlays/overlay-symbols.txt" \
        "${S}/luckfox-lyra/overlays/overlay-symbols.txt"; do
        if [ -f "${candidate}" ]; then
            OVERLAY_SYMS="${candidate}"
            break
        fi
    done
    if [ -n "${OVERLAY_SYMS}" ]; then
        install -m 0644 "${OVERLAY_SYMS}" ${D}${datadir}/picocalc/overlay-symbols.txt
    else
        bbwarn "overlay-symbols.txt not found – kernel will fall back to built-in symbol list"
    fi
}

FILES:${PN} = "\
    ${datadir}/picocalc/picocalc-luckfox-lyra.dtsi \
    ${datadir}/picocalc/rk3506-luckfox-lyra.dtsi \
    ${datadir}/picocalc/rk3506g-luckfox-lyra.dts \
    ${datadir}/picocalc/rk3506-luckfox.dtsi \
    ${datadir}/picocalc/rk3506-luckfox.dts \
    ${datadir}/picocalc/overlay-symbols.txt \
"
SYSROOT_DIRS += "${datadir}/picocalc"
