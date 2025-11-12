SUMMARY = "Device Tree Blob Overlay Configuration File System"
DESCRIPTION = "Out-of-tree kernel module providing a configfs interface for dynamically loading and unloading device tree overlay blobs."

LICENSE = "BSD-2-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=6e83d63de93384e6cce0fd3632041d91"

DEPENDS = "virtual/kernel"

inherit module

SRC_URI = "git://github.com/ikwzm/dtbocfg.git;protocol=https;branch=master"
SRCREV = "06207c67bac6978a997b37d6e8843504d6f70a4b"

S = "${WORKDIR}/git"

# Build system uses host arch heuristics that conflict with cross builds; override with kernel settings
do_configure[noexec] = "1"
do_compile[depends] += "virtual/kernel:do_shared_workdir"

EXTRA_OEMAKE = "\
    KERNEL_SRC=${STAGING_KERNEL_DIR} \
    KSRC=${STAGING_KERNEL_DIR} \
    KDIR=${STAGING_KERNEL_BUILDDIR} \
    ARCH=${ARCH} \
    CROSS_COMPILE=${TARGET_PREFIX} \
"

KERNEL_MODULE_AUTOLOAD:${PN} = "dtbocfg"

FILES:${PN} += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}"

COMPATIBLE_MACHINE = "luckfox-lyra"
