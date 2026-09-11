PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio (#28/#29) + CMA disabled (#30) + PL330 mcbufsz for SPI fb without CMA (#31)
SRCREV = "f2e0d5a4d12a8140b430ea9dcb93ecf49f0319de"
S = "${WORKDIR}/git"
