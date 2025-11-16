#!/bin/bash
# SDL2 DRM Diagnostic Script

echo "=== SDL2 DRM Diagnostic ==="
echo

echo "1. Checking SDL2 library and video drivers:"
if command -v sdl2-config &> /dev/null; then
    echo "SDL2 config found:"
    sdl2-config --version
    sdl2-config --cflags
    sdl2-config --libs
else
    echo "sdl2-config not found"
fi
echo

echo "2. Checking for libSDL2:"
find /usr/lib* -name "libSDL2*.so*" 2>/dev/null
echo

echo "3. Checking DRM/KMS devices:"
ls -la /dev/dri/ 2>/dev/null || echo "/dev/dri/ not found"
echo

echo "4. Checking for DRM modules:"
lsmod | grep drm || echo "No DRM modules loaded"
echo

echo "5. Checking framebuffer devices:"
ls -la /dev/fb* 2>/dev/null || echo "No framebuffer devices found"
echo

echo "6. Testing SDL2 video drivers (requires sdl2-test or similar):"
if [ -f /usr/bin/sdl2-test ]; then
    echo "Available via SDL test app - run sdl2-test for details"
else
    echo "sdl2-test not found"
fi
echo

echo "7. Checking DRM card info:"
if [ -e /dev/dri/card0 ]; then
    cat /sys/class/drm/card0/device/uevent 2>/dev/null || echo "Cannot read card0 info"
    echo "DRM card0 connectors:"
    ls -la /sys/class/drm/card0*/status 2>/dev/null
else
    echo "/dev/dri/card0 not found"
fi
echo

echo "8. Checking permissions:"
ls -la /dev/dri/ 2>/dev/null
echo "Current user: $(whoami)"
echo "User groups: $(groups)"
echo

echo "9. Environment variables:"
echo "SDL_VIDEODRIVER=${SDL_VIDEODRIVER:-<not set>}"
echo "SDL_VIDEO_KMSDRM_SHOW_CURSOR=${SDL_VIDEO_KMSDRM_SHOW_CURSOR:-<not set>}"
