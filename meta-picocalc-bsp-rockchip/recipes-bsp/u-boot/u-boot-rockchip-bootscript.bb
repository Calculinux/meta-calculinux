SUMMARY = "Provide bootchooser script for U-Boot"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

PACKAGE_ARCH = "${MACHINE_ARCH}"

SRC_URI = " \
    file://boot.scr.sh.in \
"

DEPENDS += "u-boot-tools-native"

inherit kernel-arch deploy

S = "${UNPACKDIR}"
B = "${S}/build"

UBOOT_BOOTSCR_TEMPLATE = "${THISDIR}/files/boot.scr.sh.in"
UBOOT_BOOTSCR = "${S}/boot.scr.sh"
UBOOT_BOOTSCR_IMG = "${B}/boot.scr"

# This task creates boot.scr.sh in the UNPACKDIR from the boot.scr.sh.in template
python do_create_boot_scr_sh() {
    with open(d.getVar("UBOOT_BOOTSCR_TEMPLATE"), "r") as f:
        bootScrTemplate = f.read()

    bootScrPath = d.getVar("UBOOT_BOOTSCR")

    args = {
    }

    with open(bootScrPath, 'w') as f:
        f.write(bootScrTemplate.format(**args))
    os.chmod(bootScrPath, 0o755)
}

do_compile() {
    mkimage -C none -A ${UBOOT_ARCH} -T script -d ${UBOOT_BOOTSCR} ${UBOOT_BOOTSCR_IMG}
}

do_install() {
    install -D -m 0644 ${UBOOT_BOOTSCR_IMG} ${D}/boot/boot.scr
}

do_deploy() {
    install -D -m 0644 ${UBOOT_BOOTSCR} ${DEPLOYDIR}/boot.scr.sh
    install -D -m 0644 ${UBOOT_BOOTSCR_IMG} ${DEPLOYDIR}/boot.scr
}

addtask do_deploy after do_compile before do_install
addtask do_create_boot_scr_sh before do_compile after do_configure

FILES:${PN} += "/boot"

COMPATIBLE_MACHINE = "(luckfox-lyra)"
