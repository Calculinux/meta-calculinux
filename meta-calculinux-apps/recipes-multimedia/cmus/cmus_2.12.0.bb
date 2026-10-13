SUMMARY = "Keyboard-driven curses console music player"
DESCRIPTION = "cmus is a small, fast and powerful console music player. \
It organises music into on-disk libraries, smart playlists and a play \
queue, with tag editing, seeking, gapless playback, replay gain and \
shuffling. Input formats and audio sinks are loadable plugins, keeping \
the core binary small. It is driven entirely from the keyboard, which \
fits the PicoCalc's compact hardware keyboard, and scales down to the \
~53 column grid of the cruft framebuffer terminal."
HOMEPAGE = "https://cmus.github.io"
LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=b234ee4d69f5fce4486a80fdaf4a4263"
SECTION = "console/media"

# git protocol (rather than an archive download) is mandatory here: the
# distro QA check src-uri-bad rejects unstable codeload archive URLs.
# Pinned to tag v2.12.0.
SRC_URI = "git://github.com/cmus/cmus.git;protocol=https;branch=master"
SRCREV = "58d34cf9db5c29e01a985a48a9b6947855cb6cc9"

S = "${WORKDIR}/git"

# Upstream builds with a hand-rolled ./configure (scripts/configure.sh):
# plain KEY=value arguments, per-plugin pkg-config probes, and it honours
# the environment-supplied CC/CFLAGS/LDFLAGS and pkg-config on PATH, so
# no autotools class is needed - we drive the Makefile directly.
# pkgconfig-NATIVE: probes run on the build host, and a bare "pkgconfig"
# dependency would resolve to a target-arch build that cannot execute here.
DEPENDS = "ncurses pkgconfig-native"

# Loadable input plugins (${libdir}/cmus/ip/*.so) and audio sinks
# (${libdir}/cmus/op/*.so). The codec dependency in the third
# PACKAGECONFIG field lands in BOTH DEPENDS (needed for the build-time
# pkg-config probes) and RDEPENDS (plugins are loaded with dlopen(), so
# the codec libs never show up in the cmus binary's link-time deps and
# opkg would not pull them in without this).
PACKAGECONFIG ??= "alsa mad flac vorbis opus"
PACKAGECONFIG[alsa]   = "CONFIG_ALSA=y,CONFIG_ALSA=n,alsa-lib"
PACKAGECONFIG[mad]    = "CONFIG_MAD=y,CONFIG_MAD=n,libmad"
PACKAGECONFIG[flac]   = "CONFIG_FLAC=y,CONFIG_FLAC=n,flac"
PACKAGECONFIG[vorbis] = "CONFIG_VORBIS=y,CONFIG_VORBIS=n,libvorbis libogg"
PACKAGECONFIG[opus]   = "CONFIG_OPUS=y,CONFIG_OPUS=n,opusfile"

# Pins for sinks and services that make no sense on the PicoCalc, forced
# off in case their pkg-config probes ever find something in the staged
# sysroot: MPRIS wants a desktop D-Bus session, FFMPEG would bloat a
# 128 MiB box, discid/cdio/cddb presume an optical drive, and the rest
# are alternate audio APIs (or Android/macOS backends) with no device
# counterpart.
EXTRA_CONF_ARGS = "\
    CONFIG_AO=n \
    CONFIG_ARTS=n \
    CONFIG_CDDB=n \
    CONFIG_CDIO=n \
    CONFIG_COREAUDIO=n \
    CONFIG_DISCID=n \
    CONFIG_FFMPEG=n \
    CONFIG_JACK=n \
    CONFIG_MIKMOD=n \
    CONFIG_MODPLUG=n \
    CONFIG_MP4=n \
    CONFIG_MPC=n \
    CONFIG_MPRIS=n \
    CONFIG_PULSE=n \
    CONFIG_ROAR=n \
    CONFIG_SAMPLERATE=n \
    CONFIG_SNDIO=n \
    CONFIG_SUN=n \
    CONFIG_TREMOR=n \
    CONFIG_VTX=n \
    CONFIG_WAVEPACK=n \
"

# WAV and CUE support is self-contained (no external decoder library),
# keep it enabled unconditionally.
#
# The bare PACKAGECONFIG variable only holds the list of option NAMES;
# no class translates the per-option arguments for us (autotools does
# that internally), so lift each enabled option's argument out of its
# PACKAGECONFIG:<opt> entry explicitly. Disabled options safely stay
# off: their dependency drops out of DEPENDS too, so configure's
# pkg-config auto-probes cannot find the codec in the staged sysroot.
CONFIGURE_ARGS_PACKAGECONFIG = "\
    ${@' '.join(((d.getVar('PACKAGECONFIG:%s' % pc) or ',,,').split(',')[0]) \
                 for pc in (d.getVar('PACKAGECONFIG') or '').split())} \
"

do_configure() {
    # Upstream's ./configure probes the toolchain via "check_program $CC"
    # (scripts/checks.sh) - an unquoted expansion that word-splits Yocto's
    # composite compiler variable (<cross-gcc> + tune/security flags +
    # --sysroot=...) into a dozen tokens and aborts with "expecting 1-2
    # arguments". Wrap the effective $CC in a throwaway launcher so
    # configure sees an ordinary one-word compiler; the wrapper forwards
    # to the original command verbatim, sysroot and all.
    WRAP="${WORKDIR}/cc-wrapper/cc"
    install -d ${WORKDIR}/cc-wrapper
    {
        echo "#!/bin/sh"
        printf 'exec %s "$@"\n' "$CC"
    } > ${WRAP}
    chmod 0755 ${WRAP}

    # LD is exported by the build environment as "<cross-ld> --sysroot=...",
    # which happens to pass check_program's 1-2 token limit with the
    # sysroot silently dropped - leaving the bare ld to choke on the
    # GCC-driver flags in LDFLAGS. Point it at the same wrapper: linking
    # through the compiler driver is what upstream intends (check_cc's
    # own default is LD=$CC) and what LDFLAGS was formatted for.
    #
    # The plugin probes ask pkg-config for ALSA_LIBS etc., but nothing in
    # the task environment tells a PATH-visible pkg-config where the
    # staged .pc files live. Advertise the target sysroot explicitly.
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:+${PKG_CONFIG_PATH}:}${RECIPE_SYSROOT}/usr/lib/pkgconfig"
    # GNU install-directory variables (docdir, exampledir, ...) are also
    # exported into the task environment, and configure's var_default()
    # keeps pre-existing values - so upstream's ${datadir}/doc/cmus
    # defaults would never win. Pass the intended values explicitly.
    ${S}/configure \
        CC=${WRAP} \
        LD=${WRAP} \
        PKG_CONFIG=pkg-config \
        --prefix=${prefix} \
        --bindir=${bindir} \
        --libdir=${libdir} \
        --datadir=${datadir} \
        --mandir=${mandir} \
        docdir=${datadir}/doc/${BPN} \
        exampledir=${datadir}/doc/${BPN}/examples \
        DEBUG=0 \
        CONFIG_WAV=y \
        CONFIG_CUE=y \
        ${CONFIGURE_ARGS_PACKAGECONFIG} \
        ${EXTRA_CONF_ARGS}
}

do_compile() {
    oe_runmake
}

do_install() {
    # The in-tree install helper (scripts/install) prefixes $(DESTDIR)
    # onto every destination, so the usual image-staging applies.
    oe_runmake install DESTDIR=${D}
}

# PACKAGES is a single main package - there is no -dbg package to absorb
# the debug-info extraction that do_package performs (splitdebuginfo
# writes .debug files into the package tree after the D copy), so inhibit
# it. The binaries are still stripped; a 128 MiB handheld gains little
# from shipping ~200 KiB of debug info for two small C binaries anyway,
# and developers can rebuild for debugging.
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"

# No headers, pkgconfig files or translations to split out; the plugins
# travel with the main binary in a single package.
PACKAGES = "${PN}"
FILES:${PN} = "\
    ${bindir}/cmus \
    ${bindir}/cmus-remote \
    ${libdir}/cmus/ \
    ${datadir}/cmus/ \
    ${datadir}/doc/cmus/ \
    ${mandir}/man1 \
    ${mandir}/man7 \
"
