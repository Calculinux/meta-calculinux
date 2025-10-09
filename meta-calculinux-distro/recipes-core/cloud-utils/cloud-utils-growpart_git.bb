DESCRIPTION = "growpart utility from cloud-utils"
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=d32239bcb673463ab874e80d47fae504"

SRC_URI = "git://github.com/canonical/cloud-utils.git;protocol=https;branch=main;nobranch=1"
SRCREV = "49e5dd7849ee3c662f3db35e857148d02e72694b"

S = "${WORKDIR}/git"

do_install() {
    install -d ${D}${base_sbindir}
    install -m 0755 ${S}/bin/growpart ${D}${base_sbindir}
}

FILES:${PN} += "${base_sbindir}/growpart"

BBCLASSEXTEND = "native"
