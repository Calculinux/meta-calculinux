SUMMARY = "RTL8XXXU kernel driver for RTL8188EU"
DESCRIPTION = "Out-of-tree Realtek USB Wi-Fi driver for RTL8188EU chipset"
HOMEPAGE = "https://github.com/aesteryck/rtl8xxxu"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://firmware/LICENCE.rtlwifi_firmware.txt;md5=00d06cfd3eddd5a2698948ead2ad54a5"

PV = "1.0-git"

SRC_URI = "\
    git://github.com/aesteryck/rtl8xxxu.git;protocol=https;branch=main \
    "
SRCREV = "7cb5b73796b19b460af835144e604595083ca60d"

S = "${WORKDIR}/git"
DEPENDS += "virtual/kernel"

inherit module

MODULE_DIR="${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/"

EXTRA_OEMAKE += "\
    MODULE_NAME=rtl8xxxu \
    KDIR=${STAGING_KERNEL_BUILDDIR} \
    KSRC=${STAGING_KERNEL_DIR} \
    KVER=${KERNEL_VERSION} \
    "

PACKAGES =+ "${PN}-firmware"

RPROVIDES:${PN} += "kernel-module-rtl8xxxu"
RDEPENDS:${PN} += "${PN}-firmware"

# Conflict with linux-firmware packages that provide RTL8188EU firmware
RCONFLICTS:${PN}-firmware = "linux-firmware-rtl8188"
RREPLACES:${PN}-firmware = "linux-firmware-rtl8188"
RPROVIDES:${PN}-firmware = "linux-firmware-rtl8188"

module_do_install() {
    install -d ${D}${MODULE_DIR}
    install -m 0644 ${S}/rtl8xxxu.ko ${D}${MODULE_DIR}
}

do_install:append() {
    install -d ${D}${nonarch_base_libdir}/firmware/rtlwifi
    # Install only RTL8188EU firmware file
    if [ -f ${S}/firmware/rtl8188eufw.bin ]; then
        install -m 0644 ${S}/firmware/rtl8188eufw.bin ${D}${nonarch_base_libdir}/firmware/rtlwifi/
    fi
}

FILES:${PN}-firmware = "${nonarch_base_libdir}/firmware/rtlwifi/rtl8188eufw.bin"