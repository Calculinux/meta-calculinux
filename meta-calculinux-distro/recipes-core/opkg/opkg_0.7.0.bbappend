FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Use Calculinux fork with image status file support and query filtering
SRC_URI:remove = "http://downloads.yoctoproject.org/releases/${BPN}/${BPN}-${PV}.tar.gz"
SRC_URI:prepend = "git://github.com/Calculinux/opkg.git;protocol=https;branch=master "

SRCREV = "v0.9.0-calculinux1"
