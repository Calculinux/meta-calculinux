SUMMARY = "SDL 1.2 API implemented on top of SDL 2"
DESCRIPTION = "sdl12-compat is a drop-in replacement for SDL 1.2 (libSDL-1.2.so.0, \
headers, sdl.pc) that runs on SDL 2. On Calculinux this gives SDL 1.2 apps the \
kmsdrm display path and evdev keyboard handling of libsdl2: they draw to their \
own buffer instead of sharing /dev/fb0 with the terminal, need no kernel VT, \
and modes larger than the panel are scaled down to fit."
HOMEPAGE = "https://github.com/libsdl-org/sdl12-compat"
BUGTRACKER = "https://github.com/libsdl-org/sdl12-compat/issues"
SECTION = "libs"

LICENSE = "Zlib"
LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=f81f7fb6803c844def5c392f71c28dcd"

SRC_URI = "git://github.com/libsdl-org/sdl12-compat.git;protocol=https;branch=main \
           file://0001-map-sdl12-console-video-drivers-to-sdl2-default.patch \
           "
# release-1.2.78
SRCREV = "07043bdcfd0d16ea8f14fe2a375089d00566a5e9"

S = "${WORKDIR}/git"

# Only SDL 2's headers are needed to build; the library is dlopen()ed at
# runtime, so shlibdeps doesn't see it.
DEPENDS = "libsdl2"
RDEPENDS:${PN} = "libsdl2"

# Stands in for meta-oe's libsdl (see PREFERRED_PROVIDER_libsdl in the distro
# config), so recipes keep depending on "libsdl".
PROVIDES = "libsdl"
RPROVIDES:${PN} = "libsdl"
RPROVIDES:${PN}-dev = "libsdl-dev"

BINCONFIG = "${bindir}/sdl-config"

inherit cmake pkgconfig lib_package binconfig-disabled

EXTRA_OECMAKE = "-DSDL12TESTS=OFF"

do_install:append() {
    # Only sdl12_compat.pc is installed; it "Provides: sdl", which pkg-config
    # doesn't resolve when asked for sdl by name.
    ln -sf sdl12_compat.pc ${D}${libdir}/pkgconfig/sdl.pc
}
