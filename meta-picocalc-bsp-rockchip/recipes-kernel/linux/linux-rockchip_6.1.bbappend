FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

LICENSE = "GPL-2.0-only"

SRCREV = "e0846929f1a797988a6965268f391fdb779becfc"

SRC_URI = " \
    git://github.com/Calculinux/luckfox-linux-6.1-rk3506.git;protocol=https;nobranch=1 \
    file://rk3506-luckfox-lyra.dtsi;subdir=git/arch/${ARCH}/boot/dts/ \
    file://rk3506g-luckfox-lyra.dts;subdir=git/arch/${ARCH}/boot/dts/ \
    file://base-configs.cfg \
    file://wifi.cfg \
    file://dto.cfg \
    file://rauc.cfg \
    file://cgroups.cfg \
    file://fonts.cfg \
    file://removed.cfg \
    file://utf8.cfg \
    file://mmc-spi-fix-nullpointer-on-shutdown.patch \
"

KBUILD_DEFCONFIG = "rk3506_luckfox_defconfig"

do_install:append() {
    # Remove kernel image formats that are not needed in the device image
    rm -f ${D}/boot/Image
    rm -f ${D}/boot/Image-*
    rm -f ${D}/boot/fitImage
    rm -f ${D}/boot/fitImage-*
    rm -f ${D}/boot/zboot.img
    rm -f ${D}/boot/zboot.img-*
}
