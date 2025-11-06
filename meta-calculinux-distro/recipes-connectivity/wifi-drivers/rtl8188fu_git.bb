SUMMARY = "RTL8188fu kernel driver (wifi + bluetooth)"
DESCRIPTION = "RTL8188fu kernel driver"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=b234ee4d69f5fce4486a80fdaf4a4263"

PV = "1.0-git"
SRCREV = "7ce43037212aab03a5cfe441992eee04de7f858d"
SRC_URI = " \
    git://github.com/kelebek333/rtl8188fu.git;protocol=https;branch=master \
    "
S = "${UNPACKDIR}/git"
B = "${S}"

inherit module

MODULE_DIR="${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/"
MAKE_TARGETS = "modules"

EXTRA_OEMAKE += "MODULE_NAME=rtl8188fu \
                 USER_EXTRA_CFLAGS='-Wno-address' \
                 KSRC=${STAGING_KERNEL_DIR} \
                 KVER=${KERNEL_VERSION} \
                 "

RPROVIDES:${PN} += "kernel-module-rtl8188fu"

module_do_install() {
    install -d ${D}${MODULE_DIR}
    install -m 0644 ${S}/rtl8188fu.ko ${D}${MODULE_DIR}
}

do_install:append() {
    install -d ${D}${libdir}/firmware/rtlwifi
    install -m 0644 ${S}/firmware/rtl8188fufw.bin ${D}${libdir}/firmware/rtlwifi
}

FILES:${PN} += " \
    ${libdir}/firmware/rtlwifi/rtl8188fufw.bin \
"
