SUMMARY = "OverlayFS lower layer restoration tool"
HOMEPAGE = "https://github.com/Calculinux/luckfox-linux-6.1-rk3506"
DESCRIPTION = "Command-line tool to restore visibility of overlayfs lower layer files \
by removing whiteouts from the upper layer using the OVL_IOC_RESTORE_LOWER ioctl."

LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

SRC_URI = "git://github.com/Calculinux/luckfox-linux-6.1-rk3506.git;protocol=https;nobranch=1"
SRCREV = "7e3209499d520d8960fd0a37e0dc34bf88252b04"

S = "${WORKDIR}/git/tools/ovl-restore"

# Use SRCPV for automatic git-based versioning
PV = "1.0.0+git${SRCPV}"

do_compile() {
    # Set cross-compilation variables
    oe_runmake CC="${CC}" \
               CFLAGS="${CFLAGS}" \
               LDFLAGS="${LDFLAGS}"
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/ovl-restore ${D}${bindir}/ovl-restore
}

FILES:${PN} = "${bindir}/ovl-restore"

# Note: Requires CONFIG_OVERLAY_FS to be enabled in the kernel
# Since overlayfs is built into the kernel (not a module), there's no
# runtime package dependency needed
