SUMMARY = "Terminus console font (PSF)"
DESCRIPTION = "Optional kernel fbcon / setfont Terminus PSF fonts. Not part of the \
default image — install via opkg when using CONSOLE=kernel and wanting a \
userspace-loadable font (e.g. FONT=ter-u12n.psf.gz in /etc/vconsole.conf). \
Cruft Unicode fonts are separate (.cruftfont via console-font / miniwi / unifont)."

LICENSE = "OFL-1.1"
LIC_FILES_CHKSUM = "file://OFL.TXT;md5=f57e6cca943dbc6ef83dc14f1855bdcc"

SRC_URI = "https://download.sourceforge.net/${BPN}/${BPN}-${PV}.tar.gz"
SRC_URI[sha256sum] = "d961c1b781627bf417f9b340693d64fc219e0113ad3a3af1a3424c7aa373ef79"

DEPENDS = "bdftopcf-native"
# setfont + systemd-vconsole-setup
RDEPENDS:${PN} = "kbd"

do_configure () {
    ${S}/configure --prefix=${prefix} --psfdir=${datadir}/consolefonts
}

do_compile () {
    oe_runmake psf
}

do_install () {
    oe_runmake install-psf DESTDIR=${D}
}

FILES:${PN} = "${datadir}/consolefonts/"
