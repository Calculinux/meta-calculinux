# Enable DRM/KMS framebuffer capture support for PicoCalc
# This allows screen capture via the kmsgrab input device

PACKAGECONFIG:append = " drm"

# Add libdrm support for KMS/DRM screen capture
PACKAGECONFIG[drm] = "--enable-libdrm,--disable-libdrm,libdrm"
