SUMMARY = "RTW89 kernel driver for Realtek Wi-Fi 6/7 USB adapters"
DESCRIPTION = "Out-of-tree rtw89 driver (morrownr/rtw89 with 6.1 compat) for \
Realtek RTL8851BU, RTL8852AU, RTL8852BU, RTL8852CU and RTL8922AU USB Wi-Fi. \
The 6.1 kernel only ships the PCIe rtw89 drivers."
HOMEPAGE = "https://github.com/Calculinux/rtw89"
LICENSE = "GPL-2.0-only | BSD-3-Clause"
LIC_FILES_CHKSUM = " \
    file://core.c;beginline=1;endline=1;md5=04cb8411563d8726ae2273d76febc90d \
    file://firmware/LICENCE.rtlwifi_firmware.txt;md5=308b6dce04fb3dd6dd35237918e74f0f \
"

PV = "1.0-git"

SRC_URI = "git://github.com/Calculinux/rtw89.git;protocol=https;branch=calculinux-6.1"
SRCREV = "1c9c1540e30352e4bc7c6ee5d4e83e1ed59eabd5"

DEPENDS += "virtual/kernel"

inherit module

MODULE_DIR = "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/realtek/rtw89"

EXTRA_OEMAKE += "\
    KDIR=${STAGING_KERNEL_BUILDDIR} \
    KVER=${KERNEL_VERSION} \
    NPROC=${@oe.utils.cpu_count()} \
    "

PACKAGES =+ "${PN}-firmware"

# Combo dongles (e.g. RTL8852BU) start in fake driver CD mode
RDEPENDS:${PN} += "${PN}-firmware realtek-usb-modeswitch"

module_do_install() {
    install -d ${D}${MODULE_DIR}
    install -m 0644 ${B}/*.ko ${D}${MODULE_DIR}/
}

# Firmware for the chips that have USB variants. linux-firmware's copies are
# removed in its bbappend so these are the only rtw89 blobs in the image.
RTW89_FIRMWARE = " \
    rtw8851b_fw-1.bin \
    rtw8852a_fw-1.bin \
    rtw8852b_fw-2.bin \
    rtw8852c_fw-2.bin \
    rtw8922a_fw-4.bin \
"

do_install:append() {
    install -d ${D}${nonarch_base_libdir}/firmware/rtw89
    for fw in ${RTW89_FIRMWARE}; do
        install -m 0644 ${S}/firmware/$fw ${D}${nonarch_base_libdir}/firmware/rtw89/
    done
}

FILES:${PN}-firmware = "${nonarch_base_libdir}/firmware/rtw89"
