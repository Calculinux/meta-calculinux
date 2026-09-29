SUMMARY = "overlayfs with the Calculinux upper-layer ioctls"
DESCRIPTION = "overlayfs from the target kernel built as an out-of-tree overlay.ko, \
adding OVL_IOC_UPPER_STATE, OVL_IOC_IS_RESTORABLE and OVL_IOC_RESTORE_LOWER, \
which calculinux-update uses to reconcile overlay packages with a new base \
image. The kernel must be built with CONFIG_OVERLAY_FS=n."
HOMEPAGE = "https://github.com/Calculinux/overlayfs"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

# The machine names the branch for its kernel series, e.g. linux-6.1.
OVERLAYFS_CALCULINUX_BRANCH ??= ""
OVERLAYFS_CALCULINUX_SRCREV[linux-6.1] = "06bc0262a65550b8e068dcc95d3f83695bc65100"
OVERLAYFS_CALCULINUX_SRCREV[linux-6.12] = "3b1f5624c3b1213aeb34dac88490d3501e17d474"

SRC_URI = "git://github.com/Calculinux/overlayfs.git;protocol=https;branch=${OVERLAYFS_CALCULINUX_BRANCH}"
SRCREV = "${@d.getVarFlag('OVERLAYFS_CALCULINUX_SRCREV', d.getVar('OVERLAYFS_CALCULINUX_BRANCH')) or 'INVALID'}"

S = "${UNPACKDIR}/git"
PV = "${@d.getVar('OVERLAYFS_CALCULINUX_BRANCH').replace('linux-', '')}+git"

inherit module

python () {
    branch = d.getVar('OVERLAYFS_CALCULINUX_BRANCH')
    if not branch:
        raise bb.parse.SkipRecipe("OVERLAYFS_CALCULINUX_BRANCH is not set for this machine")
    if not d.getVarFlag('OVERLAYFS_CALCULINUX_SRCREV', branch):
        raise bb.parse.SkipRecipe("no OVERLAYFS_CALCULINUX_SRCREV for branch %s" % branch)
}
