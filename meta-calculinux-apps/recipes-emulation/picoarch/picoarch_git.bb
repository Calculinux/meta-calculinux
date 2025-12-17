SUMMARY = "Picoarch - a libretro frontend designed for small screens and low power"
DESCRIPTION = "Picoarch uses libpicofe and SDL to create a small frontend to libretro cores. \
It is designed for small screen, low-powered devices like the PicoCalc."
HOMEPAGE = "https://github.com/gurubook/picoarch"
SECTION = "emulation"
LICENSE = "BSD-3-Clause & GPL-2.0-or-later & LGPL-2.1-or-later"
LIC_FILES_CHKSUM = "file://LICENSE;md5=cf9f0edc6d0921306fabede20ebb4306"

SRC_URI = "gitsm://github.com/gurubook/picoarch.git;protocol=https;branch=feature/calculinux"
SRCREV = "8cea7b4e965300c33dde29197180f65c47b2b0b4"

S = "${WORKDIR}/git"

DEPENDS = " \
    alsa-lib \
    libpng \
    libsdl \
    zlib \
"

inherit pkgconfig

# Disable LTO as it can cause issues with the embedded libpicofe
# Use -Wa,-mimplicit-it=thumb to allow conditional instructions in Thumb mode without explicit IT blocks
# ARM_INSTRUCTION_SET = "arm" would switch to ARM mode but adds interworking overhead
# Pass the assembler flag via TARGET_CFLAGS to allow Makefile's CFLAGS += to work properly
# Don't override LDFLAGS - let Makefile add SDL/ALSA libs via pkg-config
TARGET_CFLAGS:append = " -Wa,-mimplicit-it=thumb"
EXTRA_OEMAKE = "CC='${CC}'"

do_configure() {
    # Apply libpicofe patches
    if [ -f ${S}/libpicofe/.patched ]; then
        bbnote "libpicofe already patched"
    else
        cd ${S}
        for patch in $(find patches/libpicofe -name "*.patch" 2>/dev/null | sort); do
            bbnote "Applying patch: $patch"
            cd ${S}/libpicofe
            patch --no-backup-if-mismatch --merge -p1 < ${S}/$patch || bbwarn "Patch $patch failed to apply"
            cd ${S}
        done
        touch ${S}/libpicofe/.patched
    fi
}

do_compile() {
    cd ${S}
    oe_runmake picoarch
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/picoarch ${D}${bindir}/picoarch
    
    # Create directories for config and save data
    install -d ${D}${datadir}/picoarch/system
}

RDEPENDS:${PN} = " \
    alsa-lib \
    libsdl \
    libpng \
    zlib \
"

FILES:${PN} += "${datadir}/picoarch"

# The upstream Makefile strips the binary with -s, so skip this QA check
INSANE_SKIP:${PN} += "already-stripped"
