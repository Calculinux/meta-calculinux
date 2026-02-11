SUMMARY = "TIC-80 fantasy computer"
DESCRIPTION = "TIC-80 is a fantasy computer for making, playing and sharing tiny games. \
It has built-in tools for code, sprites, maps, sound editors and the command line, \
which is enough to create a mini retro game."
HOMEPAGE = "https://tic80.com/"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=a954a69f40fac61a7a00097f2be76f8e"

inherit cmake pkgconfig

PV = "1.1.2837"
SRC_URI = "gitsm://github.com/nesbox/TIC-80.git;protocol=https;branch=main"
SRCREV = "${AUTOREV}"
S = "${WORKDIR}/git"

DEPENDS = "\
    libsdl2 \
    zlib \
    curl \
"

# TIC-80 supports multiple build configurations
# For PicoCalc, we build without X11 but with SDL2
# TIC-80 requires many vendored dependencies so we don't use system libraries
EXTRA_OECMAKE = "\
    -DBUILD_SDL=ON \
    -DBUILD_SDLGPU=OFF \
    -DBUILD_LIBRETRO=OFF \
    -DBUILD_DEMO_CARTS=ON \
    -DBUILD_PRO=ON \
    -DPREFER_SYSTEM_LIBRARIES=ON \
"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/bin/tic80 ${D}${bindir}/tic80
}

FILES:${PN} = "${bindir}/tic80"

COMPATIBLE_MACHINE = "luckfox-lyra"
