SUMMARY = "PicoCalc device tree overlays"
DESCRIPTION = "Runtime device tree overlays for PicoCalc hardware"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

require picocalc-drivers-source.inc

COMPATIBLE_MACHINE = "luckfox-lyra"

DEPENDS = "dtc-native"

do_compile() {
    for overlay in ${S}/devicetree-overlays/*-overlay.dts; do
        [ -f "$overlay" ] || bbfatal "No device tree overlay sources found in ${S}/devicetree-overlays"
        name=$(basename "$overlay" -overlay.dts)
        dtc -@ -I dts -O dtb -o ${B}/${name}.dtbo "$overlay"
    done
}

do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware/overlays
    for overlay in ${B}/*.dtbo; do
        [ -f "$overlay" ] || bbfatal "No compiled overlays found in ${B}"
        install -m 0644 "$overlay" ${D}${nonarch_base_libdir}/firmware/overlays/
    done
}

FILES:${PN} = "${nonarch_base_libdir}/firmware/overlays/*.dtbo"
PACKAGES = "${PN}"
