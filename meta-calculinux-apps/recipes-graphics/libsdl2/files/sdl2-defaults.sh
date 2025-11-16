# SDL2 default configuration for PicoCalc/Calculinux
# Sets SDL to use KMS/DRM video driver by default

# Use KMSDRM video driver for direct rendering to DRM/KMS displays
export SDL_VIDEODRIVER=kmsdrm

# Disable mouse cursor (useful for touch-only devices)
# Uncomment if needed:
# export SDL_VIDEO_KMSDRM_SHOW_CURSOR=0

# For fullscreen applications by default
# Uncomment if needed:
# export SDL_VIDEO_FULLSCREEN_HEAD=0
