SUMMARY = "Calculinux RedUced Footprint Terminal"
DESCRIPTION = "Linux framebuffer VT terminal for Calculinux (PicoCalc / Luckfox Lyra). \
Uses demand-paged .cruftfont blobs with runtime cell metrics (4x8 miniwi, \
6x12 default, 8x16 Unifont), sparse sixel cell storage, and lazy DRCS. \
Optional status bar in the top margin strip (wifi, clock, backlight, \
battery) rendered in a second 4x8 font (miniwi-console). \
Font is selected via CRUFT_FONT in /etc/cruft.conf. \
Opens the kernel framebuffer already set up by TinyDRM/fbcon. Local VTs \
are wired statically at install (CONSOLE=cruft|kernel in \
/etc/default/console; `console-mode apply` re-applies)."

HOMEPAGE = "https://github.com/Calculinux/cruft"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0a1f0030369f9d1f26870e0bfc24c47b"

# TEMP (revert when the full stack — cruft #4/#5/#6/#10/#11 — merges):
# fetch from the stack-tip branch instead of main so this SRCREV resolves;
# after the merge, restore branch=main with the landed SHA.
SRC_URI = "git://github.com/Calculinux/cruft.git;protocol=https;branch=feat/etcc \
           file://cruft@.service \
           file://cruft-budget-check.sh \
           file://console.default \
           file://cruft.conf \
           file://console-mode \
           "
SRCREV = "c9e70abff40a6162002379f1b7005f9daa630bdc"
PV = "0.2.10+git${SRCPV}"

S = "${WORKDIR}/git"

DEPENDS = "ncurses-native"
# miniwi-console carries the status bar's 4x8 font; the bar is on by
# default whenever that font is loadable, so it is a hard dependency.
RDEPENDS:${PN} = "console-font miniwi-console"
RRECOMMENDS:${PN} = "unifont-console"
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
        ${S}/sixel_canvas.c ${S}/glyph_mmap.c ${S}/terminal_cell.c \
        ${S}/scrollback.c ${S}/sbdisk.c \
        ${S}/status.c ${S}/conf.c
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

    install -d ${D}${sysconfdir}/default
    install -m 0644 ${UNPACKDIR}/console.default ${D}${sysconfdir}/default/console

    install -d ${D}${sysconfdir}
    install -m 0644 ${UNPACKDIR}/cruft.conf ${D}${sysconfdir}/cruft.conf
}

SYSTEMD_SERVICE:${PN} = ""
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

pkg_postinst:${PN}() {
#!/bin/sh
# $D is the image root at build time, empty on the target.
# Drop legacy yaft wiring and any short-lived /etc/default/yaft.
rm -f $D${sysconfdir}/systemd/system/getty.target.wants/yaft@tty1.service
rm -f $D${sysconfdir}/systemd/system/getty@tty1.service
if [ -f $D${sysconfdir}/default/yaft ] && [ ! -e $D${sysconfdir}/default/console ]; then
    mv $D${sysconfdir}/default/yaft $D${sysconfdir}/default/console
fi
rm -f $D${sysconfdir}/default/yaft

# Static console wiring (output of the retired systemd generator, made
# permanent): alias on-demand VTs (logind autovt@) to cruft@, want the
# boot VT's cruft@ on getty.target, mask the managed kernel gettys.
# /etc outranks /usr/lib, so these stand for what the generator used
# to emit in /run at every boot. Rewritten on every install, so a
# CONSOLE or CONSOLE_TTYS edit takes effect at the next package
# upgrade (or immediately via `console-mode apply`).
CONSOLE=cruft
CONSOLE_TTYS="1 2 3 4 5 6"
if [ -f $D${sysconfdir}/default/console ]; then
    # shellcheck disable=SC1090
    . $D${sysconfdir}/default/console
fi
SYSDIR=$D${sysconfdir}/systemd/system
rm -f $SYSDIR/autovt@.service
# shellcheck disable=SC2086
for n in $CONSOLE_TTYS; do
    rm -f $SYSDIR/getty@tty${n}.service \
        $SYSDIR/getty.target.wants/cruft@tty${n}.service
done
case "$CONSOLE" in
kernel)
    echo "cruft: CONSOLE=kernel, leaving kernel gettys unwired"
    ;;
*)
    # shellcheck disable=SC2086
    set -- $CONSOLE_TTYS
    boot_tty=${1:-1}
    mkdir -p $SYSDIR/getty.target.wants
    ln -sf ${systemd_system_unitdir}/cruft@.service $SYSDIR/autovt@.service
    ln -sf ${systemd_system_unitdir}/cruft@.service \
        $SYSDIR/getty.target.wants/cruft@tty${boot_tty}.service
    # shellcheck disable=SC2086
    for n in $CONSOLE_TTYS; do
        ln -sf /dev/null $SYSDIR/getty@tty${n}.service
    done
    ;;
esac
}

pkg_postrm:${PN}() {
#!/bin/sh
# Unwire the static console wiring (see pkg_postinst). console.default
# is a conffile, so it survives removal and tells us the managed VTs.
CONSOLE_TTYS="1 2 3 4 5 6"
if [ -f $D${sysconfdir}/default/console ]; then
    # shellcheck disable=SC1090
    . $D${sysconfdir}/default/console
fi
SYSDIR=$D${sysconfdir}/systemd/system
rm -f $SYSDIR/autovt@.service
# shellcheck disable=SC2086
for n in $CONSOLE_TTYS; do
    rm -f $SYSDIR/getty@tty${n}.service \
        $SYSDIR/getty.target.wants/cruft@tty${n}.service
done
}

FILES:${PN} += "${datadir}/terminfo \
                ${systemd_system_unitdir}/cruft@.service \
                ${sysconfdir}/default/console \
                ${sysconfdir}/cruft.conf \
                "

CONFFILES:${PN} = "${sysconfdir}/default/console ${sysconfdir}/cruft.conf"
