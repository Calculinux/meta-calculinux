# The Luckfox SPI LCD is driven via TinyDRM, so SDL should use the KMS/DRM
# renderer by default. Keep other backends (fbcon, directfb) available as fallbacks.
# Disable OpenGL/GLES since this is an SPI display without GPU acceleration.
PACKAGECONFIG[fbcon] = "-DSDL_FBDEV=ON,-DSDL_FBDEV=OFF"
PACKAGECONFIG[directfb] = "-DSDL_DIRECTFB=ON,-DSDL_DIRECTFB=OFF,directfb"
# Remove directfb (extra dependencies), opengl/gles (no GPU), keep fbcon as fallback
PACKAGECONFIG:remove = "directfb opengl gles2"
PACKAGECONFIG:append = " kmsdrm fbcon"

# Runtime dependencies for kmsdrm backend:
# - libdrm: DRM/KMS interface library
# - libgbm: Generic Buffer Manager for allocating graphics buffers
# Note: mesa and EGL not needed since OpenGL/GLES are disabled for this SPI display
RDEPENDS:${PN}:append = " libdrm libgbm"

# Bump PR to force rebuild without OpenGL/EGL dependencies
PR = "r14"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://sdl2-defaults.sh"

do_install:append() {
    install -d ${D}${sysconfdir}/profile.d
    install -m 0644 ${UNPACKDIR}/sdl2-defaults.sh ${D}${sysconfdir}/profile.d/
}

FILES:${PN} += "${sysconfdir}/profile.d/sdl2-defaults.sh"
