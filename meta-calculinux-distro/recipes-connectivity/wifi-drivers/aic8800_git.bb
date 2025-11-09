SUMMARY = "AIC8800 USB Wi-Fi/Bluetooth kernel module"
DESCRIPTION = "Out-of-tree USB driver and bundled firmware for the AIC8800 wireless combo chipset."
HOMEPAGE = "https://github.com/radxa-pkg/aic8800"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://${WORKDIR}/git/LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

SRC_URI = "git://github.com/radxa-pkg/aic8800.git;branch=main;protocol=https \
           file://fix-usb-firmware-path.patch;patchdir=${WORKDIR}/git \
           file://fix-usb-build.patch;patchdir=${WORKDIR}/git \
           file://fix-linux-6.1-build.patch;patchdir=${WORKDIR}/git \
           file://fix-aic_btusb.patch;patchdir=${WORKDIR}/git \
          "
SRCREV = "451a1c8f14dad821034017ccb902eaf0a2b8c2ee"
PV = "4.0+git${SRCPV}"

S = "${WORKDIR}/git/src/USB/driver_fw/drivers/aic8800"
B = "${S}"
AIC8800_GITDIR = "${WORKDIR}/git"

DEPENDS = "virtual/kernel"

inherit module

EXTRA_OEMAKE += "KDIR=${STAGING_KERNEL_BUILDDIR}"
EXTRA_OEMAKE += "KSRC=${STAGING_KERNEL_DIR}"
EXTRA_OEMAKE += "ARCH=${ARCH}"
EXTRA_OEMAKE += "CROSS_COMPILE=${TARGET_PREFIX}"
EXTRA_OEMAKE += "CONFIG_PLATFORM_UBUNTU=n"
EXTRA_OEMAKE += "CONFIG_USE_FW_REQUEST=y"
EXTRA_OEMAKE += "CONFIG_AIC_FW_PATH=/lib/firmware/aic8800/USB"

PACKAGES =+ "${PN}-firmware"

FILES:${PN} = "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/aic8800/usb/*.ko"
FILES:${PN}-firmware = "${nonarch_base_libdir}/firmware/aic8800"

RDEPENDS:${PN} += "${PN}-firmware"
RPROVIDES:${PN} += "kernel-module-aic-load-fw-${KERNEL_VERSION} kernel-module-aic8800-fdrv-${KERNEL_VERSION}"

KERNEL_MODULE_AUTOLOAD:${PN} = "aic_load_fw aic8800_fdrv"

COMPATIBLE_MACHINE = "luckfox-lyra"

do_install() {
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/aic8800/usb
    install -m 0644 ${S}/aic_load_fw/aic_load_fw.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/aic8800/usb/
    install -m 0644 ${S}/aic8800_fdrv/aic8800_fdrv.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/aic8800/usb/

    install -d ${D}${nonarch_base_libdir}/firmware/aic8800/USB
    cp -r --no-preserve=ownership ${AIC8800_GITDIR}/src/USB/driver_fw/fw/. ${D}${nonarch_base_libdir}/firmware/aic8800/USB/
}
