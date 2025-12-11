FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://man_db.conf.append"

do_install:append() {
    # Append UTF-8 configuration to man_db.conf to enable proper Unicode rendering
    # with enhanced console fonts that have additional Unicode mappings
    if [ -f ${D}${sysconfdir}/man_db.conf ]; then
        cat ${UNPACKDIR}/man_db.conf.append >> ${D}${sysconfdir}/man_db.conf
    fi
}
