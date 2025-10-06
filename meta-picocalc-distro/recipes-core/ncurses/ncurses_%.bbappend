FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Override to use ABI version 6 to enable extended color functions
# This provides init_extended_pair, alloc_pair, and free_pair functions
# and is source compatible with the v5 ABI, so as long as we are compiling
# against this library there should be no compatibility issues.

EXTRA_OECONF += "--with-abi-version=6"

# Fix the linker script to reference the correct version
do_install:append() {
    # Fix libncursesw.so linker script to reference .so.6 instead of .so.5
    if [ -f ${D}${libdir}/libncursesw.so ]; then
        sed -i 's/libncursesw\.so\.5/libncursesw.so.6/g' ${D}${libdir}/libncursesw.so
    fi
}