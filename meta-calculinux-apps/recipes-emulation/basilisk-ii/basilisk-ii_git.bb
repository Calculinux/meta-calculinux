DESCRIPTION = "Basilisk II — 680x0 Apple Macintosh emulator (build from macemu)"
HOMEPAGE = "https://github.com/kanjitalk755/macemu"
SECTION = "emulator"
LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://BasiliskII/COPYING;md5=0636e73ff0215e8d672dc4c32c317bb3"

PN = "basilisk-ii"
PV = "1.0+git${SRCPV}"

SRC_URI = "git://github.com/kanjitalk755/macemu;protocol=https;branch=master \
           file://0002-fix-configure-for-cross-compilation.patch \
           file://0003-fix-register-keyword.patch \
           file://0004-fix-sscanf-format.patch \
           file://0005-fix-makefile-for-cross-compilation.patch \
        "
SRCREV = "ac3273276215ffb3d0e40c8ed2e86f60882ec04d"

# The macemu repository contains multiple emulators. Basilisk II's Unix port
# lives in 'BasiliskII/src/Unix' in this upstream repo — set S to the git root
# so patches can be applied to files in different subdirectories.
S = "${WORKDIR}/git"

DEPENDS = "libsdl2 libpng jpeg zlib alsa-lib gmp mpfr autoconf-native automake-native libtool-native pkgconfig-native"
HOSTTOOLS += "gcc g++"

EXTRA_OECONF = "--disable-x11 --enable-sdl-video --enable-sdl-sound --disable-macosx-gui --disable-macosx-sound"

inherit pkgconfig

BB_NO_NETWORK = "0"

do_configure() {
    bbnote "Configuring Basilisk II"
    cd ${S}/BasiliskII/src/Unix

    if [ -x "autogen.sh" ]; then
        bbnote "Running autogen.sh to generate configure"
        NO_CONFIGURE=true ./autogen.sh

        export ac_cv_tun_tap_support=yes
        export ac_cv_type_socklen_t=yes
        export ac_cv_c_float_format='IEEE (little-endian)'
        export ac_cv_gcc_mdynamic_no_pic=no
        export ac_cv_have_extended_signals=yes
        export SDL_CFLAGS="`pkg-config --cflags sdl2`"
        export SDL_LIBS="`pkg-config --libs sdl2`"

        ./configure --host=${TARGET_SYS} --build=${BUILD_SYS} --prefix=${prefix} ${EXTRA_OECONF}
    else
        bbnote "No autogen.sh script found; skipping configure step"
    fi
}

do_configure:append() {
    # Strip macOS-specific frameworks that break cross-linking on Linux
    for framework in AppKit Carbon IOKit CoreFoundation Metal; do
        sed -i "s/ -framework ${framework}//g" ${S}/BasiliskII/src/Unix/Makefile
    done
}

do_compile() {
    bbnote "Compiling Basilisk II"
    cd ${S}/BasiliskII/src/Unix
    oe_runmake
}

do_install() {
    bbnote "Installing Basilisk II binary"
    install -d ${D}${bindir}
    install -m 0755 ${S}/BasiliskII/src/Unix/BasiliskII ${D}${bindir}/basilisk-ii
}

FILES_${PN} = "${bindir}/basilisk-ii"

RDEPENDS_${PN} = ""
