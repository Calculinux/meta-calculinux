SUMMARY = "RTL8XXXU kernel driver for RTL8xxxU"
DESCRIPTION = "Out-of-tree Realtek USB Wi-Fi driver for RTL8188EU/FU/GU chipsets"
HOMEPAGE = "https://github.com/Calculinux/rtl8xxxu"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://firmware/LICENCE.rtlwifi_firmware.txt;md5=00d06cfd3eddd5a2698948ead2ad54a5"

PV = "1.0-git"

SRC_URI = " \
    git://github.com/Calculinux/rtl8xxxu.git;protocol=https;branch=main \
    file://rtl8xxxu-modeswitch.rules \
"
SRCREV = "113070098a4028d7a77734683677c55ea2b7ae93"

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

PACKAGES =+ "${PN}-firmware ${PN}-udev"

RDEPENDS:${PN} += "${PN}-firmware ${PN}-udev"

# The modeswitch rule ejects the fake driver CD with usb_modeswitch
RDEPENDS:${PN}-udev += "usb-modeswitch"

# Conflict with linux-firmware packages that provide RTL8188EU and RTL8710BU firmware
RCONFLICTS:${PN}-firmware = "linux-firmware-rtl8188 linux-firmware-rtl8710"
RREPLACES:${PN}-firmware = "linux-firmware-rtl8188 linux-firmware-rtl8710"
RPROVIDES:${PN}-firmware = "linux-firmware-rtl8188 linux-firmware-rtl8710"

module_do_install() {
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless
    install -m 0644 ${B}/rtl8xxxu.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/
}

do_install:append() {
    install -d ${D}${nonarch_base_libdir}/firmware/rtlwifi
    # Install firmware files for 8188EU, 8188FU and 8188GU (aka 8710BU).
    # The 8710BU blobs have no split package in linux-firmware, so they would
    # otherwise only land in the (excluded) main linux-firmware package.
    # Other firmware variants are provided by linux-firmware packages
    install -m 0644 ${S}/firmware/rtl8188eufw.bin ${D}${nonarch_base_libdir}/firmware/rtlwifi/
    install -m 0644 ${S}/firmware/rtl8188fufw.bin ${D}${nonarch_base_libdir}/firmware/rtlwifi/
    install -m 0644 ${S}/firmware/rtl8710bufw_SMIC.bin ${D}${nonarch_base_libdir}/firmware/rtlwifi/
    install -m 0644 ${S}/firmware/rtl8710bufw_UMC.bin ${D}${nonarch_base_libdir}/firmware/rtlwifi/

    # Switch dongles that start in fake driver CD mode into Wi-Fi mode
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${UNPACKDIR}/rtl8xxxu-modeswitch.rules ${D}${sysconfdir}/udev/rules.d/
}

FILES:${PN}-firmware = " \
    ${nonarch_base_libdir}/firmware/rtlwifi/rtl8188eufw.bin \
    ${nonarch_base_libdir}/firmware/rtlwifi/rtl8188fufw.bin \
    ${nonarch_base_libdir}/firmware/rtlwifi/rtl8710bufw_SMIC.bin \
    ${nonarch_base_libdir}/firmware/rtlwifi/rtl8710bufw_UMC.bin \
"
FILES:${PN}-udev = "${sysconfdir}/udev/rules.d/rtl8xxxu-modeswitch.rules"
