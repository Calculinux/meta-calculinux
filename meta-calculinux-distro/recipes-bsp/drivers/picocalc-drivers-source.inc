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
#   Also, in the base dtsi, hclk_lsperi_root (the SPI controllers' and GPIO4's
#   register bus) at 187.5 MHz and 2-word SPI1 DMA bursts: SD-read noise at the
#   headphone output follows those two, not the card or the M0's lag.
#   Re-pin to main once #39 and that are merged.
# + branch sd-comp-policy at e20c3f3: the corrected loop (m0_play_comp) runs
#   SysTick free (24-bit) and spins to each tick, so a pin write's lateness is a
#   count difference with no -28..+99 cycle window (a write caught up 40 cycles
#   early after a late one was misread). Jack-tip noise with the card read at
#   4-word bursts drops from about 7 mV to about 0.65 mV; tone THD+N at 25 MHz
#   4-word from -9.9 to -26.8 dB (docs/m0-audio.md). The core no longer sleeps
#   between ticks while audio plays (power not yet measured).
SRCREV = "e8011b8a78372d44db84b013ce74a3c724320134"
S = "${WORKDIR}/git"
