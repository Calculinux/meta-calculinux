PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# CMA disabled (#30) + PL330 mcbufsz for SPI fb without CMA (#31)
# + opt-in lcd-spi-100mhz overlay (#32)
SRCREV = "cf9f01a1e363d6463ac4a1fe0dccdd9da3172385"
