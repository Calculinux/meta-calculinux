# Custom kernel for QEMU ARM32 test with ovl-restore ioctl support
# Based on linux-yocto 6.1 with overlayfs-restore-lower patch

require recipes-kernel/linux/linux-yocto.inc

LINUX_VERSION ?= "6.1"
LINUX_VERSION_EXTENSION:append = "-ovl-restore"

KBRANCH = "v6.1/standard/base"
SRCREV_machine ?= "${AUTOREV}"
SRCREV_meta ?= "${AUTOREV}"

SRC_URI = "git://git.yoctoproject.org/linux-yocto.git;protocol=https;branch=${KBRANCH};name=machine \
           git://git.yoctoproject.org/yocto-kernel-cache;type=kmeta;name=meta;branch=yocto-6.1;destsuffix=${KMETA};protocol=https \
           file://overlayfs-restore-lower.patch \
           file://overlayfs-test.cfg \
"

COMPATIBLE_MACHINE = "qemu-arm32-test"

KERNEL_CONFIG_FRAGMENTS += "overlayfs-test.cfg"
