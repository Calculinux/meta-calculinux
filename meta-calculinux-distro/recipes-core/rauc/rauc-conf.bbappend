FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append := "\
                    file://system.conf.in \
                  "

RAUC_SYSTEMCONF_TEMPLATE = "${UNPACKDIR}/system.conf.in"

# These variables must be defined in the machine config. E.g.
# RAUC_SLOT_A_DEVICE = "/dev/mmcblk1p2"
# RAUC_SLOT_B_DEVICE = "/dev/mmcblk1p3"
# This task creates system.conf in the UNPACKDIR from the system.conf.in template
python do_create_system_config() {
    raucSlotADevice = d.getVar("RAUC_SLOT_A_DEVICE")
    raucSlotBDevice = d.getVar("RAUC_SLOT_B_DEVICE")
    compatible = d.getVar("RAUC_COMPATIBLE")

    if not raucSlotADevice  :
        bb.fatal("RAUC_SLOT_A_DEVICE  must be set in your MACHINE configuration")
    if not raucSlotBDevice  :
        bb.fatal("RAUC_SLOT_B_DEVICE  must be set in your MACHINE configuration")

    with open(d.getVar("RAUC_SYSTEMCONF_TEMPLATE"), "r") as f:
        fileTemplate = f.read()

    filePath = oe.path.join(d.getVar("UNPACKDIR"), "system.conf")

    args = {
        'RAUC_SLOT_A_DEVICE': raucSlotADevice,
        'RAUC_SLOT_B_DEVICE': raucSlotBDevice,
        'SYSTEM_COMPATIBLE': compatible
    }

    with open(filePath, 'w') as f:
        f.write(fileTemplate.format(**args))
    os.chmod(filePath, 0o755)
}

addtask create_system_config after do_configure before do_install
