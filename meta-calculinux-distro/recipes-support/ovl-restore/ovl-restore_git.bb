SUMMARY = "Inspect and restore overlayfs lower layer entries"
HOMEPAGE = "https://github.com/Calculinux/overlayfs"
DESCRIPTION = "Command-line tool for the Calculinux overlayfs ioctls: report what \
the upper layer holds for a path (OVL_IOC_UPPER_STATE) and remove whiteouts so \
lower layer files show again (OVL_IOC_RESTORE_LOWER)."

LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

# main holds the tool and the ioctl ABI header; the kernel module is
# overlayfs-calculinux (the linux-<version> branches of the same repository).
SRC_URI = "git://github.com/Calculinux/overlayfs.git;protocol=https;branch=main"
SRCREV = "5197262f25fbb96edf45937443df26e1967c5453"

S = "${UNPACKDIR}/${BP}/tools/ovl-restore"

PV = "1.1.0+git"

do_compile() {
    oe_runmake CC="${CC}" \
               CFLAGS="${CFLAGS}" \
               LDFLAGS="${LDFLAGS}"
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/ovl-restore ${D}${bindir}/ovl-restore
}

FILES:${PN} = "${bindir}/ovl-restore"
