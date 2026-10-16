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
# + (picocalc-drivers #39, merged): the corrected loop (m0_play_comp) runs
#   SysTick free (24-bit) and spins to each tick, so a pin write's lateness is a
#   count difference with no -28..+99 cycle window (a write caught up 40 cycles
#   early after a late one was misread). Jack-tip noise with the card read at
#   4-word bursts drops from about 7 mV to about 0.65 mV; tone THD+N at 25 MHz
#   4-word from -9.9 to -26.8 dB (docs/m0-audio.md). The core no longer sleeps
#   between ticks while audio plays (power not yet measured).
# + picocalc-drivers#40 (merged): no pop at stream start and stop: the M0 fades
#   its pins between idle (low) and the silence level over 90 ms with a
#   second-order loop that corrects for late writes (recorded: peak 1.1 FS
#   clipped -> 0.37 FS, average -12 -> -29 dBFS, docs/m0-audio.md), the
#   driver's pace check starts at the first frame the M0 reads, and
#   comp_gave_up is gone (the lag check only logs a warning).
SRCREV = "0d07ac88e6b0ef30cdb9dc69f2da2645df9fe34a"
S = "${WORKDIR}/git"
