SUMMARY = "AIC8800 USB Wi-Fi kernel module (DKMS package)"
DESCRIPTION = "AIC8800 DC/D80/D80X2 USB wireless driver built from official BrosTrend DKMS package. Supports DC WiFi-only variant."
HOMEPAGE = "https://linux.brostrend.com"
LICENSE = "GPL-2.0-only"
PV = "1.0.8"

# License file is extracted from deb package (usr/share/doc/aic8800-dkms/copyright)
LIC_FILES_CHKSUM = "file://${WORKDIR}/usr/share/doc/aic8800-dkms/copyright;md5=dda5bafa8afaed74f884152b2b3efd00"

# Download the prebuilt DKMS deb package
SRC_URI = "https://linux.brostrend.com/aic8800-dkms.deb;unpack=0 \
           file://0001-disable-werror-and-fix-address-check.patch \
           file://0002-disable-ft-ies-update.patch \
"
SRC_URI[sha256sum] = "952152f3add4ec24fee4af5a677b40135eec7759945268c8539bcc8b8da655eb"

S = "${WORKDIR}/aic8800-${PV}"
B = "${S}"

DEPENDS = "virtual/kernel"
RDEPENDS:${PN} = ""

inherit module

# Build configuration - matches what worked on test machine
EXTRA_OEMAKE += "KDIR=${STAGING_KERNEL_BUILDDIR}"
EXTRA_OEMAKE += "KSRC=${STAGING_KERNEL_DIR}"
EXTRA_OEMAKE += "ARCH=${ARCH}"
EXTRA_OEMAKE += "CROSS_COMPILE=${TARGET_PREFIX}"
EXTRA_OEMAKE += "CONFIG_PLATFORM_UBUNTU=y"
EXTRA_OEMAKE += "CONFIG_USE_FW_REQUEST=n"
EXTRA_OEMAKE += "CONFIG_PREALLOC_RX_SKB=y"
EXTRA_OEMAKE += "CONFIG_PREALLOC_TXQ=y"

PACKAGES =+ "${PN}-firmware ${PN}-udev"

# Allow buildpaths QA check to pass - kernel modules often contain build paths
INSANE_SKIP:${PN} += "buildpaths"
INSANE_SKIP:${PN}-dbg += "buildpaths"

FILES:${PN} = "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/aic8800/*.ko"
FILES:${PN}-firmware = "${nonarch_base_libdir}/firmware/aic8800DC"
FILES:${PN}-udev = "${sysconfdir}/udev/rules.d/aic.rules"

RDEPENDS:${PN} += "${PN}-firmware ${PN}-udev"

# Declare that this recipe provides the kernel modules
RPROVIDES:${PN} += "kernel-module-aic-load-fw-${KERNEL_VERSION} kernel-module-aic8800-fdrv-${KERNEL_VERSION}"

# Module autoload order - loader first, then driver
KERNEL_MODULE_AUTOLOAD:${PN} = "aic_load_fw aic8800_fdrv"

COMPATIBLE_MACHINE = "luckfox-lyra"

python do_unpack:append() {
    import subprocess
    import os
    import shutil
    
    workdir = d.getVar('WORKDIR')
    dl_dir = d.getVar('DL_DIR')
    pv = d.getVar('PV')
    
    # With unpack=0, the deb stays in DL_DIR
    deb_file = os.path.join(dl_dir, 'aic8800-dkms.deb')
    
    if not os.path.exists(deb_file):
        bb.fatal('DEB file not found in DL_DIR: %s' % deb_file)
    
    # Copy deb to workdir for extraction
    workdir_deb = os.path.join(workdir, 'aic8800-dkms.deb')
    shutil.copy(deb_file, workdir_deb)
    
    # Extract deb to workdir
    # deb format: ar x file.deb extracts control.tar.gz, data.tar.gz, debian-binary
    os.chdir(workdir)
    subprocess.run(['ar', 'x', workdir_deb], check=True, capture_output=True)
    subprocess.run(['tar', '-xzf', 'data.tar.gz'], check=True, capture_output=True)
    
    # The deb extracts to usr/src/aic8800-<PV> and lib/firmware/aic8800DC
    # Move driver source to S
    src_path = os.path.join(workdir, 'usr', 'src', 'aic8800-%s' % pv)
    dst_path = os.path.join(workdir, 'aic8800-%s' % pv)
    if os.path.exists(src_path) and not os.path.exists(dst_path):
        shutil.move(src_path, dst_path)
        bb.debug(1, 'Moved source from %s to %s' % (src_path, dst_path))
    
    # Extract udev rules from deb lib/udev/rules.d/
    # Already extracted by tar above, just verify it exists
    rules_path = os.path.join(workdir, 'lib', 'udev', 'rules.d', 'aic.rules')
    if os.path.exists(rules_path):
        bb.debug(1, 'Found aic.rules at %s' % rules_path)
    else:
        bb.warn('aic.rules not found at %s' % rules_path)
    
    # Convert all source files from CRLF to LF line endings
    # This allows patches to apply cleanly despite upstream using Windows line endings
    src_dir = os.path.join(workdir, 'aic8800-%s' % pv)
    if os.path.exists(src_dir):
        for root, dirs, files in os.walk(src_dir):
            for file in files:
                if file.endswith(('.c', '.h', '.makefile', 'Makefile')):
                    filepath = os.path.join(root, file)
                    try:
                        with open(filepath, 'rb') as f:
                            content = f.read()
                        # Replace CRLF with LF
                        content = content.replace(b'\r\n', b'\n')
                        with open(filepath, 'wb') as f:
                            f.write(content)
                    except Exception as e:
                        bb.warn('Failed to convert line endings for %s: %s' % (filepath, str(e)))
}

do_compile() {
    # Build aic_load_fw module first
    cd ${B}/aic_load_fw
    oe_runmake
    
    cp ${B}/aic_load_fw/Module.symvers ${B}/aic8800_fdrv/
    
    # Build aic8800_fdrv module with access to aic_load_fw symbols
    cd ${B}/aic8800_fdrv
    oe_runmake KBUILD_EXTRA_SYMBOLS="${B}/aic_load_fw/Module.symvers"
}

do_install() {
    # Install modules
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/aic8800
    install -m 0644 ${S}/aic_load_fw/aic_load_fw.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/aic8800/
    install -m 0644 ${S}/aic8800_fdrv/aic8800_fdrv.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/aic8800/

    # Install firmware files from extracted deb
    install -d ${D}${nonarch_base_libdir}/firmware/aic8800DC
    if [ -d ${WORKDIR}/lib/firmware/aic8800DC ]; then
        cp -r --no-preserve=ownership ${WORKDIR}/lib/firmware/aic8800DC/* ${D}${nonarch_base_libdir}/firmware/aic8800DC/
    fi

    # Install udev rules extracted from deb
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/lib/udev/rules.d/aic.rules ${D}${sysconfdir}/udev/rules.d/
}
