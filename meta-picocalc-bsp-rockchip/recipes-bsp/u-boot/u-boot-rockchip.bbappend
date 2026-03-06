FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRCREV_rkbin = "f43a462e7a1429a9d407ae52b4745033034a6cf9"

LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"

PATCHPATH = ""

EXTRA_OEMAKE += " KCFLAGS='-Wno-enum-int-mismatch -Wno-maybe-uninitialized'"

SRCREV = "c1758ed5fecd6200db4e211524be2a0b762670b9"
SRC_URI = " \
    git://github.com/Calculinux/luckfox-u-boot-2017.09-rk3506.git;nobranch=1;protocol=https \
    git://github.com/rockchip-linux/rkbin.git;protocol=https;nobranch=1;name=rkbin;destsuffix=rkbin; \
    file://backport-part-command-from-u-boot-2020.01.patch \
    file://backport-setexpr-fmt-from-u-boot-2021.10.patch \
    file://disable-display.cfg \
    file://partition-labels.cfg \
    file://rk3506_common.h;subdir=git/include/configs/ \
    file://rk3506_luckfox_defconfig;subdir=git/configs/ \
    file://rk3506b_luckfox.config;subdir=git/configs/ \
"

# Copy PicoCalc U-Boot device tree from devicetree helper recipe
do_prepare_uboot_picocalc() {
    PICOCALC_UBOOT_DTS_SOURCE="${RECIPE_SYSROOT}/usr/share/picocalc/rk3506-luckfox.dts"
    PICOCALC_UBOOT_DTSI_SOURCE="${RECIPE_SYSROOT}/usr/share/picocalc/rk3506-luckfox.dtsi"
    install -d ${S}/arch/arm/dts
    cp "${PICOCALC_UBOOT_DTS_SOURCE}" "${S}/arch/arm/dts/rk3506-luckfox.dts"
    cp "${PICOCALC_UBOOT_DTSI_SOURCE}" "${S}/arch/arm/dts/rk3506-luckfox.dtsi"
}

addtask do_prepare_uboot_picocalc after do_unpack before do_configure
do_prepare_uboot_picocalc[depends] += "picocalc-devicetree:do_populate_sysroot"

# Rockchip u-boot uses some special patches. Therefore we export mkimage into the deploy
# dir to have them available for other recipes.
do_prepare_host_tools() {
    install -D -m 0755 ${B}/tools/mkimage ${DEPLOY_DIR_IMAGE}/rockchip-mkimage-2017.09
}

FILES:${PN} = "/boot"

addtask do_prepare_host_tools after do_compile before do_install
