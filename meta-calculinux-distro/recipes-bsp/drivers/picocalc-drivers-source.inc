PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# overlay-symbols.txt for kernel __symbols__ injection (Calculinux/picocalc-drivers#26)
SRCREV = "74dc424722c20db62b9dbbf95a1889b339a85226"
S = "${WORKDIR}/git"
