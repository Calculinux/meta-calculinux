SUMMARY = "DOSBox-X - A cross-platform DOS emulator based on the DOSBox project"
DESCRIPTION = "Like DOSBox, it emulates a PC necessary for running many  \
MS-DOS games and applications that simply cannot be run on modern PCs and \
operating systems. It also emulates the environments to run Windows 3.x, 9x \
and ME and software written for those versions of Windows."
HOMEPAGE = "https://dosbox-x.com"
SECTION = "emulation"
# PD: the X11 misc-fixed 4x6 font used as the default TTF output font
LICENSE = "GPL-2.0-or-later & PD"
LIC_FILES_CHKSUM = " \
    file://COPYING;md5=13df4b3611f08fada0e7fa65465a92cc \
    file://${UNPACKDIR}/font-misc-misc-1.1.2/COPYING;md5=200c507f595ee97008c7c5c3e94ab9a8 \
"

# Needs a patch to detect 32-bit ARM when the cpu is just reported as "arm" by the system
SRC_URI = " \
    git://github.com/joncampbell123/dosbox-x.git;protocol=https;branch=master;tag=dosbox-x-v${PV} \
    file://0001-configure-detect-32-bit-ARM-when-host_cpu-is-arm.patch \
    file://0002-Install-generated-metainfo-from-the-build-directory.patch \
    file://0003-Default-to-8-dot-text-no-doublescan-and-4-3-aspect.patch \
    file://0004-Default-to-TTF-output-with-a-4x6-bitmap-font.patch \
    https://www.x.org/releases/individual/font/font-misc-misc-1.1.2.tar.bz2;name=font \
"
SRC_URI[font.sha256sum] = "b8e77940e4e1769dc47ef1805918d8c9be37c708735832a07204258bacc11794"
SRCREV = "4f19017c5f565dc40d01fede0f1382892e7243d7"


# needed because the upstream project uses a non-standard Git tag format for releases
UPSTREAM_CHECK_GITTAGREGEX = "dosbox-x-v(?P<pver>\d+(\.\d+)+)$"

DEPENDS = "libsdl2 libpng zlib ncurses"

inherit autotools pkgconfig bash-completion

# The PicoCalc display is an SPI panel driven by SDL2's kmsdrm/fbcon backends
# (see the libsdl2 bbappend): no X11, no GPU. Leave out the bundled SDL1 and
# the OpenGL/ffmpeg paths so configure can't pick them up from the sysroot.
EXTRA_OECONF = " \
    --enable-debug \
    --enable-sdl2 \
    --disable-x11 \
    --disable-opengl \
    --disable-avcodec \
"

# The Lyra tune defaults to Thumb-2. Build in ARM mode instead: ESFMu's ARM
# inline asm runs out of registers in Thumb-2 ("impossible constraints"), and
# the emulator's hot loops don't benefit from Thumb's smaller code.
ARM_INSTRUCTION_SET = "arm"

PACKAGECONFIG ??= "alsa freetype"

PACKAGECONFIG[alsa] = "--enable-alsa-midi,--disable-alsa-midi,alsa-lib"
# TrueType text-mode output (output=ttf), handy for readable DOS text on a
# small screen.
PACKAGECONFIG[freetype] = "--enable-freetype,--disable-freetype,freetype"
PACKAGECONFIG[fluidsynth] = "--enable-libfluidsynth,--disable-libfluidsynth,fluidsynth"
# Userspace TCP/IP for the emulated NE2000 (backend=slirp).
PACKAGECONFIG[slirp] = "--enable-libslirp,--disable-libslirp,libslirp"
# Configure treats any --enable-sdlnet/--disable-sdlnet as "disable", so only
# pass it when turning the modem/IPX emulation off.
PACKAGECONFIG[sdl-net] = ",--disable-sdlnet,libsdl2-net"
# No configure switch: ethernet pass-through is enabled whenever libpcap is
# in the sysroot.
PACKAGECONFIG[pcap] = ",,libpcap"

do_install:append() {
    install -m 0644 ${UNPACKDIR}/font-misc-misc-1.1.2/4x6.bdf ${D}${datadir}/dosbox-x/4x6.bdf
}

# The CJK fonts (WenQuanYi bitmaps and Sarasa Gothic) are ~25 MB and only
# needed for DOS/V, PC-98 and other DBCS modes.
PACKAGES =+ "${PN}-cjk-fonts"
FILES:${PN}-cjk-fonts = " \
    ${datadir}/dosbox-x/wqy_*.bdf \
    ${datadir}/dosbox-x/SarasaGothicFixed.ttf \
"
FILES:${PN} += " \
    ${datadir}/dosbox-x \
    ${datadir}/icons \
    ${datadir}/metainfo \
"
