SUMMARY = "TUI WiFi manager for iwd"
DESCRIPTION = "A small-screen TUI WiFi client that talks to iwd over D-Bus. \
Scans, connects, disconnects, and forgets networks using ncurses. Designed \
for Calculinux on PicoCalc-class devices."
HOMEPAGE = "https://github.com/RealBusinessAccount/uwific"
SECTION = "console/network"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=574efe748ed4af8e3c587194e64d9ea8"

SRC_URI = "git://github.com/RealBusinessAccount/uwific.git;protocol=https;branch=main"
SRCREV = "961bc1dd0358f61aadd7ca6a0a5f76b9856ce80d"

PV = "1.0+git${SRCPV}"

inherit pkgconfig

DEPENDS = "systemd ncurses"

EXTRA_OEMAKE = "\
    CC='${CC}' \
    CFLAGS='${CFLAGS} `pkg-config --cflags libsystemd ncurses`' \
    LIBS='${LDFLAGS} `pkg-config --libs libsystemd ncurses`' \
    PREFIX=${prefix} \
"

do_compile() {
    oe_runmake
}

do_install() {
    oe_runmake install DESTDIR=${D} PREFIX=${prefix}
}

RDEPENDS:${PN} = "iwd"
