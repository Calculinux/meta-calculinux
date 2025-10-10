SUMMARY = "Meta Calculinux Apps package group"
DESCRIPTION = "Package group for additional applications and tools for Calculinux"

inherit packagegroup

PACKAGES = "${PN}"

RDEPENDS:${PN} = "zerotier-one"
