PV = "1.0+git${SRCPV}"
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI = "git://github.com/Calculinux/picocalc-drivers.git;protocol=https;nobranch=1 \
           file://0001-move-snd-pins-into-base-dtsi.patch"
# M0 audio (rproc, snd-m0) at d562af78. snd-pins are patched into the base
# dtsi here; this agent cannot push Calculinux/picocalc-drivers. Drop the
# patch and bump SRCREV when that change is on picocalc-drivers main.
SRCREV = "d562af782151cf7bb0d3a23693de4bf70084dc73"
S = "${WORKDIR}/git"
