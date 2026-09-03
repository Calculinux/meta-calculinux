PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1"
# M0 audio (rproc, snd-m0), unused snd-pins, and OTG VBUS always-on
# (Calculinux/picocalc-drivers#28, #29)
SRCREV = "88daa9c38a111dd8c1424d6c396e74b27f26a8fa"
S = "${WORKDIR}/git"
