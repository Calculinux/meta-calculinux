PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio drivers (rproc, snd-m0); drop unused unmap_tcm label for -Werror
SRCREV = "d562af782151cf7bb0d3a23693de4bf70084dc73"
S = "${WORKDIR}/git"
