SUMMARY = "RTL8XXXU kernel driver for RTL8xxxU"
DESCRIPTION = "Out-of-tree Realtek USB Wi-Fi driver for RTL8188EU/FU chipset"
HOMEPAGE = "https://github.com/aesteryck/rtl8xxxu"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://firmware/LICENCE.rtlwifi_firmware.txt;md5=00d06cfd3eddd5a2698948ead2ad54a5"

PV = "1.0-git"

SRC_URI = "\
    git://github.com/aesteryck/rtl8xxxu.git;protocol=https;branch=main \
    file://rtl8188ftv-solution-d.patch \
    file://rtl8188ftv-block-size.patch \
    "
SRCREV = "7cb5b73796b19b460af835144e604595083ca60d"

S = "${UNPACKDIR}/git"
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

RDEPENDS:${PN} += "${PN}-firmware"

# Conflict with linux-firmware packages that provide RTL8188EU firmware
RCONFLICTS:${PN}-firmware = "linux-firmware-rtl8188"
RREPLACES:${PN}-firmware = "linux-firmware-rtl8188"
RPROVIDES:${PN}-firmware = "linux-firmware-rtl8188"

module_do_install() {
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless
    install -m 0644 ${B}/rtl8xxxu.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/
}

do_install:append() {
    install -d ${D}${nonarch_base_libdir}/firmware/rtlwifi
    # Install firmware files for 81888EU and 8188FU
    # Other firmware variants are provided by linux-firmware packages
    install -m 0644 ${S}/firmware/rtl8188eufw.bin ${D}${nonarch_base_libdir}/firmware/rtlwifi/
    install -m 0644 ${S}/firmware/rtl8188fufw.bin ${D}${nonarch_base_libdir}/firmware/rtlwifi/
}

FILES:${PN}-firmware = "${nonarch_base_libdir}/firmware/rtlwifi/rtl8188eufw.bin ${nonarch_base_libdir}/firmware/rtlwifi/rtl8188fufw.bin"
