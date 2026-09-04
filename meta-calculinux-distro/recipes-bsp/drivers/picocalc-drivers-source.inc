PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# Includes vbus-always-on (#29) and CMA disabled (#30)
SRCREV = "fff02f377980b54cba0aa254d8fabcd4125daa34"
S = "${WORKDIR}/git"
