SUMMARY = "PicoCalc device tree overlays"
DESCRIPTION = "Runtime device tree overlays for PicoCalc hardware"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

require picocalc-drivers-source.inc

COMPATIBLE_MACHINE = "luckfox-lyra"

inherit devicetree

# Point to the overlay sources in the picocalc-drivers repo
DT_FILES_PATH = "${S}/devicetree-overlays"

# Build all overlay files
DT_FILES = " \
    100khz-i2c-overlay.dts \
    ds3231-rtc-overlay.dts \
    neo-m8n-gps-overlay.dts \
    pcm5102a-i2s-overlay.dts \
    sx1262-lora-overlay.dts \
"
