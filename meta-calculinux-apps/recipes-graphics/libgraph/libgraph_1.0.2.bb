SUMMARY = "Turbo C graphics.h implementation for Linux using SDL"
DESCRIPTION = "LibGraph is an implementation of the TurboC graphics API (graphics.h) \
on GNU/Linux using SDL (Simple DirectMedia Layer). It enables programs written \
using Turbo C graphics.h functions to run directly on Linux with minimal changes."
HOMEPAGE = "https://savannah.nongnu.org/projects/libgraph/"
LICENSE = "LGPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=f30a9716ef3762e3467a2f62bf790f0a"

# Needed so Yocto finds the patch files in the files/ subdirectory alongside this recipe
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = "https://download.savannah.nongnu.org/releases/libgraph/libgraph-${PV}.tar.gz \
           file://0001-fix-deprecated-autoconf-macros.patch \
           file://0002-fix-gcc14-implicit-declarations-and-pointer-types.patch \
           file://0003-automatic-quit.patch \
"
SRC_URI[sha256sum] = "0bacaab6dd6f54446a6c4e203167011cb18b23f83c665cdabca48ffc40c6536e"

S = "${WORKDIR}/${BP}"

# SDL 1.2 provides the graphics backend; SDL_image provides font/image loading
DEPENDS = "libsdl libsdl-image"

inherit autotools pkgconfig

# Guile scripting support is optional and out of scope here;
# disabling it avoids a build-time dependency on guile-config.
EXTRA_OECONF = "\
    --disable-guile \
    --enable-pkgconfig \
"

# The library's headers define global variables (screen, CP, InternalFont, etc.)
# rather than using extern declarations, so multiple .o files each contain a
# definition of those symbols. GCC 10+ defaults to -fno-common which treats
# these as hard errors at link time; -fcommon restores the original behaviour of
# merging uninitialized global definitions as BSS common symbols.
TARGET_CFLAGS:append = " -fcommon"

# Override FILES:${PN} to list only what this library actually installs at runtime:
#   libgraph.so.*        - versioned shared library
#   ${datadir}/libgraph/ - bitmap fonts and HTML docs used at runtime
#   grc                  - convenience shell script wrapper for gcc -lgraph
# The default FILES:${PN}-dev (headers, unversioned .so symlink, .la) is preserved
# via +=; only the pkgconfig dir is appended since it is already in the default.
FILES:${PN} = "\
    ${libdir}/libgraph.so.* \
    ${datadir}/libgraph/ \
    ${bindir}/grc \
"
FILES:${PN}-dev += "\
    ${libdir}/pkgconfig/ \
"
