SUMMARY = "Common code base for all Kiwix ports"
DESCRIPTION = "The Kiwix library provides the Kiwix software core. It contains the code \
shared by all Kiwix ports (Windows, Linux, macOS, Android, iOS, etc.)."
HOMEPAGE = "https://github.com/kiwix/libkiwix"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=4c61b8950dc1aab4d2aa7c2ae6b1cfb3"

SRC_URI = "\
    git://github.com/kiwix/libkiwix;protocol=https;branch=main \
    https://raw.githubusercontent.com/kainjow/Mustache/v4.1/mustache.hpp;name=mustache \
    file://0001-fix-mustache-header-check.patch \
    file://0001-add-icu-uc-dependency.patch \
"

SRCREV = "20abebd6237fe5879bf79950a0e620edd620f33a"

SRC_URI[mustache.sha256sum] = "6a07bd8c31be6bb3eae6df98b12f89df8931604bd890e8bba59298a68b89ff29"

S = "${WORKDIR}/git"

DEPENDS = "\
    libzim \
    icu \
    pugixml \
    curl \
    libmicrohttpd \
    zlib \
    cmake \
    xapian-core \
"

inherit meson pkgconfig

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Ensure mustache.hpp is present in the source tree before meson runs
python do_unpack:append() {
    import shutil, os
    os.makedirs(d.getVar('S') + '/include', exist_ok=True)
    shutil.copy(d.getVar('WORKDIR') + '/sources-unpack/mustache.hpp', d.getVar('S') + '/include/mustache.hpp')
}

do_install:append() {
    install -d ${D}${includedir}
    if [ -f ${S}/include/mustache.hpp ]; then
        install -m 0644 ${S}/include/mustache.hpp ${D}${includedir}/
    fi
}

EXTRA_OEMESON = "\
    -Dstatic-linkage=false \
    -Ddoc=false \
"

FILES:${PN} += "${libdir}/*.so.*"
FILES:${PN}-dev += "${libdir}/*.so ${includedir}/*"
