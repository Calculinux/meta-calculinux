SUMMARY = "PicoCalc device tree overlays"
DESCRIPTION = "Runtime device tree overlays for PicoCalc hardware"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

require picocalc-drivers-source.inc

COMPATIBLE_MACHINE = "luckfox-lyra"

inherit devicetree

# Overlays need -@ flag to generate __fixups__ node for phandle resolution
DTC_FLAGS += "-@"

# Copy overlay sources from git checkout to where devicetree.bbclass expects them
# devicetree.bbclass sets UNPACKDIR=${S}=sources, so git unpacks to ${UNPACKDIR}/git
do_unpack[postfuncs] += "copy_overlay_sources"

copy_overlay_sources() {
    if [ -d ${UNPACKDIR}/git/devicetree-overlays ]; then
        cp -r ${UNPACKDIR}/git/devicetree-overlays/* ${S}/
    fi
}

# Build all overlay files
DT_FILES = " \
    100khz-i2c-overlay.dts \
    ds3231-rtc-overlay.dts \
    neo-m8n-gps-overlay.dts \
    pcm5102a-i2s-overlay.dts \
    sx1262-lora-overlay.dts \
"
