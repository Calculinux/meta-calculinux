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

SRC_URI = "git://salsa.debian.org/installer-team/console-setup;protocol=https;branch=master;tag=${PV}"

S = "${WORKDIR}/git"

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
    
    # Install equivalents and set files directly
    install -m 0644 ${S}/Fonts/*.equivalents ${D}${datadir}/bdf2psf/ || true
    install -m 0644 ${S}/Fonts/*.set ${D}${datadir}/bdf2psf/ || true
    
    # Install man page
    install -d ${D}${mandir}/man1
    install -m 0644 ${S}/man/bdf2psf.1 ${D}${mandir}/man1/
}

FILES:${PN} = "${bindir}/bdf2psf ${datadir}/bdf2psf"
FILES:${PN}-doc = "${mandir}"

BBCLASSEXTEND = "native nativesdk"
