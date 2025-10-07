FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://wheel-sudoers"

do_install:append() {
    # Install sudo configuration for members of the wheel group
    install -m 0440 ${UNPACKDIR}/wheel-sudoers ${D}/${sysconfdir}/sudoers.d/wheel
}
