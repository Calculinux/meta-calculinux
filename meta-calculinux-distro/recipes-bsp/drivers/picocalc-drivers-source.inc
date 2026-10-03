PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio (#28/#29) + CMA disabled (#30) + PL330 mcbufsz for SPI fb without CMA (#31)
# + opt-in lcd-spi-100mhz overlay (#32) + keyboard mouse-mode fix (#33)
# + M0 audio rework from picocalc-drivers#37 (branch m0-audio-trm-fixes, not yet
#   merged): firmware as TCM, ring in system SRAM, interpolation, and the loop
#   that corrects for late pin writes. The m0-audio overlay runs the M0 at
#   375 MHz and turns that loop on; the base dtsi asks for 4-word DMA bursts on
#   the display's SPI controller (needs spi-rockchip-tx-dma-burst-from-dt.patch).
SRCREV = "ba6bc6e8db8ae9dc38bdff3271831fbe617b9fad"
S = "${WORKDIR}/git"
