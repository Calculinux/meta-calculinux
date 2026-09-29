PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# CMA disabled (#30) + PL330 mcbufsz for SPI fb without CMA (#31)
# + opt-in lcd-spi-100mhz overlay (#32)
SRCREV = "08bb73f1da443cf67f18ee45c08fe6cdc5ba0043"
S = "${WORKDIR}/git"
