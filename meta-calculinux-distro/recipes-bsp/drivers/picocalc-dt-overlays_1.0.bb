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
    KERNEL_INCLUDE="${STAGING_KERNEL_DIR}/include"
    KERNEL_DTS_INCLUDE="${STAGING_KERNEL_DIR}/arch/arm/boot/dts"
    KERNEL_DTS_INCLUDE_COMMON="${KERNEL_DTS_INCLUDE}/include"
    
    for overlay in ${S}/devicetree-overlays/*-overlay.dts; do
        [ -f "$overlay" ] || bbfatal "No device tree overlay sources found in ${S}/devicetree-overlays"
        name=$(basename "$overlay" -overlay.dts)
        
        # Preprocess with cpp to handle #include directives
        ${CPP} -nostdinc \
            -I"${KERNEL_INCLUDE}" \
            -I"${KERNEL_DTS_INCLUDE}" \
            -I"${KERNEL_DTS_INCLUDE_COMMON}" \
            -undef -D__DTS__ -x assembler-with-cpp \
            "$overlay" > "${B}/${name}.pp.dts"
        
        # Compile preprocessed DTS to DTBO
        dtc -@ -I dts -O dtb -o ${B}/${name}.dtbo "${B}/${name}.pp.dts"
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
