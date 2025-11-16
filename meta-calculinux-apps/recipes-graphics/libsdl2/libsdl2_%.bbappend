# The Luckfox SPI LCD is driven via TinyDRM, so SDL should use the KMS/DRM
# renderer by default. Keep other backends available for manual opt-in.
PACKAGECONFIG[fbcon] = "-DSDL_FBDEV=ON,-DSDL_FBDEV=OFF"
PACKAGECONFIG[directfb] = "-DSDL_DIRECTFB=ON,-DSDL_DIRECTFB=OFF,directfb"
PACKAGECONFIG:remove = "fbcon directfb"
PACKAGECONFIG:append = " kmsdrm"

# Bump PR to force rebuild with KMSDRM support
PR = "r3"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://sdl2-defaults.sh"

do_install:append() {
    install -d ${D}${sysconfdir}/profile.d
    install -m 0644 ${UNPACKDIR}/sdl2-defaults.sh ${D}${sysconfdir}/profile.d/
}

FILES:${PN} += "${sysconfdir}/profile.d/sdl2-defaults.sh"
