PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio (rproc, snd-m0) plus unused snd-pins in the base dtsi
# (Calculinux/picocalc-drivers#28)
SRCREV = "5a618666d99860a1decb7cf62311956e45205cc0"
S = "${WORKDIR}/git"
