SUMMARY = "PicoCalc device tree overlays"
DESCRIPTION = "Runtime device tree overlays for PicoCalc hardware"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

require picocalc-drivers-source.inc

COMPATIBLE_MACHINE = "luckfox-lyra"

DEPENDS = "dtc-native virtual/kernel"

# Skip default do_configure (oe_runmake clean) — compile uses dtc only.
do_configure[noexec] = "1"
do_compile[depends] += "virtual/kernel:do_shared_workdir"

do_compile() {
    # Kernel include/ only (dt-bindings). Do not add arch/.../boot/dts so
    # labels like &snd_pins stay as __fixups__ for ConfigFS apply.
    KERNEL_INCLUDE="${STAGING_KERNEL_DIR}/include"

    found=0
    for dir in ${S}/devicetree-overlays ${S}/overlays ${S}/luckfox-lyra/overlays; do
        [ -d "$dir" ] || continue
        for overlay in "$dir"/*-overlay.dts; do
            [ -f "$overlay" ] || continue
            name=$(basename "$overlay" -overlay.dts)

            ${CPP} -nostdinc \
                -I"${KERNEL_INCLUDE}" \
                -undef -D__DTS__ -x assembler-with-cpp \
                "$overlay" > "${B}/${name}.pp.dts"

            dtc -@ -L -I dts -O dtb -o ${B}/${name}.dtbo "${B}/${name}.pp.dts"
            found=1
        done
    done
    [ "$found" = 1 ] || bbfatal "No *-overlay.dts found under ${S}/{devicetree-overlays,overlays,luckfox-lyra/overlays}"
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
