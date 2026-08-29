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
    file://v2026.07-rk3506/0004-video-Add-ILI9488-SPI-DM_VIDEO-driver.patch \
    file://v2026.07-rk3506/0005-pinctrl-rk3506-Add-RMIO-remux-support.patch \
    file://v2026.07-rk3506/0006-rockchip-rk3506-Default-stdout-to-serial-vidconsole.patch \
    file://v2026.07-rk3506/defconfig/luckfox-lyra-rk3506_defconfig \
    file://v2026.07-rk3506/dt/rk3506-luckfox-lyra.dts \
    file://v2026.07-rk3506/dt/rk3506-luckfox-lyra.dtsi \
    file://v2026.07-rk3506/dt/rk3506-luckfox-lyra-u-boot.dtsi \
    file://v2026.07-rk3506/dt/rk3506-luckfox-lyra-plus.dts \
    file://v2026.07-rk3506/dt/rk3506-luckfox-lyra-plus-u-boot.dtsi \
    file://v2026.07-rk3506/drivers/video/ili9488-spi.c \
    file://calculinux-logo.bmp \
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

# Armbian overlay dirs (defconfig + board DTs) — not git patches.
# Also install PicoCalc ILI9488 driver + generate logo C array from BMP.
do_configure:prepend() {
    install -d ${S}/configs ${S}/arch/arm/dts ${S}/drivers/video
    cp ${UNPACKDIR}/v2026.07-rk3506/defconfig/luckfox-lyra-rk3506_defconfig ${S}/configs/
    cp ${UNPACKDIR}/v2026.07-rk3506/dt/rk3506-luckfox-lyra.dts \
       ${UNPACKDIR}/v2026.07-rk3506/dt/rk3506-luckfox-lyra.dtsi \
       ${UNPACKDIR}/v2026.07-rk3506/dt/rk3506-luckfox-lyra-u-boot.dtsi \
       ${UNPACKDIR}/v2026.07-rk3506/dt/rk3506-luckfox-lyra-plus.dts \
       ${UNPACKDIR}/v2026.07-rk3506/dt/rk3506-luckfox-lyra-plus-u-boot.dtsi \
        ${S}/arch/arm/dts/
    cp ${UNPACKDIR}/v2026.07-rk3506/drivers/video/ili9488-spi.c ${S}/drivers/video/
    python3 - "${UNPACKDIR}/calculinux-logo.bmp" "${S}/drivers/video/calculinux-logo.c" <<'PY'
import sys
from pathlib import Path

bmp = Path(sys.argv[1])
out = Path(sys.argv[2])
data = bmp.read_bytes()
lines = [
    "/* SPDX-License-Identifier: GPL-2.0+ */",
    "/* Generated from calculinux-logo.bmp — do not edit */",
    "#include <linux/types.h>",
    "",
    f"const u8 calculinux_logo_bmp[{len(data)}] = {{",
]
row = []
for b in data:
    row.append(f"0x{b:02x}")
    if len(row) == 12:
        lines.append("\t" + ", ".join(row) + ",")
        row = []
if row:
    lines.append("\t" + ", ".join(row) + ",")
lines += [
    "};",
    "",
    f"const u32 calculinux_logo_bmp_len = {len(data)};",
    "",
]
out.write_text("\n".join(lines))
print(f"Wrote {out} ({len(data)} bytes)")
PY
}

COMPATIBLE_MACHINE = "luckfox-lyra"
