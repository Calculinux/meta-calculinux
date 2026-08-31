SUMMARY = "Yet another framebuffer terminal with mmap fonts"
DESCRIPTION = "Lightweight VT-compatible framebuffer terminal for Calculinux. \
Uses demand-paged .yaftfont blobs with runtime cell metrics (6x12 default, \
optional 8x16 Unifont via YAFT_FONT). Opens the kernel framebuffer already \
set up by TinyDRM/fbcon — does not re-init the panel."

HOMEPAGE = "https://github.com/Calculinux/yaft"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0a1f0030369f9d1f26870e0bfc24c47b"

SRC_URI = "git://github.com/Calculinux/yaft.git;protocol=https;branch=main \
           file://yaft@.service \
           file://yaft-budget-check.sh \
           "
SRCREV = "3c4a430cc896332410f3741334ec59728694422d"
PV = "0.2.9+calculinux${SRCPV}"

S = "${WORKDIR}/git"

DEPENDS = "ncurses-native"
RDEPENDS:${PN} = "console-font"

inherit systemd

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Shared DL_DIR git mirrors may be owned by another CI runner UID.
do_fetch:prepend() {
    git config --global --add safe.directory '*'
}

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

    install -d ${D}${datadir}/terminfo
    tic -o ${D}${datadir}/terminfo ${S}/info/yaft.src

    install -d ${D}${mandir}/man1
    install -m 0644 ${S}/man/yaft.1 ${D}${mandir}/man1/yaft.1

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/yaft@.service ${D}${systemd_system_unitdir}/yaft@.service

    install -d ${D}${sysconfdir}/systemd/system/getty.target.wants
    ln -sf ${systemd_system_unitdir}/yaft@.service \
        ${D}${sysconfdir}/systemd/system/getty.target.wants/yaft@.service
    ln -sf /dev/null ${D}${sysconfdir}/systemd/system/getty@tty1.service
}

SYSTEMD_SERVICE:${PN} = ""
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

FILES:${PN} += "${datadir}/terminfo \
                ${systemd_system_unitdir}/yaft@.service \
                ${sysconfdir}/systemd/system/getty.target.wants \
                ${sysconfdir}/systemd/system/getty@tty1.service \
"
