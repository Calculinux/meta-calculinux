SUMMARY = "PicoCalc Keyboard Test Utility"
DESCRIPTION = "SDL2-based keyboard test utility with visual feedback for the PicoCalc device"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

DEPENDS = "libsdl2 libsdl2-ttf"

SRC_URI = "file://picocalc-kbd-test.c \
           file://Makefile"

S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"

inherit pkgconfig

EXTRA_OEMAKE = "'CC=${CC}' 'CFLAGS=${CFLAGS} `pkg-config --cflags sdl2 SDL2_ttf`' 'LDFLAGS=${LDFLAGS}' 'LDLIBS=`pkg-config --libs sdl2 SDL2_ttf` -lm'"

do_compile() {
    cd ${S}
    oe_runmake
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/picocalc-kbd-test ${D}${bindir}/
}

FILES:${PN} = "${bindir}/picocalc-kbd-test"

RDEPENDS:${PN} = "libsdl2 libsdl2-ttf"

COMPATIBLE_MACHINE = "luckfox-lyra"
