SUMMARY = "Terminus console font"
DESCRIPTION = "Monospaced font designed for long (8+ hours per day) work with computers. Contains 1326 characters, supports about 120 language sets, many IBM, Windows and Macintosh code pages, IBM VGA / vt100 / xterm pseudographic characters and Esperanto."

LICENSE = "OFL-1.1"
LIC_FILES_CHKSUM = "file://OFL.TXT;md5=f57e6cca943dbc6ef83dc14f1855bdcc"

SRC_URI = "https://download.sourceforge.net/${BPN}/${BPN}-${PV}.tar.gz"
SRC_URI[sha256sum] = "d961c1b781627bf417f9b340693d64fc219e0113ad3a3af1a3424c7aa373ef79"

DEPENDS = "bdftopcf-native"
RDEPENDS:${PN} = "console-tools"

do_configure () {
    ${S}/configure --prefix=${prefix}
}

do_compile () {
    oe_runmake psf
}

do_install () {
    # This is a guess; additional arguments may be required
    oe_runmake install-psf DESTDIR=${D}
}

FILES:${PN} = "${datadir}/consolefonts/"
