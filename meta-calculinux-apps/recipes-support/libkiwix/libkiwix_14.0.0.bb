SUMMARY = "Common code base for all Kiwix ports"
DESCRIPTION = "The Kiwix library provides the Kiwix software core. It contains the code \
shared by all Kiwix ports (Windows, Linux, macOS, Android, iOS, etc.)."
HOMEPAGE = "https://github.com/kiwix/libkiwix"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=4c61b8950dc1aab4d2aa7c2ae6b1cfb3"

SRC_URI = "\
    git://github.com/kiwix/libkiwix;protocol=https;branch=main \
    https://raw.githubusercontent.com/kainjow/Mustache/v4.1/mustache.hpp \
"

SRCREV = "20abebd6237fe5879bf79950a0e620edd620f33a"

SRC_URI[sha256sum] = "6a07bd8c31be6bb3eae6df98b12f89df8931604bd890e8bba59298a68b89ff29"
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
