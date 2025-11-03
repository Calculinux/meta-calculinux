SUMMARY = "AIC8800 Wi-Fi driver and firmware"
DESCRIPTION = "Out-of-tree full MAC driver for AIC8800 USB adapters with bundled firmware and udev helpers"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit module

PV = "1.1.0+git${SRCPV}"
SRC_URI = "git://github.com/CELIANVF/aic8800_linux_drvier.git;protocol=https;branch=main"
SRCREV = "5b85ae0cc8a9f6e154c850006cda8390cb0d37e1"

S = "${WORKDIR}/git/drivers/aic8800"

COMPATIBLE_MACHINE = "luckfox-lyra"

EXTRA_OEMAKE += " \
    KDIR=${STAGING_KERNEL_DIR} \
    ARCH=${ARCH} \
    CROSS_COMPILE=${TARGET_PREFIX} \
    CONFIG_PLATFORM_UBUNTU=n \
    CONFIG_PLATFORM_ROCKCHIP=n \
    CONFIG_PLATFORM_ALLWINNER=n \
    CONFIG_PLATFORM_AMLOGIC=n \
    CONFIG_PLATFORM_HI=n \
    V=1 \
"

do_compile() {
    unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
    oe_runmake -C ${S} modules
}

do_install() {
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra
    install -m 0644 ${S}/aic_load_fw/aic_load_fw.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    install -m 0644 ${S}/aic8800_fdrv/aic8800_fdrv.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/

    install -d ${D}${base_libdir}/firmware
    cp -r ${WORKDIR}/git/fw/aic8800D80 ${D}${base_libdir}/firmware/
    find ${D}${base_libdir}/firmware/aic8800D80 -type d -exec chmod 0755 {} +
    find ${D}${base_libdir}/firmware/aic8800D80 -type f -exec chmod 0644 {} +

    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/git/tools/aic.rules ${D}${sysconfdir}/udev/rules.d/aic.rules
}

FILES:${PN} += " \
    ${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/aic_load_fw.ko \
    ${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/aic8800_fdrv.ko \
    ${base_libdir}/firmware/aic8800D80 \
    ${sysconfdir}/udev/rules.d/aic.rules \
"

RPROVIDES:${PN} += "kernel-module-aic8800_fdrv"

KERNEL_MODULE_AUTOLOAD:${PN} = "aic_load_fw aic8800_fdrv"

RDEPENDS:${PN} += "udev"
