SUMMARY = "Xapian is an Open Source Search Engine Library"
HOMEPAGE = "http://xapian.org/"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=4325afd396febcb659c36b49533135d4"

PV = "1.4.21"
SRC_URI = "http://oligarchy.co.uk/xapian/${PV}/${BPN}-${PV}.tar.xz"
SRC_URI[sha256sum] = "80f86034d2fb55900795481dfae681bfaa10efbe818abad3622cdc0c55e06f88"

inherit autotools cmake_lib

DEPENDS = "util-linux zlib"

FILES:${PN}-dev += "${libdir}/cmake"

CMAKE_ALIGN_SYSROOT[1] = "xapian, -S${libdir}, -s${OE_QMAKE_PATH_HOST_LIBS}/"