SUMMARY = "GLKTerm is an interpreter for interactive fiction games on the console"
DESCRIPTION = "GLKTerm provides a unified interface for running various text adventure games \
and supports multiple interpreter engines for different game formats."
HOMEPAGE = "https://github.com/benklop/glkterm"
SECTION = "games"

# License information
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=78e4545921c790f53f837dd922313bbb"

# Source from git repository (live version)
SRC_URI = "git://github.com/benklop/glkterm.git;protocol=https;branch=main"
SRCREV = "${AUTOREV}"

# Version (git live version)
PV = "1.0+git${SRCPV}"

# Working directory
S = "${WORKDIR}/git"

# Build system
inherit cmake pkgconfig

# Build dependencies
DEPENDS = "ncurses \
           zlib \
           libsdl2 \
           libsdl2-mixer \
           pkgconfig-native \
           cmake-native"

# Runtime dependencies
RDEPENDS:${PN} = "ncurses \
                  zlib \
                  libsdl2 \
                  libsdl2-mixer"

# Package configuration options (equivalent to Gentoo USE flags)
PACKAGECONFIG ??= "advsys agility alan2 alan3 bocfel glulxe git hugo jacl level9 magnetic plus scare scott tads taylor"

PACKAGECONFIG[advsys] = "-DWITH_ADVSYS=ON,-DWITH_ADVSYS=OFF"
PACKAGECONFIG[agility] = "-DWITH_AGILITY=ON,-DWITH_AGILITY=OFF"
PACKAGECONFIG[alan2] = "-DWITH_ALAN2=ON,-DWITH_ALAN2=OFF"
PACKAGECONFIG[alan3] = "-DWITH_ALAN3=ON,-DWITH_ALAN3=OFF"
PACKAGECONFIG[bocfel] = "-DWITH_BOCFEL=ON,-DWITH_BOCFEL=OFF"
PACKAGECONFIG[glulxe] = "-DWITH_GLULXE=ON,-DWITH_GLULXE=OFF"
PACKAGECONFIG[git] = "-DWITH_GIT=ON,-DWITH_GIT=OFF"
PACKAGECONFIG[hugo] = "-DWITH_HUGO=ON,-DWITH_HUGO=OFF"
PACKAGECONFIG[jacl] = "-DWITH_JACL=ON,-DWITH_JACL=OFF"
PACKAGECONFIG[level9] = "-DWITH_LEVEL9=ON,-DWITH_LEVEL9=OFF"
PACKAGECONFIG[magnetic] = "-DWITH_MAGNETIC=ON,-DWITH_MAGNETIC=OFF"
PACKAGECONFIG[plus] = "-DWITH_PLUS=ON,-DWITH_PLUS=OFF"
PACKAGECONFIG[scare] = "-DWITH_SCARE=ON,-DWITH_SCARE=OFF"
PACKAGECONFIG[scott] = "-DWITH_SCOTT=ON,-DWITH_SCOTT=OFF"
PACKAGECONFIG[tads] = "-DWITH_TADS=ON,-DWITH_TADS=OFF"
PACKAGECONFIG[taylor] = "-DWITH_TAYLOR=ON,-DWITH_TAYLOR=OFF"

# Extra CMake arguments
EXTRA_OECMAKE = ""

# Remove problematic build-path files
do_install:append() {
    # Remove Make.glkterm which contains build paths
    rm -f ${D}${includedir}/Make.glkterm
}

# Package files
FILES:${PN} = "${bindir}/* \
               ${datadir}/${PN}/* \
               ${libdir}/${PN}/*"

# Development files (if any)
FILES:${PN}-dev = "${includedir}/* \
                   ${libdir}/pkgconfig/* \
                   ${libdir}/*.so \
                   ${libdir}/cmake/*"

# Documentation files
FILES:${PN}-doc = "${docdir}/* \
                   ${mandir}/*"