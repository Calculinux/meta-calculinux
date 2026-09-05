SUMMARY = "Calculinux RedUced Footprint Terminal"
DESCRIPTION = "Linux framebuffer VT terminal for Calculinux (PicoCalc / Luckfox Lyra). \
Uses demand-paged .cruftfont blobs with runtime cell metrics (4x8 miniwi, \
6x12 default, 8x16 Unifont), sparse sixel cell storage, and lazy DRCS. \
Font is selected via CONSOLE_FONT in /etc/default/console (or CRUFT_FONT). \
Opens the kernel framebuffer already set up by TinyDRM/fbcon. Local VTs \
are wired via a systemd generator (CONSOLE=cruft|kernel)."

HOMEPAGE = "https://github.com/Calculinux/cruft"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0a1f0030369f9d1f26870e0bfc24c47b"

SRC_URI = "git://github.com/Calculinux/cruft.git;protocol=https;branch=main \
           file://cruft@.service \
           file://cruft-budget-check.sh \
           file://console.default \
           file://cruft-generator \
           file://console-mode \
           "
SRCREV = "d4a83c30caa33de9c11f145a8fe362ee025ea4c1"
PV = "0.1.0+git${SRCPV}"

DEPENDS = "ncurses-native"
RDEPENDS:${PN} = "console-font"
RRECOMMENDS:${PN} = "miniwi-console unifont-console"
RPROVIDES:${PN} = "yaft"
RREPLACES:${PN} = "yaft"
RCONFLICTS:${PN} = "yaft"

inherit systemd

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

EXTRA_OEMAKE = "CC='${CC}' \
    CFLAGS='${CFLAGS} -std=c99 -D_XOPEN_SOURCE=600' \
    LDFLAGS='${LDFLAGS}' \
    PREFIX='${D}${prefix}' \
    MANPREFIX='${D}${mandir}' \
"

do_configure[noexec] = "1"

do_compile() {
    oe_runmake cruft

    # Host-side selftests (cross target binary is not runnable here).
    ${BUILD_CC} ${BUILD_CFLAGS} ${BUILD_LDFLAGS} -std=c99 -O0 -g -I${S} \
        -o ${WORKDIR}/cruft-selftest \
        ${S}/tests/selftest.c ${S}/cell_pixmap.c ${S}/drcs.c \
        ${S}/sixel_canvas.c ${S}/glyph_mmap.c ${S}/terminal_cell.c
    ${WORKDIR}/cruft-selftest

    ${BUILD_CC} ${BUILD_CFLAGS} ${BUILD_LDFLAGS} -std=c99 -O2 \
        -o ${WORKDIR}/mkcruftfont ${S}/tools/mkcruftfont.c
    ${WORKDIR}/mkcruftfont --self-check
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/cruft ${D}${bindir}/cruft

    install -m 0755 ${UNPACKDIR}/cruft-budget-check.sh ${D}${bindir}/cruft-budget-check
    install -m 0755 ${UNPACKDIR}/console-mode ${D}${bindir}/console-mode

    install -d ${D}${datadir}/terminfo
    tic -o ${D}${datadir}/terminfo ${S}/info/cruft.src

    install -d ${D}${mandir}/man1
    install -m 0644 ${S}/man/cruft.1 ${D}${mandir}/man1/cruft.1

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/cruft@.service ${D}${systemd_system_unitdir}/cruft@.service

    install -d ${D}${systemd_unitdir}/system-generators
    sed -e 's|@SYSTEMD_SYSTEM_UNITDIR@|${systemd_system_unitdir}|g' \
        ${UNPACKDIR}/cruft-generator > ${D}${systemd_unitdir}/system-generators/cruft-generator
    chmod 0755 ${D}${systemd_unitdir}/system-generators/cruft-generator
    ${D}${systemd_unitdir}/system-generators/cruft-generator --self-check

    install -d ${D}${sysconfdir}/default
    install -m 0644 ${UNPACKDIR}/console.default ${D}${sysconfdir}/default/console
}

SYSTEMD_SERVICE:${PN} = ""
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

pkg_postinst:${PN}() {
#!/bin/sh
# Drop legacy yaft wiring and any short-lived /etc/default/yaft.
rm -f $D${sysconfdir}/systemd/system/getty.target.wants/yaft@tty1.service
rm -f $D${sysconfdir}/systemd/system/getty@tty1.service
if [ -f $D${sysconfdir}/default/yaft ] && [ ! -e $D${sysconfdir}/default/console ]; then
    mv $D${sysconfdir}/default/yaft $D${sysconfdir}/default/console
fi
rm -f $D${sysconfdir}/default/yaft
}

FILES:${PN} += "${datadir}/terminfo \
                ${systemd_system_unitdir}/cruft@.service \
                ${systemd_unitdir}/system-generators/cruft-generator \
                ${sysconfdir}/default/console \
"

CONFFILES:${PN} = "${sysconfdir}/default/console"
