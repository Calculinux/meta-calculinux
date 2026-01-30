# Fix for GCC 14.3.0 linking errors in cross-compiler build
# The issue: libbackend.a is missing RTL object files needed for cc1/cc1plus linking
# Root cause: all-host target in Poky only runs configure-gcc, not the full all-gcc
# Solution: Override do_compile to build complete host components including all-gcc

do_compile () {
    export CC="${BUILD_CC}"
    export AR_FOR_TARGET="${TARGET_SYS}-ar"
    export RANLIB_FOR_TARGET="${TARGET_SYS}-ranlib"
    export LD_FOR_TARGET="${TARGET_SYS}-ld"
    export NM_FOR_TARGET="${TARGET_SYS}-nm"
    export CC_FOR_TARGET="${CCACHE} ${TARGET_SYS}-gcc"
    export CFLAGS_FOR_TARGET="${TARGET_CFLAGS}"
    export CPPFLAGS_FOR_TARGET="${TARGET_CPPFLAGS}"
    export CXXFLAGS_FOR_TARGET="${TARGET_CXXFLAGS}"
    export LDFLAGS_FOR_TARGET="${TARGET_LDFLAGS}"

    remove_sysroot_paths_from_configargs '/host'
    remove_sysroot_paths_from_checksum_options '${STAGING_DIR_HOST}' '/host'

    # Build all host components including complete gcc compiler
    oe_runmake all-host all-gcc configure-target-libgcc
    (cd ${B}/${TARGET_SYS}/libgcc; oe_runmake enable-execute-stack.c unwind.h md-unwind-support.h sfp-machine.h gthr-default.h)
}
