FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

LICENSE = "GPL-2.0-only"

SRCREV = "815d6a4af7589b0da6cc765658913d05fe550965"

SRC_URI = " \
    git://github.com/Calculinux/luckfox-linux-6.1-rk3506.git;protocol=https;nobranch=1 \
    file://base-configs.cfg \
    file://display.cfg \
    file://wifi.cfg \
    file://dto.cfg \
    file://rauc.cfg \
    file://cgroups.cfg \
    file://fonts.cfg \
    file://led.cfg \
    file://removed.cfg \
    file://utf8.cfg \
    file://filesystems.cfg \
    file://usb-gadget.cfg \
    file://audio-i2s.cfg \
    file://mmc-spi-fix-nullpointer-on-shutdown.patch \
    file://0001-of-configfs-overlay-interface.patch \
"

KERNEL_CONFIG_FRAGMENTS += " \
    base-configs.cfg \
    display.cfg \
    wifi.cfg \
    rauc.cfg \
    cgroups.cfg \
    fonts.cfg \
    led.cfg \
    removed.cfg \
    utf8.cfg \
    filesystems.cfg \
    usb-gadget.cfg \
    audio-i2s.cfg \
"

DEPENDS += "gzip"
KBUILD_DEFCONFIG = "rk3506_luckfox_defconfig"

ROCKCHIP_KERNEL_IMAGES = "0"
ROCKCHIP_KERNEL_COMPRESSED = "1"
KERNEL_IMAGETYPES = "zboot.img"

# Copy PicoCalc device tree from devicetree helper recipe
do_prepare_kernel_picocalc() {
    PICOCALC_DT_SOURCE="${RECIPE_SYSROOT}/usr/share/picocalc/picocalc-luckfox-lyra.dtsi"
    PICOCALC_BOARD_DTSI_SOURCE="${RECIPE_SYSROOT}/usr/share/picocalc/rk3506-luckfox-lyra.dtsi"
    PICOCALC_BOARD_DTS_SOURCE="${RECIPE_SYSROOT}/usr/share/picocalc/rk3506g-luckfox-lyra.dts"
    install -d ${S}/arch/${ARCH}/boot/dts
    cp "${PICOCALC_DT_SOURCE}" "${S}/arch/${ARCH}/boot/dts/picocalc-luckfox-lyra.dtsi"
    cp "${PICOCALC_BOARD_DTSI_SOURCE}" "${S}/arch/${ARCH}/boot/dts/rk3506-luckfox-lyra.dtsi"
    cp "${PICOCALC_BOARD_DTS_SOURCE}" "${S}/arch/${ARCH}/boot/dts/rk3506g-luckfox-lyra.dts"
}

addtask prepare_kernel_picocalc after do_kernel_checkout before do_kernel_configme
do_prepare_kernel_picocalc[depends] += "picocalc-devicetree:do_populate_sysroot"

do_install:append() {
    # Remove kernel image formats that are not needed in the device image
    rm -f ${D}/boot/Image
    rm -f ${D}/boot/Image-*

    gzip -k "${B}/.config"
    install -D -m 0644  "${B}/.config.gz" "${D}${datadir}/kernel/config.gz"
}

FILES:${KERNEL_PACKAGE_NAME}-base += "${datadir}/kernel"
