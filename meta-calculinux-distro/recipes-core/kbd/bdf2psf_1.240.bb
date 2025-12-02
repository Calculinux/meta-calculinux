SUMMARY = "Font converter to generate console fonts from BDF source fonts"
DESCRIPTION = "A command-line converter that can be used to build console fonts from \
BDF sources automatically. The converter comes with a collection of font encodings \
that cover many of the world's languages. When the source font does not define a \
glyph for a particular symbol in the encoding table, that glyph position in the \
console font is not wasted but used for another symbol."

HOMEPAGE = "https://salsa.debian.org/installer-team/console-setup"
SECTION = "utils"
LICENSE = "GPL-2.0-or-later & MIT"
LIC_FILES_CHKSUM = "file://COPYRIGHT;md5=49cab1cfd397b014807c5b2bcc63e04f"

SRC_URI = "${DEBIAN_MIRROR}/main/c/console-setup/console-setup_${PV}.tar.xz"
SRC_URI[sha256sum] = "ce9e9a7bd59e7d54c00d20628fa08b879efa7bfc25fd39c406683a6d6c09e49c"

S = "${WORKDIR}/console-setup"

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
    install -m 0644 ${S}/Fonts/*.equivalents ${D}${datadir}/bdf2psf/
    install -m 0644 ${S}/Fonts/*.set ${D}${datadir}/bdf2psf/
    
    # Install man page
    install -d ${D}${mandir}/man1
    install -m 0644 ${S}/man/bdf2psf.1 ${D}${mandir}/man1/
}

FILES:${PN} = "${bindir}/bdf2psf ${datadir}/bdf2psf"
FILES:${PN}-doc = "${mandir}"

BBCLASSEXTEND = "native nativesdk"
