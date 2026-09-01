FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://main.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/iwd
    install -m 0644 ${UNPACKDIR}/main.conf ${D}${sysconfdir}/iwd/main.conf
}

CONFFILES:${PN} += "${sysconfdir}/iwd/main.conf"
