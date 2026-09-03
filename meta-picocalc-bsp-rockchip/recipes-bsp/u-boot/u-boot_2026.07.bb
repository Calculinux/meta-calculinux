SUMMARY = "Universal Boot Loader for embedded devices"
DESCRIPTION = "Mainline U-Boot v2026.07 with Kwiboo/Armbian RK3506 support \
(see armbian/build#10470)."
HOMEPAGE = "https://www.denx.de/wiki/U-Boot"
SECTION = "bootloaders"
LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://Licenses/README;md5=2ca5f2c35c8cc335f0a19756634782f1"

require recipes-bsp/u-boot/u-boot.inc

DEPENDS += "bc-native bison-native dtc-native flex-native gnutls-native python3-pyelftools-native python3-setuptools-native"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# v2026.07
SRCREV = "ece349ade2973e220f524ce59e59711cc919263f"
# armbian/rkbin (DDR v1.09 + tee v2.10 for RK3506)
SRCREV_rkbin = "1d3c61008fa823936ae7a59615393f8294b64456"

SRC_URI = " \
    git://source.denx.de/u-boot/u-boot.git;protocol=https;branch=master;name=default \
    git://github.com/armbian/rkbin.git;protocol=https;branch=master;name=rkbin;destsuffix=rkbin \
    file://v2026.07-rk3506/0001-rockchip-spl-Allow-use-of-ROCKCHIP_SPL_RESERVE_IRAM-on-ARMv7.patch \
    file://v2026.07-rk3506/0002-rockchip-rk3506-Add-WIP-device-trees.patch \
    file://v2026.07-rk3506/0003-rockchip-rk3506-Enable-use-of-SPL_OPTEE_IMAGE.patch \
    file://v2026.07-rk3506/rockchip-rk3506-Identify-RK3506Gx-SoC-variants.patch \
    file://v2026.07-rk3506/rockchip-rk3506-Imply-OF_UPSTREAM.patch \
    file://v2026.07-rk3506/rockchip-rk3506-Remove-unneeded-syscon-driver.patch \
    file://v2026.07-rk3506/rockchip-rk3506-Remove-unused-rockchip_get_clk-helper.patch \
    file://v2026.07-rk3506/rockchip-rk3506-Update-ENV_MEM_LAYOUT_SETTINGS.patch \
    file://v2026.07-rk3506/rockchip-rk3506-clk-Fix-CLK_SARADC-set-rate-issues.patch \
    file://v2026.07-rk3506/rockchip-rk3506-clk-Fix-trivial-clock-configuration-errors.patch \
    file://v2026.07-rk3506/rockchip-rk3506-saradc-Add-driver-data.patch \
    file://v2026.07-rk3506/defconfig/luckfox-lyra-rk3506_defconfig \
    file://v2026.07-rk3506/dt/rk3506-luckfox-lyra.dts \
    file://v2026.07-rk3506/dt/rk3506-luckfox-lyra.dtsi \
    file://v2026.07-rk3506/dt/rk3506-luckfox-lyra-u-boot.dtsi \
    file://v2026.07-rk3506/dt/rk3506-luckfox-lyra-plus.dts \
    file://v2026.07-rk3506/dt/rk3506-luckfox-lyra-plus-u-boot.dtsi \
    file://calculinux.cfg \
"

SRCREV_FORMAT = "default_rkbin"

S = "${WORKDIR}/git"
B = "${WORKDIR}/build"

UBOOT_BINARY = "u-boot-rockchip.bin"

RKBIN_DDR = "rk3506_ddr_750MHz_v1.09.bin"
RKBIN_TEE = "rk3506_tee_v2.10.bin"

EXTRA_OEMAKE += " \
    ROCKCHIP_TPL=${UNPACKDIR}/rkbin/rk35/${RKBIN_DDR} \
    TEE=${UNPACKDIR}/rkbin/rk35/${RKBIN_TEE} \
"

# Armbian overlay dirs (defconfig + board DTs) — not git patches
do_configure:prepend() {
    install -d ${S}/configs ${S}/arch/arm/dts
    cp ${UNPACKDIR}/v2026.07-rk3506/defconfig/luckfox-lyra-rk3506_defconfig ${S}/configs/
    cp ${UNPACKDIR}/v2026.07-rk3506/dt/rk3506-luckfox-lyra.dts \
       ${UNPACKDIR}/v2026.07-rk3506/dt/rk3506-luckfox-lyra.dtsi \
       ${UNPACKDIR}/v2026.07-rk3506/dt/rk3506-luckfox-lyra-u-boot.dtsi \
       ${UNPACKDIR}/v2026.07-rk3506/dt/rk3506-luckfox-lyra-plus.dts \
       ${UNPACKDIR}/v2026.07-rk3506/dt/rk3506-luckfox-lyra-plus-u-boot.dtsi \
        ${S}/arch/arm/dts/
}

# Blob at 32 KiB must end before ubootenv at 6 MiB (OTA + WIC share this ceiling).
UBOOT_OTA_MAX_BYTES = "6258688"

do_install:append() {
    install -d ${D}${libdir}/calculinux
    install -m 0644 ${B}/${UBOOT_BINARY} ${D}${libdir}/calculinux/${UBOOT_BINARY}
}

do_deploy:append() {
    bin="${DEPLOYDIR}/${UBOOT_BINARY}"
    if [ ! -f "$bin" ]; then
        bin="${B}/${UBOOT_BINARY}"
    fi
    if [ -f "$bin" ]; then
        size=$(stat -c%s "$bin")
        if [ "$size" -gt "${UBOOT_OTA_MAX_BYTES}" ]; then
            bbfatal "${UBOOT_BINARY} is ${size} bytes; must be <= ${UBOOT_OTA_MAX_BYTES} (6 MiB - 32 KiB)"
        fi
    fi
}

PACKAGES =+ "${PN}-ota"
FILES:${PN}-ota = "${libdir}/calculinux/${UBOOT_BINARY}"

COMPATIBLE_MACHINE = "luckfox-lyra"
