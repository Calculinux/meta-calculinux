DESCRIPTION = "Basilisk II — 680x0 Apple Macintosh emulator (build from macemu)"
HOMEPAGE = "https://github.com/kanjitalk755/macemu"
SECTION = "emulator"
LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://BasiliskII/COPYING;md5=0636e73ff0215e8d672dc4c32c317bb3"

PN = "basilisk-ii"
PV = "1.0+git${SRCPV}"

SRC_URI = "git://github.com/kanjitalk755/macemu;protocol=https;branch=master \
           file://0001-fix-tun-tap-check.patch \
           file://0003-fix-register-keyword.patch \
           file://0004-fix-sscanf-format.patch \
        "
SRCREV = "ac3273276215ffb3d0e40c8ed2e86f60882ec04d"

# The macemu repository contains multiple emulators. Basilisk II's Unix port
# lives in 'BasiliskII/src/Unix' in this upstream repo — set S to the git root
# so patches can be applied to files in different subdirectories.
S = "${WORKDIR}/git"

DEPENDS = "libsdl2 libpng jpeg zlib alsa-lib gmp mpfr autoconf-native automake-native libtool-native pkgconfig-native"
HOSTTOOLS += "gcc g++"

# Build without X11 support by default for this device. Some macemu forks
# provide configure flags to disable X11; we'll pass a conservative flag and
# users can adjust if upstream uses a different option.
EXTRA_OECONF = "--disable-x11 --enable-sdl-video --enable-sdl-sound --disable-macosx-gui --disable-macosx-sound"

inherit pkgconfig

BB_NO_NETWORK = "0"

# Try to be flexible: if an autotools ./configure exists, use it. Otherwise
# fallback to direct make in the source directory. We'll patch after an initial
# build attempt if cross-compilation issues appear.
python __anonymous() {
    import os
    s = d.getVar('S')
    if not os.path.isdir(s):
        bb.warn('Directory %s does not exist in fetched sources; check upstream layout.' % s)
}

do_configure() {
    bbnote "Configuring Basilisk II (best-effort scaffold)"
    cd ${S}/BasiliskII/src/Unix
    if [ -f "configure.ac" ]; then
        # Replace obsolete autoconf macros that attempt to run test programs
        # (AC_TRY_*) with their modern equivalents which are cross-compile
        # friendly (AC_RUN_IFELSE/AC_COMPILE_IFELSE/AC_LINK_IFELSE). Doing
        # this here avoids creating a permanent patch file while we iterate.
        bbnote "Patching configure.ac for cross-compile friendly macros"
        sed -i 's/AC_TRY_RUN/AC_RUN_IFELSE/g' configure.ac || true
        sed -i 's/AC_TRY_COMPILE/AC_COMPILE_IFELSE/g' configure.ac || true
        sed -i 's/AC_TRY_LINK/AC_LINK_IFELSE/g' configure.ac || true
        # Fix utils_macosx.mm inclusion for non-macOS
        sed -i 's/EXTRASYSSRCS="\$EXTRASYSSRCS \.\.\/MacOSX\/utils_macosx\.mm"/case "\$target_os" in darwin*) EXTRASYSSRCS="\$EXTRASYSSRCS ..\/MacOSX\/utils_macosx.mm" ;; esac/' configure.ac || true
        # Fix clip_macosx inclusion for non-macOS SDL video
        sed -i 's/EXTRASYSSRCS="\$EXTRASYSSRCS \.\.\/MacOSX\/clip_macosx\.cpp"/case "\$target_os" in darwin*) EXTRASYSSRCS="\$EXTRASYSSRCS ..\/MacOSX\/clip_macosx.cpp" ;; *) EXTRASYSSRCS="\$EXTRASYSSRCS ..\/dummy\/clip_dummy.cpp" ;; esac/' configure.ac || true
        sed -i 's/EXTRASYSSRCS="\$EXTRASYSSRCS \.\.\/MacOSX\/clip_macosx64\.mm \.\.\/pict\.c"/case "\$target_os" in darwin*) EXTRASYSSRCS="\$EXTRASYSSRCS ..\/MacOSX\/clip_macosx64.mm ..\/pict.c" ;; *) EXTRASYSSRCS="\$EXTRASYSSRCS ..\/dummy\/clip_dummy.cpp" ;; esac/' configure.ac || true
    fi

    if [ -x "autogen.sh" ]; then
        bbnote "Running autogen.sh to generate configure"
        NO_CONFIGURE=true ./autogen.sh

        export ac_cv_tun_tap_support=yes
        export ac_cv_type_socklen_t=yes
        export ac_cv_c_float_format='IEEE (little-endian)'
        export ac_cv_gcc_mdynamic_no_pic=no
        export ac_cv_have_extended_signals=yes
        export SDL_CFLAGS="`pkg-config --cflags sdl2`"
        export SDL_LIBS="`pkg-config --libs sdl2`"

        ./configure --host=${TARGET_SYS} --build=${BUILD_SYS} --prefix=${prefix} ${EXTRA_OECONF}

        # Handle cross-compilation: use host-built generators for CPU code generation
        sed -i 's#cpudefs\.cpp: $(OBJ_DIR)/build68k$(EXEEXT) \./$(UAE_PATH)/table68k#cpudefs.cpp: obj/host-tools/build68k-host ./$(UAE_PATH)/table68k#' Makefile
        sed -i 's#$(OBJ_DIR)/build68k$(EXEEXT) <\./$(UAE_PATH)/table68k >cpudefs\.cpp#obj/host-tools/build68k-host <./$(UAE_PATH)/table68k >$@#' Makefile
        sed -i 's#^cpuemu\.cpp: $(OBJ_DIR)/gencpu$(EXEEXT)#cpuemu.cpp: obj/host-tools/gencpu-host#' Makefile
        sed -i $'s#^\t$(OBJ_DIR)/gencpu$(EXEEXT)#\tobj/host-tools/gencpu-host#' Makefile
        sed -i 's#^compemu\.cpp: $(OBJ_DIR)/gencomp$(EXEEXT)#compemu.cpp: obj/host-tools/gencomp-host#' Makefile
        sed -i $'s#^\t$(OBJ_DIR)/gencomp$(EXEEXT)#\tobj/host-tools/gencomp-host#' Makefile
    else
        bbnote "No autogen.sh script found; skipping configure step"
    fi
}

do_configure:append() {
    # Strip macOS-specific frameworks that break cross-linking on Linux
    for framework in AppKit Carbon IOKit CoreFoundation Metal; do
        sed -i "s/ -framework ${framework}//g" ${S}/BasiliskII/src/Unix/Makefile
    done
}

do_compile:prepend() {
    bbnote "Preparing host-side CPU generators"
    cd ${S}/BasiliskII/src/Unix
    mkdir -p obj/host-tools

    host_cppflags="-I. -I.. -I../include -I../CrossPlatform -I../uae_cpu_2021 -I../uae_cpu_2021/compiler -I../slirp"
    host_defs="-DHAVE_CONFIG_H -DOS_linux -DDIRECT_ADDRESSING -DFPU_MPFR -DUPDATE_UAE -D_REENTRANT -DDATADIR=\"/usr/share/BasiliskII\""
    host_cc="${BUILD_CC}"
    host_cxx="${BUILD_CXX:-${BUILD_CC}}"

    ${host_cc} ${host_cppflags} ${host_defs} ${BUILD_CFLAGS} -c ../uae_cpu_2021/build68k.c -o obj/host-tools/build68k-host.o
    ${host_cc} ${BUILD_LDFLAGS} -o obj/host-tools/build68k-host obj/host-tools/build68k-host.o

    obj/host-tools/build68k-host < ../uae_cpu_2021/table68k > cpudefs.cpp

    ${host_cxx} ${host_cppflags} ${host_defs} ${BUILD_CXXFLAGS:-${BUILD_CFLAGS}} -c cpudefs.cpp -o obj/host-tools/cpudefs-host.o
    ${host_cxx} ${host_cppflags} ${host_defs} ${BUILD_CXXFLAGS:-${BUILD_CFLAGS}} -c ../uae_cpu_2021/readcpu.cpp -o obj/host-tools/readcpu-host.o

    ${host_cc} ${host_cppflags} ${host_defs} ${BUILD_CFLAGS} -c ../uae_cpu_2021/gencpu.c -o obj/host-tools/gencpu-host.o
    ${host_cxx} ${BUILD_LDFLAGS} -o obj/host-tools/gencpu-host obj/host-tools/gencpu-host.o obj/host-tools/readcpu-host.o obj/host-tools/cpudefs-host.o

    ${host_cc} ${host_cppflags} ${host_defs} ${BUILD_CFLAGS} -c ../uae_cpu_2021/compiler/gencomp.c -o obj/host-tools/gencomp-host.o
            ${host_cxx} ${BUILD_LDFLAGS} -o obj/host-tools/gencomp-host obj/host-tools/gencomp-host.o obj/host-tools/readcpu-host.o obj/host-tools/cpudefs-host.o
}

        obj/host-tools/gencpu-host
        obj/host-tools/gencomp-host
    fi
}

do_compile() {
    bbnote "Compiling Basilisk II"
    cd ${S}/BasiliskII/src/Unix
    oe_runmake
}

do_install() {
    bbnote "Installing Basilisk II binary"
    install -d ${D}${bindir}
    install -m 0755 ${S}/BasiliskII/src/Unix/BasiliskII ${D}${bindir}/basilisk-ii
}

FILES_${PN} = "${bindir}/basilisk-ii"

RDEPENDS_${PN} = ""

# Notes for next steps:
# - Inspect the fetched git tree to determine the correct build directory (S).
# - Add patches to support cross-compilation (use HOST/BUILD tools separation,
#   ensure native build tools are built or avoided, fix hardcoded CC flags).
# - Replace the AUTOREV with a pinned SRCREV once testing a commit that builds.
