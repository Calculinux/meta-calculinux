# ALSA configuration for the PicoCalc M0 audio output.
#
# picocalc_snd_m0 exposes a single fixed 48 kHz / S16_LE / stereo PCM
# with no mixer controls, and the image runs no sound server, so this
# gives the "default" device what a desktop sound server would provide
# (see files/asound.conf): plug conversion to the one configuration
# the M0 takes, and a software master volume (softvol).

SUMMARY = "ALSA configuration for the PicoCalc M0 audio output"
DESCRIPTION = "Installs /etc/asound.conf defining the default PCM as a plug + softvol chain over the M0 DAC."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Machine arch, like the sibling device data recipes (calculinux-bootscript,
# u-boot-fw-config, default-merged-fit): the config is M0/Lyra-specific, and
# "all" is invisible to the SPDX 3.0 package walk (SSTATE_ARCHS has no
# "all" entry), which breaks do_create_package_spdx on the image's RDEPENDS.
PACKAGE_ARCH = "${MACHINE_ARCH}"

SRC_URI = "file://asound.conf"

# RPROVIDES names are not uniform across stacks: the walnascar poky
# pins the runtime library under the PN "alsa-lib" (no libasound2
# package, RPROVIDES libasound only), and the same PN also ships the
# built libasound_module_*.so files (incl. the softvol module this
# config needs). Depend on the PN, not a generation-specific name.
RDEPENDS:${PN} = "alsa-lib alsa-utils"

do_install() {
	install -d ${D}${sysconfdir}
	install -m 0644 ${UNPACKDIR}/asound.conf ${D}${sysconfdir}/asound.conf
}

FILES:${PN} = "${sysconfdir}/asound.conf"

COMPATIBLE_MACHINE = "luckfox-lyra"
