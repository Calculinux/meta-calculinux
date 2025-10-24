SUMMARY = "HP48 emulator based on x48"
DESCRIPTION = "x48ng is a reboot of the x48 HP 48 calculator emulator. \
It supports HP 48SX, GX, and G+ calculators with both text-based ncurses interface and SDL graphics."
HOMEPAGE = "https://github.com/gwenhael-le-moine/x48ng"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=de11de89f591f82e0bdfa58b63169f28"

inherit pkgconfig

SRCREV = "001fca1260049ba7d726b5f9180f44ac1f9ee10b"
SRC_URI = "git://github.com/hpsaturn/x48ng;protocol=https;branch=main"

S = "${WORKDIR}/git"

DEPENDS = "ncurses readline lua libsdl2"

# Enable SDL support, disable X11
EXTRA_OEMAKE = "\
    WITH_X11=no \
    WITH_SDL2=yes \
    HAS_X11=0 \
    PREFIX=${prefix} \
    CC='${CC}' \
    CFLAGS='${CFLAGS} -O0 -rdynamic -fno-stack-protector -z execstack -D_FILE_OFFSET_BITS=64 -Wno-absolute-value -Wno-sign-compare' \
    LDFLAGS='${LDFLAGS}' \
    PKG_CONFIG_SYSROOT_DIR='${PKG_CONFIG_SYSROOT_DIR}' \
    PKG_CONFIG_PATH='${PKG_CONFIG_PATH}' \
"

do_configure[noexec] = "1"

do_compile() {
    oe_runmake ${EXTRA_OEMAKE}
}

do_install() {
    # Install binary
    install -d ${D}${bindir}
    install -m 0755 ${S}/dist/x48ng ${D}${bindir}/x48ng
    
    # Install icon and ROMs
    install -d ${D}${datadir}/x48ng
    install -m 0644 ${S}/dist/hplogo.png ${D}${datadir}/x48ng/hplogo.png
    
    # Install ROMs
    cp -R ${S}/dist/ROMs/ ${D}${datadir}/x48ng/
}

FILES:${PN} += "${datadir}/x48ng"

RDEPENDS:${PN} = "ncurses readline lua libsdl2"
