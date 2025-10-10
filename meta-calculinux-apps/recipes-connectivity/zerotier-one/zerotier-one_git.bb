HOMEPAGE = "git://github.com/zerotier/ZeroTierOne"
SUMMARY = "Smart Programmable Ethernet Switch"
DESCRIPTION = "Connect team members from anywhere in the world on any device. \
ZeroTier creates secure networks between on-premise, cloud, desktop, and mobile devices. \
"

PV = "1.14.2+git${SRCREV_zerotier}"
SRCREV_zerotier = "185a3a2c76e6bf1b1c0415871f43076638eb007c"

SRC_URI = "\
    git://github.com/zerotier/ZeroTierOne.git;name=zerotier;nobranch=1;protocol=https\
    file://zerotier.service \
"

LICENSE = "BUSL-1.1"
LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=33322cad2f266673d999241243910f44"

S = "${UNPACKDIR}/git"

COMPATIBLE_HOST = '(x86_64.*|arm.*|aarch64.*)-linux'

RDEPENDS:${PN} += "kernel-module-tun"

INSANE_SKIP:${PN} = "ldflags"
inherit systemd pkgconfig

do_compile () {
    export CFLAGS="${CFLAGS} --sysroot=${STAGING_DIR_TARGET}"

    oe_runmake all
}

FILES:${PN} += " \
     ${systemd_system_unitdir}/zerotier-one.service \
"

do_install() {
    install -d ${D}${sbindir}
    install -m 755 zerotier-one ${D}${sbindir}
    ln zerotier-one ${D}${sbindir}/zerotier-cli
    ln zerotier-one ${D}${sbindir}/zerotier-idtool
    chown -R root:root ${D}${sbindir}/zerotier-cli
    install -d ${D}/var/lib/zerotier-one
    ln -s ../../..${sbindir}/zerotier-one ${D}/${localstatedir}/lib/zerotier-one/zerotier-one
    ln -s ../../..${sbindir}/zerotier-cli ${D}/${localstatedir}/lib/zerotier-one/zerotier-cli
    ln -s ../../..${sbindir}/zerotier-idtool ${D}/${localstatedir}/lib/zerotier-one/zerotier-idtool
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/zerotier.service ${D}${systemd_system_unitdir}
    install -d ${D}/var/lib/zerotier-one/networks.d/
}

SYSTEMD_SERVICE:${PN} = "zerotier.service"
