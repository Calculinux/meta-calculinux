SUMMARY = "PCSX-ReARMed standalone PlayStation emulator"
DESCRIPTION = "Sony PlayStation emulator (PCSX ReARMed) built with its own \
SDL 1.2/libpicofe standalone frontend, aimed at devices without a full \
window manager. For a libretro core usable from picoarch or RetroArch, \
see the pcsx-rearmed-libretro package."

HOMEPAGE = "https://github.com/libretro/pcsx_rearmed"

# core: GPL-2.0; libpicofe: GPL-2.0-or-later | LGPL-2.1-or-later; vendored
# deps: lightrec (GPL-3.0, lightrec dynarec platforms only), lightning/libchdr
# (MIT), zstd (BSD-3-Clause)
LICENSE = "GPL-2.0-or-later | LGPL-2.1-or-later | GPL-3.0-or-later | MIT | BSD-3-Clause"
LIC_FILES_CHKSUM = " \
    file://COPYING;md5=5dd99a4a14d516c44d0779c1e819f963 \
    file://${COMMON_LICENSE_DIR}/LGPL-2.1-or-later;md5=2a4f4fd2128ea2f65047ee63fbca9f68 \
    file://${COMMON_LICENSE_DIR}/GPL-3.0-or-later;md5=1c76c4cc354acaac30ed4d5eefea7245 \
    file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302 \
    file://${COMMON_LICENSE_DIR}/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9 \
"

# Kept in sync with the pin used by pcsx-rearmed-libretro so both builds
# track the same commit. The same tree is reused: that recipe selects the
# libretro platform, this one the classic standalone frontend.
PV = "2024.10+git61745af67e9645b45e153d4347ace8531934c9f0"
SRC_URI = " \
    gitsm://github.com/libretro/pcsx_rearmed.git;protocol=https;branch=master \
    file://0001-store-emulator-state-in-home-directory.patch \
    file://0002-libpicofe-add-packaged-skin-directory-fallback.patch \
    file://pcsx.sh \
"
SRCREV = "61745af67e9645b45e153d4347ace8531934c9f0"
S = "${WORKDIR}/git"

SECTION = "emulators"

DEPENDS = " \
    alsa-lib \
    libpng \
    libsdl \
    zlib \
"
RDEPENDS:${PN} = " \
    alsa-lib \
    libpng \
    libsdl \
    zlib \
"

# The ari64 dynarec neither generates nor patches Thumb code, and
# configure only appends -marm if it can probe __thumb__ itself. Force ARM
# instruction set for the whole unit on arm32 so every object stays
# consistent (the core recipe relies on the same property).
ARM_INSTRUCTION_SET:arm32 = "arm"

# explicit list: configure honours alsa/pulseaudio/oss checks from it and
# the Makefile adds the SDL audio out.o from SOUND_DRIVERS; "sdl" is safe
# because the generic platform links SDL for video/input anyway
PCSX_SOUND_DRIVERS ?= "alsa sdl"

PCSX_DYNAREC ?= "none"
PCSX_DYNAREC:arm32 = "ari64"
PCSX_DYNAREC:arm64 = "ari64"
PCSX_DYNAREC:x86-64 = "lightrec"
PCSX_DYNAREC:x86 = "lightrec"

# Same GPU preference as pcsx-rearmed-libretro: neon where the tune has it,
# otherwise the peops software renderer
PCSX_BUILTIN_GPU ?= "${@bb.utils.contains('TUNE_FEATURES', 'neon', 'neon', 'peops', d)}"

do_configure() {
    # sdl-config is the shell script from the target staging dir; configure
    # only shells out to it to query include/lib flags, which is exactly
    # what a cross build needs
    SDL_CONFIG="${STAGING_DIR_TARGET}${bindir}/sdl-config" \
    ./configure \
        --gpu="${PCSX_BUILTIN_GPU}" \
        --dynarec="${PCSX_DYNAREC}" \
        --sound-drivers="${PCSX_SOUND_DRIVERS}"
}

# 'target_' builds just the pcsx binary. The recursive plugin targets
# (swappable gpu/spunull .so files) are intentionally skipped: the chosen
# GPU and the DFX sound engine are compiled straight into the binary, and
# shipping orphan plugins serves no purpose on this platform.
do_compile() {
    oe_runmake target_
}

do_install() {
    # libpicofe resolves the skin next to the executable, so the binary and
    # its skin share one directory (mirrors how picoarch pairs
    # run_picoarch.sh with picoarch.bin); /usr/bin carries the launcher.
    install -d ${D}${datadir}/pcsx_rearmed
    install -m 0755 ${S}/pcsx ${D}${datadir}/pcsx_rearmed/pcsx.bin
    install -m 0755 ${WORKDIR}/pcsx.sh ${D}${datadir}/pcsx_rearmed/pcsx
    install -d ${D}${datadir}/pcsx_rearmed/skin
    install -m 0644 ${S}/frontend/pandora/skin/*.png ${D}${datadir}/pcsx_rearmed/skin/

    install -d ${D}${bindir}
    ln -sf ${datadir}/pcsx_rearmed/pcsx ${D}${bindir}/pcsx
}

FILES:${PN} = "${bindir}/pcsx ${datadir}/pcsx_rearmed"
