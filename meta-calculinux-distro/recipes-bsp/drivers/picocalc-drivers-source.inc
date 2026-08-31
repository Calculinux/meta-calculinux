PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio drivers (rproc, snd-m0); fail-fast module build + overlay-symbols.txt
SRCREV = "83e44e4dbc66f517a9c648eb90dfde5ffde97fcf"
S = "${WORKDIR}/git"
