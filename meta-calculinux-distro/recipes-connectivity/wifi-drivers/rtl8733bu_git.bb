SUMMARY = "Realtek RTL8731BU / RTL8733BU USB WiFi driver"
DESCRIPTION = "Out-of-tree WiFi driver for RTL8731BU and RTL8733BU chipsets."
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

SRC_URI = "git://github.com/libc0607/rtl8733bu-20230626.git;branch=v5.13.0.1;protocol=https"
SRCREV = "82224810a95d8d8033d1dd38bae53a35f8d9325d"

S = "${UNPACKDIR}/git"
DEPENDS += "virtual/kernel"

inherit module

MODULE_DIR = "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/"

EXTRA_OEMAKE = "\
    MODULE_NAME=rtl8733bu \
    KSRC=${STAGING_KERNEL_DIR} \
    KVER=${KERNEL_VERSION} \
KCFLAGS='-Wno-error=misleading-indentation -Wno-error=address -Wno-error'"


RPROVIDES:${PN} += "kernel-module-rtl8733bu"

module_do_install() {
    install -d ${D}${MODULE_DIR}
    install -m 0644 ${S}/rtl8733bu.ko ${D}${MODULE_DIR}
}
