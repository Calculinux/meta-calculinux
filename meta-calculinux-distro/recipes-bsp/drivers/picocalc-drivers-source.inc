PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio (#28/#29) + CMA disabled (#30) + PL330 mcbufsz for SPI fb without CMA (#31)
# + opt-in lcd-spi-100mhz overlay (#32)
# + M0 audio rework from picocalc-drivers#37 (branch m0-audio-trm-fixes, not yet
#   merged): firmware as TCM at 3 MHz, ring in system SRAM, interpolation, optional
#   correction for late pin writes (comp=1, needs the M0 at 375 MHz). This commit
#   does not have #33 (keyboard mouse-mode fix), merged on main after #32.
SRCREV = "f9777a674b1b2aeed3e50724cbc65e5ee2d7426a"
S = "${WORKDIR}/git"
