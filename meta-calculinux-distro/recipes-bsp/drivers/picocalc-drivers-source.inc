PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# main at the merge of the M0 audio rework (#37), on top of M0 audio (#28/#29),
# CMA disabled (#30), PL330 mcbufsz for SPI fb without CMA (#31), the opt-in
# lcd-spi-100mhz overlay (#32) and the keyboard mouse-mode fix (#33).
# #37: firmware as TCM, ring in system SRAM, interpolation, and the loop that
# corrects for late pin writes. The m0-audio overlay runs the M0 at 375 MHz and
# turns that loop on; the base dtsi asks for 4-word DMA bursts on the display's
# SPI controller (the kernel's rockchip,tx-dma-burst support).
# + picocalc-drivers#38 (branch fix/spi-sd-card-detect, not yet merged): the SD
#   slot on SPI1 detects the card by GPIO and no longer polls it once a second,
#   and asks for 4-word DMA bursts both ways (the kernel's rockchip,tx-dma-burst
#   and rockchip,rx-dma-burst). Re-pin to main once #38 is merged.
SRCREV = "7f15fdafd843a2a3d750635d0aebe4371876ab14"
S = "${WORKDIR}/git"
