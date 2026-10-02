PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# CMA disabled (#30) + PL330 mcbufsz for SPI fb without CMA (#31)
# + opt-in lcd-spi-100mhz overlay (#32) + clear stale mouse-mode
# flags on arrow release and mode-off (#33)
SRCREV = "232baf58356c74e14bf6f89a47a2c7b3a43b2b9d"
S = "${WORKDIR}/git"
