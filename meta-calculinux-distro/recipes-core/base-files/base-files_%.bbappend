FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://locale.sh"

do_install:append() {
    install -d ${D}${sysconfdir}/profile.d
    install -m 0644 ${WORKDIR}/locale.sh ${D}${sysconfdir}/profile.d/locale.sh
}
