#!/bin/bash
# SDL2 KMS/DRM Diagnostic Script

echo "=== SDL2 KMS/DRM Diagnostic ==="
echo

echo "1. Checking DRM devices:"
ls -l /dev/dri/ 2>/dev/null || echo "  No /dev/dri directory found!"
echo

echo "2. Current user and groups:"
id
echo

echo "3. SDL2 Environment Variables:"
env | grep SDL || echo "  No SDL variables set"
echo

echo "4. Checking for video/render group membership:"
groups | grep -E 'video|render' && echo "  ✓ User is in video/render group" || echo "  ✗ User is NOT in video/render group"
echo

echo "5. Testing DRM device access:"
if [ -c /dev/dri/card0 ]; then
    echo "  /dev/dri/card0 exists"
    [ -r /dev/dri/card0 ] && echo "  ✓ Readable" || echo "  ✗ Not readable"
    [ -w /dev/dri/card0 ] && echo "  ✓ Writable" || echo "  ✗ Not writable"
else
    echo "  ✗ /dev/dri/card0 not found"
fi
echo

echo "6. Loaded DRM/KMS modules:"
lsmod | grep -E 'drm|rockchip' || echo "  No DRM modules found"
echo

echo "7. Checking libdrm and libgbm:"
ldconfig -p | grep -E 'libdrm|libgbm' || echo "  Libraries not found in cache"
echo

echo "8. Checking SDL2 library for kmsdrm symbols:"
if command -v strings >/dev/null 2>&1; then
    SDL_LIB=$(ldconfig -p | grep libSDL2 | awk '{print $NF}' | head -1)
    if [ -n "$SDL_LIB" ]; then
        echo "  SDL2 library: $SDL_LIB"
        strings "$SDL_LIB" | grep -i kmsdrm | head -5 || echo "  No kmsdrm strings found"
    fi
else
    echo "  strings command not available"
fi
echo

echo "9. Running SDL2 driver enumeration test..."
if command -v sdl2-test >/dev/null 2>&1; then
    # Run without SDL_VIDEODRIVER set to see all available drivers
    unset SDL_VIDEODRIVER
    timeout 2 sdl2-test 2>&1 | head -30 || echo "  Test timed out or failed"
else
    echo "  sdl2-test not found"
fi
