SUMMARY = "RTL8188eu WiFi kernel driver"
DESCRIPTION = "RTL8188eu WiFi kernel driver"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=3224303dd2d22c5ba741033e02e71cc6"

PV = "1.0-git"
SRCREV = "96ecc776167a15cc7df4efc4f721ba5784c55c85"
SRC_URI = " \
    git://github.com/Benetti-Engineering/rtl8188eu.git;protocol=https;branch=master \
    "
S = "${UNPACKDIR}/git"

DEPENDS += "virtual/kernel"

inherit module

MODULE_DIR="${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/"

EXTRA_OEMAKE += "MODULE_NAME=rtl8188eu \
                 USER_EXTRA_CFLAGS='-Wno-address' \
                 KSRC=${STAGING_KERNEL_DIR} \
                 KVER=${KERNEL_VERSION} \
                 "

RPROVIDES:${PN} += "kernel-module-rtl8188eu"
RCONFLICTS:${PN} = "linux-firmware-rtl8188"
RREPLACES:${PN} = "linux-firmware-rtl8188"

module_do_install() {
    install -d ${D}${MODULE_DIR}
    install -m 0644 ${S}/rtl8188eu.ko ${D}${MODULE_DIR}
}

do_install:append() {
    install -d ${D}${libdir}/firmware/rtlwifi
    install -m 0644 ${S}/firmware/rtl8188eufw.bin ${D}${libdir}/firmware/rtlwifi
}

FILES:${PN} += " \
    ${libdir}/firmware/rtlwifi/rtl8188eufw.bin \
"
