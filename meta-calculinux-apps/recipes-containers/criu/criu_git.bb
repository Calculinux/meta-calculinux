SUMMARY = "CRIU"
DESCRIPTION = "Checkpoint/Restore In Userspace, or CRIU, is a software tool for \
Linux operating system. Using this tool, you can freeze a running application \
(or part of it) and checkpoint it to a hard drive as a collection of files. \
You can then use the files to restore and run the application from the point \
it was frozen at. The distinctive feature of the CRIU project is that it is \
mainly implemented in user space"
HOMEPAGE = "http://criu.org"
SECTION = "console/tools"
LICENSE = "GPL-2.0-only"

EXCLUDE_FROM_WORLD = "1"

LIC_FILES_CHKSUM = "file://COPYING;md5=412de458544c1cb6a2b512cd399286e2"

SRCREV = "b6059ff193a9b0dff98e997134d662c3ccfd1600"
PV = "4.1+git"

SRC_URI = "git://github.com/checkpoint-restore/criu.git;branch=master;protocol=https \
           file://0001-criu-Skip-documentation-install.patch \
           file://0002-criu-Change-libraries-install-directory.patch \
           file://0003-crit-pycriu-build-and-install-wheels.patch \
           file://0004-pycriu-attr-pycriu.version.__version__.patch \
           file://0005-pycriu-skip-dependency-check-during-build.patch \
           file://0001-crit-explicity-set-PEP517_SOURCE_PATH.patch \
           file://0001-plugins-cuda-pass-DEBUG_PREFIX_MAP.patch \
           "

COMPATIBLE_HOST = "(x86_64|arm|aarch64).*-linux"

DEPENDS += "libnl libcap protobuf-c-native protobuf-c util-linux-native libbsd libnet python3-protobuf-native"
RDEPENDS:${PN} = "bash cgroup-lite python3-ctypes python3-fcntl python3-protobuf"

S = "${WORKDIR}/git"

#
# CRIU just can be built on ARMv7 and ARMv6, so the Makefile check
# if the ARCH is ARMv7 or ARMv6.
# ARM BSPs need set CRIU_BUILD_ARCH variable for building CRIU.
#
EXTRA_OEMAKE:arm += "ARCH=arm UNAME-M=${CRIU_BUILD_ARCH} WERROR=0"
EXTRA_OEMAKE:x86-64 += "ARCH=x86 WERROR=0"
EXTRA_OEMAKE:aarch64 += "ARCH=aarch64 WERROR=0"

EXTRA_OEMAKE:append = " SBINDIR=${sbindir} LIBDIR=${libdir} INCLUDEDIR=${includedir} PIEGEN=no"
EXTRA_OEMAKE:append = " LOGROTATEDIR=${sysconfdir} SYSTEMDUNITDIR=${systemd_unitdir}"

CFLAGS += "-D__USE_GNU -D_GNU_SOURCE "

CFLAGS += " -I${STAGING_INCDIR} -I${STAGING_INCDIR}/libnl3"
CFLAGS:append:arm = " -D__WORDSIZE"

# overide LDFLAGS to allow criu to build without: "x86_64-poky-linux-ld: unrecognized option '-Wl,-O1'"
export LDFLAGS = ""
export C_INCLUDE_PATH = "${STAGING_INCDIR}/libnl3"

export BUILD_SYS
export HOST_SYS
export HOSTCFLAGS = "${BUILD_CFLAGS}"

inherit python_setuptools_build_meta
inherit pkgconfig

B = "${S}"

PACKAGECONFIG ??= ""
PACKAGECONFIG[selinux] = ",,libselinux"

CLEANBROKEN = "1"

# WARNING: criu-3.17.1 do_package_qa: QA Issue: criu: ELF binary /usr/sbin/criu has relocations in .text [textrel]
INSANE_SKIP:${PN} += "textrel"

do_compile:prepend() {
    rm -rf ${S}/images/google/protobuf/descriptor.proto
    ln -s  ${PKG_CONFIG_SYSROOT_DIR}/usr/include/google/protobuf/descriptor.proto ${S}/images/google/protobuf/descriptor.proto
}

do_compile () {
	export DEBUG_PREFIX_MAP="${DEBUG_PREFIX_MAP}"
	oe_runmake FULL_PYTHON=${PYTHON} PYTHON=nativepython3
}

do_install () {
    export INSTALL_LIB="${libdir}/${PYTHON_DIR}/site-packages"
    export PEP517_WHEEL_PATH="${PEP517_WHEEL_PATH}"
    export USRBINPATH="${USRBINPATH}"
    export PEP517_INSTALL_PYTHON="${PEP517_INSTALL_PYTHON}"

    oe_runmake PREFIX=${exec_prefix} LIBDIR=${libdir} DESTDIR="${D}" PLUGINDIR="${localstatedir}/lib" FULL_PYTHON=${PYTHON} PYTHON=nativepython3 install

    # python3's distutils has a feature of rewriting the interpeter on setup installed
    # scripts. 'crit' is one of those scripts. The "executable" or "e" option to the
    # setup call should fix it, but it is being ignored. So to avoid getting our native
    # intepreter replaced in the script, we'll do an explicit update ourselves.
    #
    # we're building wheels now, so EGG-INFO need not apply
    #sed -i 's%^\#\!.*%\#\!/usr/bin/env python3%' ${D}/usr/bin/crit ${D}${libdir}/python3*/site-packages/crit-*-py3*.egg/EGG-INFO/scripts/crit

    # all the __pycache__ contains references to TMPDIR and these will be built the first time
    # it runs on the target anyway
    for pycachedir in $(find ${D} -name __pycache__); do
        rm -rf $pycachedir
    done
}

FILES:${PN} += "${systemd_unitdir}/ \
            #${libdir}/python3*/site-packages/ \
            #${libdir}/pycriu/ \
            #${libdir}/crit-0.0.1-py3*.egg-info \
            "

FILES:${PN}-staticdev += " \
            ${libexecdir}/compel/std.lib.a \
            ${libexecdir}/compel/fds.lib.a \
            "
