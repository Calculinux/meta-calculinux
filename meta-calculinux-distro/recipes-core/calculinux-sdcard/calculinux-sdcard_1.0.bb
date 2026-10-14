SUMMARY = "Automatically mount the external SD card (mmcblk1) at /run/media/sdcard"
DESCRIPTION = "Udev rule, per-device template service and handler that \
mount the partitions of the removable MMC card appearing as mmcblk1 \
(ext preened with e2fsck, read-write mount with nosuid/nodev) and \
lazily unmount them on removal. The boot card (mmcblk0, carrying \
ROOT_A/ROOT_B/SWAP/OVERLAY_DATA) is never matched or touched. All \
fsck and mount work runs in the template service, outside the udev \
worker; unmount is ownership-checked so a late remove event cannot \
tear down a different card. The mountpoint is created at runtime on \
the /run tmpfs: the read-only rootfs cannot gain directories at \
runtime, and upstream QA (QA_EMPTY_DIRS) reserves /media for runtime \
population by a media manager - which this handler effectively is."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://99-calculinux-sdcard.rules \
    file://calculinux-sdcard.sh \
    file://calculinux-sdcard@.service \
"

inherit systemd

# The template is started dynamically from udev (TAG+="systemd" +
# ENV{SYSTEMD_WANTS}); it must never be enabled at boot, and an
# uninstantiated template has nothing to enable in the first place.
SYSTEMD_SERVICE:${PN} = "calculinux-sdcard@.service"
SYSTEMD_AUTO_ENABLE = "disable"

RDEPENDS:${PN} = " \
    coreutils \
    e2fsprogs \
    systemd \
    usbutils \
    util-linux \
"

do_install() {
    install -d ${D}${nonarch_base_libdir}/udev/rules.d
    install -m 0644 ${UNPACKDIR}/99-calculinux-sdcard.rules ${D}${nonarch_base_libdir}/udev/rules.d/

    install -d ${D}${nonarch_base_libdir}/calculinux
    install -m 0755 ${UNPACKDIR}/calculinux-sdcard.sh ${D}${nonarch_base_libdir}/calculinux/

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 "${UNPACKDIR}/calculinux-sdcard@.service" ${D}${systemd_system_unitdir}/
}

FILES:${PN} = " \
    ${nonarch_base_libdir}/udev/rules.d/99-calculinux-sdcard.rules \
    ${nonarch_base_libdir}/calculinux/calculinux-sdcard.sh \
    ${systemd_system_unitdir}/calculinux-sdcard@.service \
"
