SUMMARY = "Font converter to generate console fonts from BDF source fonts"
DESCRIPTION = "A command-line converter that can be used to build console fonts from \
BDF sources automatically. The converter comes with a collection of font encodings \
that cover many of the world's languages. When the source font does not define a \
glyph for a particular symbol in the encoding table, that glyph position in the \
console font is not wasted but used for another symbol."

HOMEPAGE = "https://salsa.debian.org/installer-team/console-setup"
SECTION = "utils"
LICENSE = "GPL-2.0-or-later & MIT"
LIC_FILES_CHKSUM = "file://debian/copyright;md5=6fdba635ca4be614fab872320fcb2220"

SRC_URI = "${DEBIAN_MIRROR}/main/c/console-setup/console-setup_${PV}.tar.xz"
SRC_URI[sha256sum] = "d935d6b51b882332276db290b3ef7d1ffa43f7901d5c7998707b3357c8717e20"

S = "${WORKDIR}/work"

inherit allarch

DEPENDS = "perl-native"
RDEPENDS:${PN} = "perl"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    # Install bdf2psf script
    install -d ${D}${bindir}
    install -m 0755 ${S}/Fonts/bdf2psf ${D}${bindir}/bdf2psf
    
    # Install support files (encodings, equivalents, sets)
    install -d ${D}${datadir}/bdf2psf
    cp -r ${S}/Fonts/fontsets ${D}${datadir}/bdf2psf/
    cp -r ${S}/Fonts/charmaps ${D}${datadir}/bdf2psf/
    
    # Install man page
    install -d ${D}${mandir}/man1
    install -m 0644 ${S}/man/bdf2psf.1 ${D}${mandir}/man1/
}

FILES:${PN} = "${bindir}/bdf2psf ${datadir}/bdf2psf"
FILES:${PN}-doc = "${mandir}"

BBCLASSEXTEND = "native nativesdk"
