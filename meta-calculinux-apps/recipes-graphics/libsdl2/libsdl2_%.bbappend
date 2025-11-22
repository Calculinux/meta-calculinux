# The Luckfox SPI LCD is driven via TinyDRM, so SDL should use the KMS/DRM
# renderer by default. Keep other backends (fbcon, directfb) available as fallbacks.
# Disable OpenGL/GLES since this is an SPI display without GPU acceleration.
PACKAGECONFIG[fbcon] = "-DSDL_FBDEV=ON,-DSDL_FBDEV=OFF"
PACKAGECONFIG[directfb] = "-DSDL_DIRECTFB=ON,-DSDL_DIRECTFB=OFF,directfb"
# Remove directfb (extra dependencies), opengl/gles (no GPU), keep fbcon as fallback
PACKAGECONFIG:remove = "directfb opengl gles2"
PACKAGECONFIG:append = " kmsdrm fbcon"

# Runtime dependency for kmsdrm backend:
# - libdrm: dynamically loaded at runtime, so it isn't captured by shlibdeps
# GBM/EGL paths are disabled, so libgbm is no longer needed.
RDEPENDS:${PN}:append = " libdrm"

# Bump PR to force rebuild without OpenGL/EGL dependencies
PR = "r15"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " \
    file://sdl2-defaults.sh \
    file://0001-kmsdrm-add-dumb-buffer-support.patch \
"

do_install:append() {
    install -d ${D}${sysconfdir}/profile.d
    install -m 0644 ${UNPACKDIR}/sdl2-defaults.sh ${D}${sysconfdir}/profile.d/
}

FILES:${PN} += "${sysconfdir}/profile.d/sdl2-defaults.sh"
