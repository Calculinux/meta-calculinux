FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://local-packages.sh \
    file://local-packages.conf \
"

do_install:append() {
    # Install profile.d script for PATH configuration
    install -d ${D}${sysconfdir}/profile.d
    install -m 0644 ${UNPACKDIR}/local-packages.sh ${D}${sysconfdir}/profile.d/local-packages.sh
    
    # Install ld.so.conf.d configuration for dynamic linker
    install -d ${D}${sysconfdir}/ld.so.conf.d
    install -m 0644 ${UNPACKDIR}/local-packages.conf ${D}${sysconfdir}/ld.so.conf.d/local-packages.conf
    
    # Create /usr/local directory structure for user packages
    # This follows FHS standard for locally-installed software
    install -d ${D}${prefix}/local/bin
    install -d ${D}${prefix}/local/sbin
    install -d ${D}${prefix}/local/lib
    install -d ${D}${prefix}/local/etc
    install -d ${D}${prefix}/local/share
    install -d ${D}${prefix}/local/include
    
    # Create /opt directory for optional/add-on software packages
    # Conventional location for manually managed packages
    install -d ${D}/opt
}

FILES:${PN} += " \
    ${sysconfdir}/profile.d/local-packages.sh \
    ${sysconfdir}/ld.so.conf.d/local-packages.conf \
    ${prefix}/local \
    /opt \
"

