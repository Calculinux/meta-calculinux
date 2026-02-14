# Set cap_checkpoint_restore on the criu binary so it can checkpoint/restore
# without full root. Requires kernel 5.9+ and libcap.
do_install:append() {
    if [ -f ${D}${sbindir}/criu ]; then
        setcap cap_checkpoint_restore+ep ${D}${sbindir}/criu
    elif [ -f ${D}${bindir}/criu ]; then
        setcap cap_checkpoint_restore+ep ${D}${bindir}/criu
    fi
}

# setcap is provided by libcap-native (build host)
DEPENDS:append = " libcap-native"
