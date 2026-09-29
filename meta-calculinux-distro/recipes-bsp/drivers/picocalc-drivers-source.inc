PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# CMA disabled (#30) + PL330 mcbufsz for SPI fb without CMA (#31)
# + LCD spi-max-frequency 100MHz (#32)
SRCREV = "89ad0694ad80e22ab6f25f77c7269c68f937829d"
S = "${WORKDIR}/git"
