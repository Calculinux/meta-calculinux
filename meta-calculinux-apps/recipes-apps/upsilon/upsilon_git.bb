SUMMARY = "Upsilon graphing calculator firmware for Picocalc"
DESCRIPTION = "Upsilon is a fork of Omega, a user-made OS for NumWorks calculator, \
               adapted for the Picocalc device with enhanced features including \
               Kandinsky module, wallpapers, external apps, and Python improvements."
HOMEPAGE = "https://github.com/gurubook/Upsilon"
LICENSE = "CC-BY-NC-SA-4.0"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=91bec4f3756d037e29191d67b4737e63"

# Using upsilon-dev branch for now
# TODO: Switch to a stable release tag once available (e.g., SRCREV = "${AUTOREV}" and PV = "1.0+git${SRCPV}")
# Current releases at https://github.com/gurubook/Upsilon/releases are minimal
# Note: submodules=1 should fetch rpn and atomic apps, but may need manual initialization
PV = "1.0+git${SRCPV}"
SRC_URI = "git://github.com/gurubook/Upsilon.git;protocol=https;branch=upsilon-dev;submodules=1"
SRCREV = "${AUTOREV}"

# Pin to specific commit for reproducibility in production:
# SRCREV = "<commit-hash>"

S = "${WORKDIR}/git"

DEPENDS = " \
    libsdl2 \
    libpng \
    jpeg \
    freetype \
    freetype-native \
    libdrm \
    virtual/libgles2 \
    python3-native \
    imagemagick-native \
    pkgconfig-native \
"

# Upsilon's build system requires these
# For TOOLCHAIN=host-gcc with TARGET=picocalc, Upsilon builds a simulator binary
# Use bare compiler names to avoid Yocto's incompatible flags

# We have to override many variables to ensure proper cross-compilation since 
# the build system isn't designed to compile the simulator for a different target.
EXTRA_OEMAKE = " \
    PLATFORM=simulator \
    TARGET=picocalc \
    TOOLCHAIN=host-gcc \
    CC='${HOST_PREFIX}gcc' \
    CXX='${HOST_PREFIX}g++' \
    LD='${HOST_PREFIX}g++' \
    AR='${HOST_PREFIX}ar' \
    HOSTCC='${BUILD_CC}' \
    HOSTCXX='${BUILD_CXX}' \
    PYTHON='${STAGING_BINDIR_NATIVE}/python3-native/python3' \
    RASTERIZER_CFLAGS='-std=c99 -I${STAGING_INCDIR_NATIVE}/freetype2 -I${STAGING_INCDIR_NATIVE} -DGENERATE_PNG=1' \
    RASTERIZER_LDFLAGS='-L${STAGING_LIBDIR_NATIVE} -lfreetype -lpng16 -lz' \
    EPSILON_GETOPT=0 \
    EPSILON_TELEMETRY=0 \
"
# Upsilon uses its own Makefile build system
do_configure() {
    # Ensure submodules are properly initialized
    cd ${S}
    if [ ! -d "${S}/apps/external/rpn" ] || [ -z "$(ls -A ${S}/apps/external/rpn)" ]; then
        bbwarn "RPN submodule not found or empty, attempting to initialize"
        git submodule update --init --recursive || bbwarn "Failed to initialize submodules"
    fi
}

do_compile() {
    # Upsilon's Makefile expects to be run from the source directory
    cd ${S}
    
    # Export essential flags for cross-compilation without Yocto's problematic flags
    export CFLAGS="--sysroot=${STAGING_DIR_TARGET}"
    export CXXFLAGS="--sysroot=${STAGING_DIR_TARGET}"
    export LDFLAGS="--sysroot=${STAGING_DIR_TARGET}"
    
    oe_runmake ${EXTRA_OEMAKE} epsilon.bin
}

do_install() {
    install -d ${D}${bindir}
    install -d ${D}${datadir}/upsilon
    install -d ${D}${datadir}/applications
    
    # Install the compiled binary
    # The binary location depends on build configuration
    if [ -f ${S}/output/release/simulator/picocalc/epsilon.bin ]; then
        install -m 0755 ${S}/output/release/simulator/picocalc/epsilon.bin ${D}${bindir}/upsilon
    else
        bbwarn "Upsilon binary not found in expected location, trying alternate paths"
        # Try other possible locations
        find ${S}/output -name "epsilon.bin" -exec install -m 0755 {} ${D}${bindir}/upsilon \;
    fi
    
    # Install any additional resources/assets if needed
    # if [ -d ${S}/apps ]; then
    #     cp -r ${S}/apps ${D}${datadir}/upsilon/
    # fi
}

FILES:${PN} = " \
    ${bindir}/upsilon \
    ${datadir}/upsilon \
    ${datadir}/applications \
"

# Upsilon is a complex C++ application
INSANE_SKIP:${PN} += "ldflags"

# The build generates many intermediate files
# Avoid rm_work issues
RM_WORK_EXCLUDE += "${PN}"
