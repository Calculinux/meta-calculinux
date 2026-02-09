SUMMARY = "DS3231 RTC device tree overlay for PicoCalc"
DESCRIPTION = "Device tree overlay to enable DS3231 I2C RTC module support on PicoCalc"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

require picocalc-drivers-source.inc

COMPATIBLE_MACHINE = "luckfox-lyra"

# Dependencies
DEPENDS = "dtc-native"

# Compile the overlay
do_compile() {
    dtc -@ -I dts -O dtb -o ${B}/ds3231-rtc.dtbo ${S}/ds3231-rtc-overlay.dts
}

# Install to /lib/firmware/overlays
do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware/overlays
    install -m 0644 ${B}/ds3231-rtc.dtbo ${D}${nonarch_base_libdir}/firmware/overlays/
}

FILES:${PN} = "\
    ${nonarch_base_libdir}/firmware/overlays/ds3231-rtc.dtbo \
"

# Package as firmware
PACKAGES = "${PN}"
