DESCRIPTION = "Calculinux Update Bundle"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit bundle

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://hook.sh"

RAUC_BUNDLE_FORMAT = "verity"
RAUC_BUNDLE_COMPATIBLE = "${RAUC_COMPATIBLE}"
RAUC_BUNDLE_SLOTS = "rootfs"
RAUC_BUNDLE_EXTRA_DEPENDS += "calculinux-image:do_image_complete"
RAUC_BUNDLE_EXTRA_FILES += "bundle-extras.tar.gz"

RAUC_BUNDLE_HOOKS[file] = "hook.sh"
RAUC_SLOT_rootfs = "calculinux-image"
RAUC_SLOT_rootfs[fstype] = "ext4"
RAUC_SLOT_rootfs[hooks] = "post-install"

RAUC_KEY_FILE = "${THISDIR}/files/private/development-1.key.pem"
RAUC_CERT_FILE = "${THISDIR}/files/development-1.cert.pem"
