SUMMARY = "Yet another framebuffer terminal with mmap fonts"
DESCRIPTION = "Lightweight VT-compatible framebuffer terminal for Calculinux. \
Uses demand-paged .yaftfont blobs with runtime cell metrics (6x12 default, \
optional 8x16 Unifont via YAFT_FONT). Opens the kernel framebuffer already \
set up by TinyDRM/fbcon — does not re-init the panel. Local VTs are wired \
via a systemd generator controlled by /etc/default/console (CONSOLE=yaft|kernel)."

HOMEPAGE = "https://github.com/Calculinux/yaft"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0a1f0030369f9d1f26870e0bfc24c47b"

SRC_URI = "git://github.com/Calculinux/yaft.git;protocol=https;branch=main \
           file://yaft@.service \
           file://yaft-budget-check.sh \
           file://console.default \
           file://yaft-generator \
           file://console-mode \
           "
SRCREV = "350c5b674f52efcd2db2cc00fd1ff3f2e953e790"
PV = "0.2.9+calculinux${SRCPV}"

S = "${WORKDIR}/git"

DEPENDS = "ncurses-native"
RDEPENDS:${PN} = "console-font"

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
    oe_runmake yaft
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/yaft ${D}${bindir}/yaft

    install -m 0755 ${UNPACKDIR}/yaft-budget-check.sh ${D}${bindir}/yaft-budget-check
    install -m 0755 ${UNPACKDIR}/console-mode ${D}${bindir}/console-mode

    install -d ${D}${datadir}/terminfo
    tic -o ${D}${datadir}/terminfo ${S}/info/yaft.src

    install -d ${D}${mandir}/man1
    install -m 0644 ${S}/man/yaft.1 ${D}${mandir}/man1/yaft.1

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/yaft@.service ${D}${systemd_system_unitdir}/yaft@.service

    # Generator picks yaft vs kernel getty from /etc/default/console (no static /etc masks).
    install -d ${D}${systemd_unitdir}/system-generators
    sed -e 's|@SYSTEMD_SYSTEM_UNITDIR@|${systemd_system_unitdir}|g' \
        ${UNPACKDIR}/yaft-generator > ${D}${systemd_unitdir}/system-generators/yaft-generator
    chmod 0755 ${D}${systemd_unitdir}/system-generators/yaft-generator
    ${D}${systemd_unitdir}/system-generators/yaft-generator --self-check

    install -d ${D}${sysconfdir}/default
    install -m 0644 ${UNPACKDIR}/console.default ${D}${sysconfdir}/default/console
}

SYSTEMD_SERVICE:${PN} = ""
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

# Drop pre-generator static getty mask and any short-lived /etc/default/yaft.
pkg_postinst:${PN}() {
#!/bin/sh
rm -f $D${sysconfdir}/systemd/system/getty.target.wants/yaft@tty1.service
rm -f $D${sysconfdir}/systemd/system/getty@tty1.service
if [ -f $D${sysconfdir}/default/yaft ] && [ ! -e $D${sysconfdir}/default/console ]; then
    mv $D${sysconfdir}/default/yaft $D${sysconfdir}/default/console
fi
rm -f $D${sysconfdir}/default/yaft
}

FILES:${PN} += "${datadir}/terminfo \
                ${systemd_system_unitdir}/yaft@.service \
                ${systemd_unitdir}/system-generators/yaft-generator \
                ${sysconfdir}/default/console \
"

CONFFILES:${PN} = "${sysconfdir}/default/console"
