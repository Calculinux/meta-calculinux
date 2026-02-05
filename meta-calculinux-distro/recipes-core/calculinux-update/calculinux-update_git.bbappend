# Patches for 32-bit ARM ioctl safety, conffile overlay paths, and future version-compat
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " \
    file://0001-overlayfs-ioctl-32bit-arm-safety-and-correct-magic.patch \
    file://0002-conffiles-correct-overlay-path-construction.patch \
    file://0003-version-compat-and-hooks-integration.patch \
"
