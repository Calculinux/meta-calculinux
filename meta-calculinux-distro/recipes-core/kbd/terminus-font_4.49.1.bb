SUMMARY = "Terminus console font"
DESCRIPTION = "Monospaced font designed for long (8+ hours per day) work with computers. \
Contains 1326 characters, supports about 120 language sets, many IBM, Windows and Macintosh \
code pages, IBM VGA / vt100 / xterm pseudographic characters and Esperanto. \
The PSF fonts include Unicode mapping tables for proper character coverage."

LICENSE = "OFL-1.1"
LIC_FILES_CHKSUM = "file://OFL.TXT;md5=f57e6cca943dbc6ef83dc14f1855bdcc"

SRC_URI = "https://download.sourceforge.net/${BPN}/${BPN}-${PV}.tar.gz"
SRC_URI[sha256sum] = "d961c1b781627bf417f9b340693d64fc219e0113ad3a3af1a3424c7aa373ef79"

DEPENDS = "bdftopcf-native"
RDEPENDS:${PN} = "console-tools"

do_configure () {
    # Configure terminus to build PSF fonts with Unicode mapping tables
    ${S}/configure --prefix=${prefix} --psfdir=${datadir}/consolefonts
}

do_compile () {
    # Build PSF fonts - these automatically include Unicode mapping tables
    # The ter-vXXn variants have particularly good Unicode codepoint mapping
    oe_runmake psf
}

do_install () {
    # Install PSF fonts with Unicode mappings to /usr/share/consolefonts
    oe_runmake install-psf DESTDIR=${D}
}

FILES:${PN} = "${datadir}/consolefonts/"
