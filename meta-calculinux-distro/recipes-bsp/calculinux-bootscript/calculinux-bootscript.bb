SUMMARY = "Calculinux U-Boot boot script (RAUC A/B + merged DT overlay FIT)"
DESCRIPTION = "Picks the RAUC slot, loads that slot's merged FIT from OVERLAY_DATA \
(falling back to /boot/zboot_merged.img) and boots it. Board specifics come from \
the machine configuration."
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

# Set these in the machine configuration.
#   CALCULINUX_BOOT_CONSOLE     kernel console device (e.g. ttyFIQ0, ttyAMA0)
#   CALCULINUX_BOOT_BAUDRATE    console baud rate
#   CALCULINUX_BOOT_EXTRA_ARGS  board-only kernel arguments (earlycon, debug, ...)
#   CALCULINUX_BOOT_LAST_RESORT optional image in the slot's /boot/ to bootm when
#                               no merged FIT loads (e.g. Rockchip zboot.img)
CALCULINUX_BOOT_CONSOLE ??= ""
CALCULINUX_BOOT_BAUDRATE ??= "115200"
CALCULINUX_BOOT_EXTRA_ARGS ??= ""
CALCULINUX_BOOT_LAST_RESORT ??= ""

UBOOT_BOOTSCR_TEMPLATE = "${UNPACKDIR}/boot.scr.sh.in"
UBOOT_BOOTSCR = "${S}/boot.scr.sh"
UBOOT_BOOTSCR_IMG = "${B}/boot.scr"

# This task creates boot.scr.sh in the UNPACKDIR from the boot.scr.sh.in template
python do_create_boot_scr_sh() {
    console = d.getVar("CALCULINUX_BOOT_CONSOLE")
    if not console:
        bb.fatal("CALCULINUX_BOOT_CONSOLE must be set in your MACHINE configuration")

    with open(d.getVar("UBOOT_BOOTSCR_TEMPLATE"), "r") as f:
        bootScrTemplate = f.read()

    last_resort = d.getVar("CALCULINUX_BOOT_LAST_RESORT")
    if last_resort:
        last_resort_cmds = (
            "echo Loading %s from ROOT;\n"
            "load ${devtype} ${devnum}:${mmcpart} ${ramdisk_addr_r} /boot/%s;\n"
            "echo Booting from address <${ramdisk_addr_r}>;\n"
            "bootm ${ramdisk_addr_r}\n" % (last_resort, last_resort))
    else:
        last_resort_cmds = "echo No bootable FIT found for slot ${rauc_slot};\n"

    args = {
        'CONSOLE': console,
        'BAUDRATE': d.getVar("CALCULINUX_BOOT_BAUDRATE"),
        'EXTRA_ARGS': d.getVar("CALCULINUX_BOOT_EXTRA_ARGS"),
        'LAST_RESORT': last_resort_cmds,
    }

    bootScrPath = d.getVar("UBOOT_BOOTSCR")
    with open(bootScrPath, 'w') as f:
        f.write(bootScrTemplate.format(**args))
    os.chmod(bootScrPath, 0o755)
}
do_create_boot_scr_sh[vardeps] += "CALCULINUX_BOOT_CONSOLE CALCULINUX_BOOT_BAUDRATE CALCULINUX_BOOT_EXTRA_ARGS CALCULINUX_BOOT_LAST_RESORT"

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

# Formerly u-boot-rockchip-bootscript in meta-picocalc-bsp-rockchip.
RPROVIDES:${PN} += "u-boot-rockchip-bootscript"
RREPLACES:${PN} += "u-boot-rockchip-bootscript"
RCONFLICTS:${PN} += "u-boot-rockchip-bootscript"
