SUMMARY = "Collection of Kiwix command line tools"
DESCRIPTION = "Kiwix tools is a collection of Kiwix related command line tools: \
kiwix-manage (manage XML based library of ZIM files), kiwix-search (full text \
search in ZIM files), and kiwix-serve (HTTP daemon serving ZIM files)."
HOMEPAGE = "https://github.com/kiwix/kiwix-tools"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=d32239bcb673463ab874e80d47fae504"

SRC_URI = "git://github.com/kiwix/kiwix-tools;protocol=https;branch=main"
SRCREV = "acad8a85ab4706ff527cabdaac4635a930f3bdd4"

S = "${WORKDIR}/git"

DEPENDS = "\
    libzim \
    libkiwix \
    docopt.cpp \
"

inherit meson pkgconfig

EXTRA_OEMESON = "\
    -Dstatic-linkage=false \
    -Ddoc=false \
"

FILES:${PN} += "${bindir}/*"

RDEPENDS:${PN} = "libzim libkiwix"
