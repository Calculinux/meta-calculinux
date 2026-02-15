SUMMARY = "PicoCalc device tree overlays"
DESCRIPTION = "Runtime device tree overlays for PicoCalc hardware"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

require picocalc-drivers-source.inc

COMPATIBLE_MACHINE = "luckfox-lyra"

DEPENDS = "dtc-native virtual/kernel"

# Ensure kernel shared workdir is available with headers
do_compile[depends] += "virtual/kernel:do_shared_workdir"

do_compile() {
    # Include only kernel include/ (for dt-bindings like <dt-bindings/pinctrl/rockchip.h>).
    # Do NOT add arch/.../boot/dts so that labels like &i2c2 stay undefined in the overlay;
    # then dtc emits __fixups__ and the kernel resolves them at apply time from the base DTB __symbols__.
    KERNEL_INCLUDE="${STAGING_KERNEL_DIR}/include"

    for overlay in ${S}/devicetree-overlays/*-overlay.dts; do
        [ -f "$overlay" ] || bbfatal "No device tree overlay sources found in ${S}/devicetree-overlays"
        name=$(basename "$overlay" -overlay.dts)

        # Preprocess: kernel include only (dt-bindings), no base DTS
        ${CPP} -nostdinc \
            -I"${KERNEL_INCLUDE}" \
            -undef -D__DTS__ -x assembler-with-cpp \
            "$overlay" > "${B}/${name}.pp.dts"

        # Compile to DTBO. -@ keeps symbols; -L generates __fixups__ so references
        # like &i2c2 are resolved at load time from the base DTB __symbols__.
        dtc -@ -L -I dts -O dtb -o ${B}/${name}.dtbo "${B}/${name}.pp.dts"
    done
}

do_install() {
    install -d ${D}/boot/devicetree
    for overlay in ${B}/*.dtbo; do
        [ -f "$overlay" ] || bbfatal "No compiled overlays found in ${B}"
        install -m 0644 "$overlay" ${D}/boot/devicetree/
    done
}

FILES:${PN} = "/boot/devicetree/*.dtbo"
PACKAGES = "${PN}"
