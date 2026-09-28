# SDL for the bundled emulator window (nativesdk-qemu): X11 (tried first)
# and Wayland (used when there is no X server). Software rendering only, so
# the AppImage carries no GL stack. No libdecor, so a native Wayland window
# is undecorated on GNOME; X11/XWayland remains the default there.
PACKAGECONFIG:class-nativesdk = "x11 wayland"

# Link the X11/Wayland client libraries instead of dlopen()ing them, so they
# become package dependencies and land in the AppImage. Leave out KMSDRM and
# the offscreen driver: with no usable display SDL would otherwise "succeed"
# with an invisible window.
EXTRA_OECMAKE:append:class-nativesdk = " \
    -DSDL_X11_SHARED=OFF \
    -DSDL_WAYLAND_SHARED=OFF \
    -DSDL_KMSDRM=OFF \
    -DSDL_OFFSCREEN=OFF \
"

# Linking them records the build sysroot in the -dev files.
do_install:append:class-nativesdk() {
    sed -i -e 's|${RECIPE_SYSROOT}||g' \
        ${D}${libdir}/pkgconfig/sdl2.pc \
        ${D}${libdir}/cmake/SDL2/SDL2staticTargets.cmake
}
