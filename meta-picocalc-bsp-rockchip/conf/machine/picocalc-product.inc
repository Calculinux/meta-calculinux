# PicoCalc product (motherboard) packages.
#
# Tiering: SoC (lyra/rockchip, later milk-v, ...) < PicoCalc motherboard <
# calculinux OS. The packages listed here attach to the motherboard itself,
# not to the SoC under it, so every machine built for the PicoCalc board -
# this Lyra/Rockchip one, and the milk-v variant that is coming - includes
# this fragment and pulls the same product packages into the image.
#
# SoC-specific packages (boot chain, DT overlays, kernel glue) stay in the
# machine conf of the SoC BSP.
#
# Note: the incumbent list in conf/machine/luckfox-lyra.conf predates this
# fragment and still mixes the two tiers; expect it to drain into the
# appropriate homes as the BSP layers are split up.

PICOCALC_PRODUCT_RDEPENDS = " \
    calculinux-alsa-config \
    calculinux-sdcard \
"
