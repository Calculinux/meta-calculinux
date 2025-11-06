FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://timeout.conf \
    file://startup-fix.conf \
"

inherit systemd

do_install:append() {
    install -d ${D}${systemd_user_unitdir}
    install -m 0644 ${S}/etc/emacs.service ${D}${systemd_user_unitdir}

    install -d ${D}${systemd_user_unitdir}/emacs.service.d
    install -m 0644 ${UNPACKDIR}/timeout.conf \
        ${D}${systemd_user_unitdir}/emacs.service.d/10-timeout.conf
    install -m 0644 ${UNPACKDIR}/startup-fix.conf \
        ${D}${systemd_user_unitdir}/emacs.service.d/20-startup-fix.conf
}

pkg_postinst:${PN}:append() {
    mkdir -p $D${sysconfdir}/systemd/user/default.target.wants
    ln -s ${systemd_user_unitdir}/emacs.service $D${sysconfdir}/systemd/user/default.target.wants/emacs.service
}

FILES:${PN} += " \
    ${systemd_user_unitdir} \
    ${sysconfdir}/systemd/user/default.target.wants/emacs.service \
"
