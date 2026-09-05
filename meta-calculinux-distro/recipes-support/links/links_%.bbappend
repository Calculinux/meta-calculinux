# PicoCalc has no console mouse; gpm is feed-only (opkg install gpm).
# links FB graphics requires libgpm at configure time — keep text mode OOTB.
DEPENDS:remove = "gpm"
EXTRA_OECONF:remove = "--enable-graphics"
EXTRA_OECONF:append = " --disable-graphics --without-gpm"
