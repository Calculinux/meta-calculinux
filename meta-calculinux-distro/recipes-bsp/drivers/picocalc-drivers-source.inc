PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio (rproc, snd-m0) plus unused snd-pins in the base dtsi
# (Calculinux/picocalc-drivers#28)
SRCREV = "0dada102464a130dc3090d1df40bb95a7e2df27d"
S = "${WORKDIR}/git"
