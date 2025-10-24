SUMMARY = "Common code base for all Kiwix ports"
DESCRIPTION = "The Kiwix library provides the Kiwix software core. It contains the code \
shared by all Kiwix ports (Windows, Linux, macOS, Android, iOS, etc.)."
HOMEPAGE = "https://github.com/kiwix/libkiwix"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=d32239bcb673463ab874e80d47fae504"

SRC_URI = "\
    git://github.com/kiwix/libkiwix;protocol=https;branch=main \
    https://raw.githubusercontent.com/kainjow/Mustache/v4.1/mustache.hpp;name=mustache;subdir=git \
"
SRCREV = "0a5c5c13d2ba51a7e4c3cf0e3bc1e7c3e9b8f8f8"
SRC_URI[mustache.sha256sum] = "e18d8f98cd3d4e0e5b8e1c6b8a5f3e5c3e3e3f3e3e3e3f3e3e3e3f3e3e3e3f3e"

S = "${WORKDIR}/git"

DEPENDS = "\
    libzim \
    icu \
    pugixml \
    curl \
    libmicrohttpd \
    zlib \
"

inherit meson pkgconfig

# Download mustache.hpp header
do_configure:prepend() {
    if [ -f ${WORKDIR}/mustache.hpp ]; then
        cp ${WORKDIR}/mustache.hpp ${S}/
    fi
}

EXTRA_OEMESON = "\
    -Dstatic-linkage=false \
    -Ddoc=false \
"

FILES:${PN} += "${libdir}/*.so.*"
FILES:${PN}-dev += "${libdir}/*.so ${includedir}/*"
