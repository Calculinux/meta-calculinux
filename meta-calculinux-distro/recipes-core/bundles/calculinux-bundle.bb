DESCRIPTION = "Calculinux Update Bundle"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit bundle

RAUC_BUNDLE_FORMAT = "verity"
RAUC_BUNDLE_COMPATIBLE = "${RAUC_COMPATIBLE}"
RAUC_BUNDLE_SLOTS = "rootfs"
RAUC_BUNDLE_EXTRA_FILES += "bundle-extras"

RAUC_SLOT_rootfs = "calculinux-image"
RAUC_SLOT_rootfs[fstype] = "ext4"

RAUC_KEY_FILE = "${THISDIR}/files/private/development-1.key.pem"
RAUC_CERT_FILE = "${THISDIR}/files/development-1.cert.pem"
