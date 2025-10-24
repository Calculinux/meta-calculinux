SUMMARY = "Reference implementation of the ZIM specification"
DESCRIPTION = "The ZIM library is the reference implementation for the ZIM file \
format. It's a software library to read and write ZIM files on many systems \
and architectures."
HOMEPAGE = "https://github.com/openzim/libzim"
LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=3d49fb732c80149332a79a8bfaf1f448"

SRC_URI = "git://github.com/openzim/libzim;protocol=https;branch=main"
SRCREV = "bb62cbc5d3f2c3ba11e1ced6f5e0e65c2c6ebf8e"

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
