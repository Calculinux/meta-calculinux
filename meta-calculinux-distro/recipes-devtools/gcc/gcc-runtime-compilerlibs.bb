# Stub provider for virtual/${TARGET_PREFIX}compilerlibs so Rust cross recipes
# can resolve its dependency when the default gcc-runtime provider is not selected
# (e.g. with meta-arm-toolchain). This recipe pulls in the real gcc-runtime.
SUMMARY = "Virtual package providing compiler runtime libraries"
SECTION = "devel"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

PROVIDES = "virtual/${TARGET_PREFIX}compilerlibs"
DEPENDS = "gcc-runtime"
# No RDEPENDS: gcc-runtime recipe produces libstdc++, libgomp, etc., not a package named gcc-runtime.

# No build or install; we only satisfy the virtual dependency.
do_configure[noexec] = "1"
do_compile[noexec] = "1"
do_install[noexec] = "1"

FILES:${PN} = ""
