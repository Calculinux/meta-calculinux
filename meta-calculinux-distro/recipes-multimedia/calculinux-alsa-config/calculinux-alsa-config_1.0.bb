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
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bc8446122904814d2b6a5b659e73783841c"

PACKAGE_ARCH = "all"

SRC_URI = "file://asound.conf"

RDEPENDS:${PN} = "alsa-utils libasound2"

do_install() {
	install -d ${D}${sysconfdir}
	install -m 0644 ${WORKDIR}/asound.conf ${D}${sysconfdir}/asound.conf
}

FILES:${PN} = "${sysconfdir}/asound.conf"

COMPATIBLE_MACHINE = "luckfox-lyra"
