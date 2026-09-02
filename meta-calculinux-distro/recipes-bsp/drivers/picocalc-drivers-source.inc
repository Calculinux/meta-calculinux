PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio (rproc, snd-m0) plus unused snd-pins in the base dtsi
# (Calculinux/picocalc-drivers#28)
SRCREV = "00af42691d37df7c6ac4a1a6a64994451f7148a9"
S = "${WORKDIR}/git"
