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
population by a media manager - which this handler effectively is. \
A build-time /sdcard symlink to the mountpoint ships with the package; \
it dangles until the card is mounted and needs no runtime recreation \
since it lives on the persistent rootfs."
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
# The unit stays declared for documentation, but no packaging scripts
# are generated: the class would emit a prerm running
# `systemctl stop calculinux-sdcard@.service` on the *uninstantiated
# template*, which systemd refuses ("missing the instance name") and
# which aborts every `opkg remove` of this package (the generated prerm
# runs under `set -e`), wedging cup's post-reboot duplicate removal on
# every boot. Instance lifecycle is fully udev-driven (the udev rule
# stops `calculinux-sdcard@%k.service` per card on disconnect), so no
# package lifecycle script is needed at all.
SYSTEMD_SERVICE:${PN} = "calculinux-sdcard@.service"
SYSTEMD_PACKAGES = ""
SYSTEMD_AUTO_ENABLE = "disable"

# A template cannot be stopped - systemd refuses an uninstantiated
# "systemctl stop calculinux-sdcard@.service" ("missing the instance
# name") - but an inserted card can still have a live instance when
# the package is removed, and removal whiteouts the udev rule and the
# handler its ExecStop relies on. Stop the instantiated units instead;
# enumeration via list-units patterns only ever yields concrete
# instances. Failures never abort the removal: a unit that cannot be
# stopped stays managed until the card is ejected or the next boot.
pkg_prerm:${PN} () {
    [ -z "$D" ] || return 0
    command -v systemctl >/dev/null 2>&1 || return 0
    for unit in $(systemctl list-units --quiet --no-legend \
                    --property=Names 'calculinux-sdcard@*.service' \
                    2>/dev/null | cut -d= -f2); do
        [ -n "$unit" ] && systemctl stop "$unit" || true
    done
    return 0
}

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

    # Fixed /sdcard alias for the mountpoint, baked in at build time
    # because the read-only rootfs gains nothing at runtime. It dangles
    # until the card is mounted (the /run tmpfs holds the real dir) and
    # resolves afterwards; /run exists on every boot so the link never
    # needs recreating.
    # ${prefix} is "/" so the link lands at ${D}/sdcard.
    ln -s /run/media/sdcard ${D}${prefix}/sdcard
}

FILES:${PN} = " \
    ${nonarch_base_libdir}/udev/rules.d/99-calculinux-sdcard.rules \
    ${nonarch_base_libdir}/calculinux/calculinux-sdcard.sh \
    ${systemd_system_unitdir}/calculinux-sdcard@.service \
    ${prefix}/sdcard \
"
