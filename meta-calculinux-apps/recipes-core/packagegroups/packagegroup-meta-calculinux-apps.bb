SUMMARY = "Meta Calculinux Apps package group"
DESCRIPTION = "Package group for GLK interactive fiction interpreters and related tools"

inherit packagegroup

PACKAGES = "${PN}"

RDEPENDS:${PN} = "glkterm \
                  glkcli"
