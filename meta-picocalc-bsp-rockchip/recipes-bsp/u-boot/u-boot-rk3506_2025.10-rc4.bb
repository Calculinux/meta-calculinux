require recipes-bsp/u-boot/u-boot-common.inc
require recipes-bsp/u-boot/u-boot.inc

DEPENDS += "bc-native dtc-native gnutls-native python3-pyelftools-native "

SRCREV = "a72ec1294fc6ba6b0bfd5ebc912a7bed2dc2513d"
SRCREV_rkbin = "74213af1e952c4683d2e35952507133b61394862"

SRC_URI = " \
    git://source.denx.de/u-boot/contributors/kwiboo/u-boot.git;protocol=https;branch=rk3506 \
    git://github.com/rockchip-linux/rkbin.git;protocol=https;branch=master;name=rkbin;destsuffix=rkbin; \
    file://rk3506_common.h;subdir=git/include/configs/ \
    file://rk3506-luckfox-lyra.dtsi;subdir=git/arch/arm/dts/ \
    file://rk3506-luckfox.dts;subdir=git/arch/arm/dts/ \
    file://rk3506_luckfox_defconfig;subdir=git/configs/ \
"

SRCREV_FORMAT = "default_rkbin"

export ROCKCHIP_TPL = "${UNPACKDIR}/rkbin/bin/rk35/rk3506_ddr_750MHz_v1.06.bin"
export TEE = "${UNPACKDIR}/rkbin/bin/rk35/rk3506_tee_v2.10.bin"

do_deploy:append () {
    install "${B}/u-boot-rockchip.bin" "${DEPLOYDIR}/u-boot-rockchip.bin-${PV}"
    ln -sf "u-boot-rockchip.bin-${PV}" "${DEPLOYDIR}/u-boot-rockchip.bin"
}
