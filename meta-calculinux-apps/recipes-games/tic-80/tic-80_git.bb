SUMMARY = "TIC-80 fantasy computer"
DESCRIPTION = "TIC-80 is a fantasy computer for making, playing and sharing tiny games. \
It has built-in tools for code, sprites, maps, sound editors and the command line, \
which is enough to create a mini retro game."
HOMEPAGE = "https://tic80.com/"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=a954a69f40fac61a7a00097f2be76f8e"

inherit cmake pkgconfig

PV = "1.3.1"
SRC_URI = "gitsm://github.com/nesbox/TIC-80.git;protocol=https;branch=main"
# v1.3.1, the current upstream release: unlike 1.3.x builds of main, its
# desktop still defaults to the SDL system layer, so -DBUILD_SDL=ON
# configures cleanly (main flipped the default to the sokol layer, which
# FATAL_ERRORs when SDL is also requested). The unpacked tree keeps its git
# metadata, and cmake/version.cmake stamps a build whose HEAD exactly matches
# a tag as that release - the fetcher's checkout carries the v1.3.1 tag, so
# the app identifies as the 1.3.1 release (production asset site) rather
# than a 1.3 dev snapshot.
SRCREV = "62c24e5c9271f1445f61120b7d204805ff9db912"
S = "${WORKDIR}/git"

DEPENDS = "\
    libsdl2 \
    zlib \
    curl \
"

# TIC-80 supports multiple build configurations
# For PicoCalc, we build without X11 but with SDL2
# TIC-80 requires many vendored dependencies so we don't use system libraries
# BUILD_DEMO_CARTS no longer exists: the demo carts ship pre-generated as
# .dat assets in the source tree. BUILD_SURF (new in the 1.2 line, on by
# default) adds the online cart browser (surf); kept on - its traffic goes
# through net.c and the bundled naett client, both already covered by the
# curl dependency above.
EXTRA_OECMAKE = "\
    -DBUILD_SDL=ON \
    -DBUILD_SDLGPU=OFF \
    -DBUILD_LIBRETRO=OFF \
    -DBUILD_PRO=ON \
    -DPREFER_SYSTEM_LIBRARIES=ON \
"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/bin/tic80 ${D}${bindir}/tic80
}

FILES:${PN} = "${bindir}/tic80"

COMPATIBLE_MACHINE = "luckfox-lyra"
