SUMMARY = "Bluetooth audio ALSA backend (BlueALSA)"
DESCRIPTION = "BlueALSA extends the BlueZ 5 stack with Bluetooth audio features: \
A2DP sink/source (SBC, aptX, aptX-HD, LDAC and Opus codecs), HFP/HSP telephony, \
ALSA PCM/CTL plugins (bluealsa:<mac>) and the bluealsa-aplay streaming tool. \
This is release 5.0.0: the daemon binary is bluealsad and the control tool is \
bluealsactl (bluealsa/bluealsa-cli in releases <= 4.3.1)."
HOMEPAGE = "https://github.com/arkq/bluez-alsa"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=8e621f51a0d6b9221389a66da5118183"

# The release tag v5.0.0 (2026-08-27) on master.
SRC_URI = "git://github.com/arkq/bluez-alsa.git;protocol=https;branch=master"
SRCREV = "1935d6dcb8975f2d7a51aaafe61538d157224623"
S = "${WORKDIR}/git"

inherit autotools pkgconfig systemd

DEPENDS = " \
    alsa-lib \
    bluez5 \
    dbus \
    glib-2.0 \
    glib-2.0-native \
    python3-packaging-native \
    sbc \
"

# glib-2.0-native stages gdbus-codegen (invoked through the project's own
# src/dbus/dbus-codegen.py wrapper), which needs a host python3 with the
# `packaging` module available (python3-packaging-native).

# aptX / aptX-HD: use libfreeaptx, the LGPL fork of the openaptx 0.2.0
# line. Upstream also supports the Qualcomm-API openaptx (>= 2.0.0), which
# this tree does not carry.
PACKAGECONFIG[aptx] = "--enable-aptx --with-libfreeaptx,--disable-aptx,libfreeaptx,libfreeaptx"
PACKAGECONFIG[aptx-hd] = "--enable-aptx-hd --with-libfreeaptx,--disable-aptx-hd,libfreeaptx,libfreeaptx"
# LDAC: the publicly available ldacBT library (the AOSP encoder) provides
# encoding only, so bluez-alsa acts as LDAC source (outbound to headsets and
# speakers); inbound A2DP negotiation falls back to the other codecs.
PACKAGECONFIG[ldac] = "--enable-ldac,--disable-ldac,ldacbt,ldacbt"
PACKAGECONFIG[opus] = "--enable-opus,--disable-opus,libopus,libopus"
PACKAGECONFIG[systemd] = "--enable-systemd,--disable-systemd"

PACKAGECONFIG ??= " \
    aptx \
    aptx-hd \
    ldac \
    opus \
    systemd \
"

# v5.0.0 dropped the systemd pkg-config probe, so pass the unit directory
# explicitly; an empty SYSTEMD_SYSTEM_UNIT_DIR would silently install the
# units outside of ${D}.
EXTRA_OECONF = "--with-systemdsystemunitdir=${systemd_system_unitdir}"

# The D-Bus interface codegen rules in src/Makefile.am write to relative
# paths (dbus/org.*.h|.c) that only exist in-tree; in the autotools
# class' default VPATH layout the build tree has no dbus/ directory and
# every codegen unit fails. Upstream builds in-tree itself (README), so do
# the same.
B = "${S}"

# libtool leaves *.la bookkeeping files next to the installed ALSA plugins;
# they serve no purpose on the target.
do_install:append() {
	rm -f ${D}${libdir}/alsa-lib/*.la
}

# Prepend the plugins package in front of the default list (so its FILES
# win over ${PN}) while keeping ${PN}-dbg & friends in the list: the debug
# splitter synthesizes .debug/ trees that only the -dbg package can take.
PACKAGES:prepend = "${PN}-plugins "

# ALSA PCM/CTL plugins and the 20-bluealsa.conf fragment; for alsa-lib
# >= 1.1.7 the fragment is installed under ${datadir}/alsa/alsa.conf.d and
# symlinked into the ALSA add-on directory (${sysconfdir}/alsa/conf.d).
FILES:${PN}-plugins = " \
    ${libdir}/alsa-lib \
    ${datadir}/alsa \
    ${sysconfdir}/alsa \
"

# D-Bus activation policy and interface XML, plus the systemd units
# (enablement is performed by the class-generated postinst).
FILES:${PN} += " \
    ${datadir}/dbus-1 \
    ${systemd_system_unitdir} \
"

# Talks to bluetoothd over D-Bus; nothing on the link line exposes this.
RDEPENDS:${PN} += "bluez5"

SYSTEMD_SERVICE:${PN} = "bluealsa.service bluealsa-aplay.service"
