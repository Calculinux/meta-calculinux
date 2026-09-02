PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio (rproc, snd-m0) plus unused snd-pins in the base dtsi
# (Calculinux/picocalc-drivers#28)
SRCREV = "13c26548295abde9e4addc2a48bf52554450aed1"
S = "${WORKDIR}/git"
