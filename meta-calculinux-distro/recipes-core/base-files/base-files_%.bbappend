FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append := " \
                    file://fstab \
                    file://locale.sh \
                    file://issue \
                    file://issue.net \
                    file://motd \
                  "
                  
do_install:append() {
    install -d ${D}${sysconfdir}/profile.d
    install -m 0644 ${WORKDIR}/sources/locale.sh ${D}${sysconfdir}/profile.d/locale.sh
    
    # Install custom issue files with Calculinux branding
    install -m 0644 ${WORKDIR}/sources/issue ${D}${sysconfdir}/issue
    install -m 0644 ${WORKDIR}/sources/issue.net ${D}${sysconfdir}/issue.net
    install -m 0644 ${WORKDIR}/sources/motd ${D}${sysconfdir}/motd
}
