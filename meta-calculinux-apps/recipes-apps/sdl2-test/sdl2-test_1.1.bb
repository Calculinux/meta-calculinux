SUMMARY = "SDL2 Display Test Application for PicoCalc"
DESCRIPTION = "A comprehensive test application to validate SDL2 functionality on the PicoCalc DRM driver"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

DEPENDS = "libsdl2"

SRC_URI = "file://sdl2-test.c \
           file://sdl2-list-backends.c \
           file://sdl2-diagnose.sh \
           file://Makefile"

S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"

inherit pkgconfig

EXTRA_OEMAKE = "'CC=${CC}' 'CFLAGS=${CFLAGS} `pkg-config --cflags sdl2`' 'LDFLAGS=${LDFLAGS}' 'LDLIBS=`pkg-config --libs sdl2` -lm'"

do_compile() {
    cd ${S}
    oe_runmake
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/sdl2-test ${D}${bindir}/
    install -m 0755 ${S}/sdl2-list-backends ${D}${bindir}/
    install -m 0755 ${S}/sdl2-diagnose.sh ${D}${bindir}/sdl2-diagnose
}

FILES:${PN} = "${bindir}/sdl2-test ${bindir}/sdl2-list-backends ${bindir}/sdl2-diagnose"

RDEPENDS:${PN} = "libsdl2 bash"
