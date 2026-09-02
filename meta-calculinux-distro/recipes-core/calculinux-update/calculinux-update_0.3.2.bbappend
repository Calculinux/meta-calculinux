FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://0001-min-calculinux-version.patch"
RDEPENDS:${PN}:append = " squashfs-tools"
