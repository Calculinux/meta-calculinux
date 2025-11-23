# Enable UTF-8 support in less for proper Unicode rendering
# This ensures less can display international characters, smart quotes, em-dashes, etc.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://less.sh"

do_install:append() {
    # Install environment configuration for less
    install -d ${D}${sysconfdir}/profile.d
    install -m 0755 ${UNPACKDIR}/less.sh ${D}${sysconfdir}/profile.d/less.sh
}

FILES:${PN} += "${sysconfdir}/profile.d/less.sh"
