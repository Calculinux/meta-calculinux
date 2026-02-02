FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Use Calculinux fork with image status file support and query filtering
SRC_URI:remove = "http://downloads.yoctoproject.org/releases/${BPN}/${BPN}-${PV}.tar.gz"
SRC_URI:prepend = "git://github.com/Calculinux/opkg.git;protocol=https;branch=master"

SRCREV = "b99c3a03ca05c6c2f1c60294d4b4c57612c753e6"
