FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

LICENSE = "GPL-2.0-only"

SRCREV = "e0846929f1a797988a6965268f391fdb779becfc"

SRC_URI = " \
    git://github.com/0xd61/luckfox-linux-6.1-rk3506.git;protocol=https;nobranch=1 \
    file://picocalc;subdir=git/drivers/staging \
    file://rk3506-luckfox-lyra.dtsi;subdir=git/arch/${ARCH}/boot/dts/ \
    file://rk3506g-luckfox-lyra.dts;subdir=git/arch/${ARCH}/boot/dts/ \
    file://picocalc-drivers-support.patch \
    file://base-configs.cfg \
    file://wifi.cfg \
    file://rauc.cfg \
    file://cgroups.cfg \
    file://fonts.cfg \
    file://picocalc.cfg \
    file://removed.cfg \
    file://mmc-spi-fix-nullpointer-on-shutdown.patch \
"

KBUILD_DEFCONFIG = "rk3506_luckfox_defconfig"
