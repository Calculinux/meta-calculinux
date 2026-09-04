SUMMARY = "Ncurses system configuration utility for Calculinux"
DESCRIPTION = "Small-screen TUI for enabling overlays, LEDs, USB gadget, \
console fonts, hostname/users/timezone, and launching uwific/cup. \
Designed for PicoCalc 320x320 displays."
HOMEPAGE = "https://github.com/Calculinux/calculinux-config"
SECTION = "console/utils"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0c1ca00017fe02adea99b8b709ff179b"

SRC_URI = "git://github.com/Calculinux/calculinux-config.git;protocol=https;branch=main"
SRCREV = "0e5298f7e6658219362e76f63c3d66a0178bdc06"
PV = "1.0+git${SRCPV}"

S = "${WORKDIR}/git"

inherit pkgconfig systemd

DEPENDS = "ncurses"

EXTRA_OEMAKE = "\
    CC='${CC}' \
    CFLAGS='${CFLAGS} `pkg-config --cflags ncurses`' \
    LIBS='${LDFLAGS} `pkg-config --libs ncurses`' \
    PREFIX=${prefix} \
    SYSTEMD_DIR=${systemd_system_unitdir} \
"

do_compile() {
    oe_runmake
}

do_install() {
    oe_runmake install DESTDIR=${D} PREFIX=${prefix}
}

SYSTEMD_SERVICE:${PN} = "calculinux-leds.service"
SYSTEMD_AUTO_ENABLE = "enable"

RDEPENDS:${PN} = "ncurses systemd shadow tzdata"

CONFFILES:${PN} = "${sysconfdir}/default/leds"

FILES:${PN} += "\
    ${bindir}/calculinux-config \
    ${bindir}/ccfg \
    ${sbindir}/calculinux-leds \
    ${sysconfdir}/default/leds \
    ${systemd_system_unitdir}/calculinux-leds.service \
"
