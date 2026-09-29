# Split the Tcl dispatcher (and the udev/systemd glue that runs it) out of the
# main package so the usb_modeswitch binary can be installed without Tcl.
# Calculinux calls usb_modeswitch directly from per-device udev rules (see
# rtl8xxxu-udev); the dispatcher is only needed with usb-modeswitch-data.
PACKAGES =+ "${PN}-dispatcher"

FILES:${PN}-dispatcher = " \
    ${sbindir}/usb_modeswitch_dispatcher \
    ${nonarch_base_libdir}/udev/usb_modeswitch \
    ${sysconfdir}/usb_modeswitch.conf \
    ${systemd_unitdir}/system/usb_modeswitch@.service \
    ${localstatedir}/lib/usb_modeswitch \
"

RDEPENDS:${PN} = ""
RRECOMMENDS:${PN} = ""
RDEPENDS:${PN}-dispatcher = "${PN} tcl"
RRECOMMENDS:${PN}-dispatcher = "usb-modeswitch-data"

SYSTEMD_PACKAGES = "${PN}-dispatcher"
SYSTEMD_SERVICE:${PN}-dispatcher = "usb_modeswitch@.service"
