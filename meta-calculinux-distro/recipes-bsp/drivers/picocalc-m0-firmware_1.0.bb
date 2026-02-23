# M0 delta-sigma audio firmware for RK3506 (Cortex-M0)
# Built from picocalc-drivers repo; ELF loaded by rk3506_rproc at 0xFFF88000

SUMMARY = "RK3506 M0 audio firmware (delta-sigma)"
DESCRIPTION = "Bare-metal Cortex-M0 firmware for PicoCalc M0 audio driver. Loaded via remoteproc."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

require picocalc-drivers-source.inc

DEPENDS = "gcc-arm-none-eabi-native"

COMPATIBLE_MACHINE = "luckfox-lyra"

# ARM bare-metal toolchain (arm-none-eabi-gcc).
CROSS_COMPILE_M0 ?= "arm-none-eabi-"

FIRMWARE_DIR = "picocalc_m0_fw"

do_compile() {
	cd ${S}/${FIRMWARE_DIR}
	make CROSS_COMPILE="${CROSS_COMPILE_M0}"
}

do_install() {
	install -d ${D}${nonarch_base_libdir}/firmware
	install -m 0644 ${S}/${FIRMWARE_DIR}/rk3506-m0-audio.elf ${D}${nonarch_base_libdir}/firmware/
}

FILES:${PN} = "${nonarch_base_libdir}/firmware/rk3506-m0-audio.elf"

# Override CROSS_COMPILE_M0 and DEPENDS in a bbappend to use a different toolchain.
