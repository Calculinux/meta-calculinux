PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio (rproc, snd-m0) plus unused snd-pins in the base dtsi
# (Calculinux/picocalc-drivers#28)
SRCREV = "ebd67d89b15e75e6206aa479dad941b9cf0b0447"
S = "${WORKDIR}/git"
