# The data package's udev rules run the dispatcher, which our usb-modeswitch
# bbappend moves into its own package.
RDEPENDS:${PN} += "usb-modeswitch-dispatcher"
