PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# main at the merge of #38 (SD slot on SPI1: card detect by GPIO, so the card is
# no longer polled once a second), on top of the M0 audio rework (#37), M0 audio
# (#28/#29), CMA disabled (#30), PL330 mcbufsz for SPI fb without CMA (#31), the
# opt-in lcd-spi-100mhz overlay (#32) and the keyboard mouse-mode fix (#33).
# #37: firmware as TCM, ring in system SRAM, interpolation, and the loop that
# corrects for late pin writes. The m0-audio overlay runs the M0 at 375 MHz and
# turns that loop on; the base dtsi asks for 4-word DMA bursts on the display's
# SPI controller (the kernel's rockchip,tx-dma-burst support).
# + picocalc-drivers#39 (branch fix/spi-sd-card-detect, not yet merged): 4-word
#   DMA bursts both ways on SPI1 (the kernel's rockchip,tx-dma-burst and
#   rockchip,rx-dma-burst) and, on trial, cap-sd-highspeed on the SD slot for
#   50 MHz.
# + branch sd-comp-policy (merged with #39's head; not yet a PR): the corrected
#   loop's give-up limit raised from 1 to 20 ms/s, so reading the SD card no
#   longer switches it off for the session, and the COMP_STATS=2 debug build.
#   Re-pin to main once #39 and that are merged.
SRCREV = "0782bc063b97c17f40bee51855c5680a67609b80"
S = "${WORKDIR}/git"
