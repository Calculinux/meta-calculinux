SUMMARY = "AIC8800 Wi-Fi driver and firmware"
DESCRIPTION = "Out-of-tree full MAC driver for AIC8800 USB adapters with bundled firmware and udev helpers"
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://../../../../../LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

inherit module

PV = "1.1.0+git${SRCPV}"
SRC_URI = "git://github.com/radxa-pkg/aic8800.git;protocol=https;branch=main"
SRCREV = "451a1c8f14dad821034017ccb902eaf0a2b8c2ee"

S = "${WORKDIR}/git/src/USB/driver_fw/drivers/aic8800"

EXTRA_OEMAKE += " \
    KDIR=${STAGING_KERNEL_DIR} \
    ARCH=${ARCH} \
    CROSS_COMPILE=${TARGET_PREFIX} \
    CONFIG_PLATFORM_UBUNTU=n \
    CONFIG_PLATFORM_ROCKCHIP=n \
    CONFIG_PLATFORM_ALLWINNER=n \
    CONFIG_PLATFORM_AMLOGIC=n \
    CONFIG_PLATFORM_HI=n \
    V=1 \
    CONFIG_AIC_LOADFW_SUPPORT=m \
    CONFIG_AIC8800_WLAN_SUPPORT=m \
"

DEBIAN_PATCHES = " \
    fix-sdio-firmware-path.patch \
    fix-sdio-fall-through.patch \
    fix-debug-file-with-no-debug-symbols.patch \
    fix-pcie-build.patch \
    fix-pcie-firmware-path.patch \
    fix-usb-firmware-path.patch \
    fix-linux-6.1-build.patch \
    fix-aic_btusb.patch \
    fix-linux-6.7-build.patch \
    fix-linux-6.5-build.patch \
    fix-linux-6.9-build.patch \
    fix-linux-6.12-build.patch \
    fix-linux-6.13-build.patch \
    fix-linux-6.14-build.patch \
    fix-linux-6.15-build.patch \
    fix-aic_btusb-implicit-declare-compat_ptr.patch \
    fix-allwinner-dkms.patch \
    fix-linux-6.16-build.patch \
    fix-usb-build.patch \
    fix-aic_btusb-use-bluez-by-default.patch \
    fix-usbc1-controller-wifi-rate-of-sun60iw2p1.patch \
    fix-linux-6.17-build.patch \
"

do_apply_debian_patches() {
    for patch in ${DEBIAN_PATCHES}; do
        patch_file="${WORKDIR}/git/debian/patches/${patch}"
        if [ ! -f "${patch_file}" ]; then
            bbfatal "Missing upstream patch ${patch}"
        fi
        bbnote "Applying upstream Debian patch ${patch}"
        set +e
        patch -d ${WORKDIR}/git -p1 --forward --silent < "${patch_file}"
        status=$?
        set -e
        case ${status} in
            0)
                bbnote "Applied ${patch}"
                ;;
            1)
                bbnote "Skipping ${patch} (already applied upstream)"
                ;;
            *)
                bbfatal "Failed to apply ${patch} (patch exited with status ${status})"
                ;;
        esac
    done
}

addtask apply_debian_patches after do_patch before do_configure

do_compile() {
    unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
    oe_runmake -C ${S} modules
}

do_install() {
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra
    install -m 0644 ${S}/aic_load_fw/aic_load_fw.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/
    install -m 0644 ${S}/aic8800_fdrv/aic8800_fdrv.ko ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/

    install -d ${D}${base_libdir}/firmware
    cp -r ${WORKDIR}/git/src/USB/driver_fw/fw/aic8800D80 ${D}${base_libdir}/firmware/
    find ${D}${base_libdir}/firmware/aic8800D80 -type d -exec chmod 0755 {} +
    find ${D}${base_libdir}/firmware/aic8800D80 -type f -exec chmod 0644 {} +
}

FILES:${PN} += " \
    ${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/aic_load_fw.ko \
    ${nonarch_base_libdir}/modules/${KERNEL_VERSION}/extra/aic8800_fdrv.ko \
    ${base_libdir}/firmware/aic8800D80 \
"

RPROVIDES:${PN} += "kernel-module-aic8800_fdrv"

KERNEL_MODULE_AUTOLOAD:${PN} = "aic_load_fw aic8800_fdrv"
