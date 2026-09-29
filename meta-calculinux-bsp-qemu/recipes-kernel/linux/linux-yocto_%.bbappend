FILESEXTRAPATHS:prepend:calculinux-qemuarm := "${THISDIR}/files:"

SRC_URI:append:calculinux-qemuarm = " file://calculinux-qemu.cfg"

# The virt board has no DTS in the kernel tree: QEMU generates its device
# tree at startup. Dump it with the same board settings runqemu uses, so
# default-merged-fit can build the FIT that U-Boot boots.
DEPENDS:append:calculinux-qemuarm = " qemu-system-native dtc-native"

# Deploy the kernel blob and base FDT for default-merged-fit (same contract
# as the luckfox-lyra kernel).
do_deploy:append:calculinux-qemuarm() {
    rm -f "${DEPLOY_DIR_IMAGE}/fit_fdt.dtb" \
          "${DEPLOY_DIR_IMAGE}/fit_kernel" \
          "${DEPLOY_DIR_IMAGE}/fit_compression.txt"

    qemu-system-arm \
        -machine ${CALCULINUX_QEMU_MACHINE},dumpdtb=${B}/qemu-virt.dtb \
        -cpu ${CALCULINUX_QEMU_CPU} \
        -smp ${CALCULINUX_QEMU_SMP} \
        -m ${CALCULINUX_QEMU_MEM} \
        -display none -nodefaults
    # QEMU seeds the RNG/KASLR from /chosen on every boot; never ship a
    # fixed seed (and keep the deployed DTB reproducible).
    fdtput -d ${B}/qemu-virt.dtb /chosen rng-seed 2>/dev/null || true
    fdtput -d ${B}/qemu-virt.dtb /chosen kaslr-seed 2>/dev/null || true

    install -m 0644 "${B}/qemu-virt.dtb" "${DEPLOYDIR}/fit_fdt.dtb"
    install -m 0644 "${B}/arch/${ARCH}/boot/zImage" "${DEPLOYDIR}/fit_kernel"
    echo -n "none" > "${DEPLOYDIR}/fit_compression.txt"
}
do_deploy[vardeps] += "CALCULINUX_QEMU_MACHINE CALCULINUX_QEMU_CPU CALCULINUX_QEMU_SMP CALCULINUX_QEMU_MEM"
