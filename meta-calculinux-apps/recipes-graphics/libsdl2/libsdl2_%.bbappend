# The Luckfox SPI LCD is driven via TinyDRM, so SDL should use the KMS/DRM
# renderer by default. Keep other backends available for manual opt-in.
PACKAGECONFIG[fbcon] = "-DSDL_FBDEV=ON,-DSDL_FBDEV=OFF"
PACKAGECONFIG[directfb] = "-DSDL_DIRECTFB=ON,-DSDL_DIRECTFB=OFF,directfb"
PACKAGECONFIG:remove = "fbcon directfb"
PACKAGECONFIG:append = " kmsdrm"
