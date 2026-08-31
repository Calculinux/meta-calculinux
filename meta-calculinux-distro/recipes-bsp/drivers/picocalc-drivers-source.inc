PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio drivers (rproc, snd-m0) plus overlay-symbols after main merge
SRCREV = "932a5eb2760c78ef28c90554721e4544d6e0c12a"
S = "${WORKDIR}/git"
