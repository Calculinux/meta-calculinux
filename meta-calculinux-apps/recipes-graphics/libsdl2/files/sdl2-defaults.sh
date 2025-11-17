# SDL2 default configuration for PicoCalc/Calculinux
# Sets SDL to use KMS/DRM video driver by default

# Set XDG_RUNTIME_DIR if not already set (required for DRM/KMS)
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR=/tmp/runtime-$(id -u)
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi

# Use KMSDRM video driver for direct rendering to DRM/KMS displays
export SDL_VIDEODRIVER=kmsdrm

# Use software rendering backend by default
export SDL_RENDER_DRIVER=software

# Disable mouse cursor (useful for touch-only devices)
# Uncomment if needed:
# export SDL_VIDEO_KMSDRM_SHOW_CURSOR=0

# For fullscreen applications by default
# Uncomment if needed:
# export SDL_VIDEO_FULLSCREEN_HEAD=0
