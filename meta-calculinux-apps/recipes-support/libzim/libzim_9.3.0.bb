SUMMARY = "Reference implementation of the ZIM specification"
DESCRIPTION = "The ZIM library is the reference implementation for the ZIM file \
format. It's a software library to read and write ZIM files on many systems \
and architectures."
HOMEPAGE = "https://github.com/openzim/libzim"
LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=00f62fee8056dc37ed6566f4ab3ddf2a"

SRC_URI = "git://github.com/openzim/libzim;protocol=https;branch=main"
SRCREV = "f421088da622c3a1e0fc6a6ced737b10d4fa5502"

S = "${WORKDIR}/git"

DEPENDS = "xz zstd"

inherit meson pkgconfig

EXTRA_OEMESON = "\
    -Dstatic-linkage=false \
    -Dtests=false \
    -Dexamples=false \
    -Ddoc=false \
    -Dwith_xapian=false \
"

FILES:${PN} += "${libdir}/*.so.*"
FILES:${PN}-dev += "${libdir}/*.so ${includedir}/*"
