FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

LICENSE = "GPL-2.0-only"

SRCREV = "e0846929f1a797988a6965268f391fdb779becfc"

SRC_URI = " \
    git://github.com/0xd61/luckfox-linux-6.1-rk3506.git;protocol=https;nobranch=1 \
    file://rk3506-luckfox-lyra.dtsi;subdir=git/arch/${ARCH}/boot/dts/ \
    file://rk3506g-luckfox-lyra.dts;subdir=git/arch/${ARCH}/boot/dts/ \
    file://base-configs.cfg \
    file://wifi.cfg \
    file://rauc.cfg \
    file://cgroups.cfg \
    file://fonts.cfg \
    file://led.cfg \
    file://removed.cfg \
    file://mmc-spi-fix-nullpointer-on-shutdown.patch \
"

KBUILD_DEFCONFIG = "rk3506_luckfox_defconfig"

ROCKCHIP_KERNEL_IMAGES = "0"
ROCKCHIP_KERNEL_COMPRESSED = "1"
KERNEL_IMAGETYPES = "zboot.img"

# Copy PicoCalc device tree from staged location
do_prepare_kernel_picocalc() {
    PICOCALC_DT_SOURCE="/build/tmp/work/luckfox_lyra-poky-linux-musleabi/picocalc-drivers/1.0/devicetree-staging/picocalc-luckfox-lyra.dtsi"
    cp "${PICOCALC_DT_SOURCE}" "${S}/arch/${ARCH}/boot/dts/picocalc-luckfox-lyra.dtsi"
}

addtask prepare_kernel_picocalc after do_kernel_checkout before do_kernel_configme
do_prepare_kernel_picocalc[depends] += "picocalc-drivers:do_stage_devicetree"

do_install:append() {
    # Remove kernel image formats that are not needed in the device image
    rm -f ${D}/boot/Image
    rm -f ${D}/boot/Image-*
}
