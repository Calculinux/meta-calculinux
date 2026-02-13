SUMMARY = "Meshtastic native daemon built with PlatformIO"
DESCRIPTION = "Meshtasticd provides a Linux-native gateway and service wrapper for Meshtastic nodes, built from the upstream Meshtastic firmware Portduino environment."
HOMEPAGE = "https://meshtastic.org/docs/software/linux-native/"
LICENSE = "GPL-3.0-only & Apache-2.0"
LIC_FILES_CHKSUM = " \
    file://LICENSE;md5=8f0e2cd40e05189ec81232da84bd6e1a \
    file://LICENSE;subdir=platform-native;md5=8f0e2cd40e05189ec81232da84bd6e1a \
"

PV = "2.6.11"

SRCREV_FORMAT = "meshtastic_platform"
SRCREV_meshtastic = "60ec05e53693535aaf616162d4f970cfca6a5d58"
SRCREV_platform = "622341c6de8a239704318b10c3dbb00c21a3eab3"

SRC_URI = " \
    git://github.com/meshtastic/firmware.git;branch=develop;protocol=https;submodules=1;name=meshtastic \
    git://github.com/meshtastic/platform-native.git;branch=develop;protocol=https;destsuffix=platform-native;name=platform \
    file://002-remove-host-include.patch \
    file://003-portduino-buildroot-board.patch \
    file://004-platformio-link-group.patch \
    file://meshtasticd.service \
    file://meshtasticd.avahi.xml \
    file://config.d/luckfox_pico-lora-rfsw-tcxo.yaml \
    file://config.d/luckfox_pico-lora-rfsw-no_tcxo.yaml \
    file://config.d/luckfox_pico-lora-rfsw-ebyte_e22.yaml \
    file://config.d/picocalc-sx1262-lora.yaml \
"

S = "${WORKDIR}/git"

inherit python3native systemd pkgconfig

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SYSTEMD_SERVICE:${PN} = "meshtasticd.service"

# Skip QA checks to ignore TMPDIR references in binaries from PlatformIO builds
INSANE_SKIP:${PN} += "buildpaths"
INSANE_SKIP:${PN}-dbg += "buildpaths"

PACKAGECONFIG ??= ""
PACKAGECONFIG[avahi] = "",,"avahi"
PACKAGECONFIG[web] = "",,"libulfius liborcania libyder openssl gnutls"

DEPENDS += " \
    argp-standalone \
    bluez5 \
    i2c-tools \
    libgpiod \
    libusb1 \
    libuv \
    openssl-native \
    python3-native \
    python3-platformio-native \
    pkgconfig-native \
    yaml-cpp \
    zlib \
"

RDEPENDS:${PN} += " \
    bluez5 \
    i2c-tools \
    libgpiod \
    libusb1 \
    libuv \
    yaml-cpp \
    zlib \
"

# Remove unsupported compiler flags for platformio builds (GCC < 8)
CFLAGS:remove = "-fcanon-prefix-map"
CXXFLAGS:remove = "-fcanon-prefix-map"

# PlatformIO downloads packages dynamically; allow controlled network usage
# until all packages are mirrored explicitly.
do_compile[network] = "1"

do_configure[noexec] = "1"

do_compile() {
    export HOME="${WORKDIR}/home"
    install -d ${WORKDIR}/home ${WORKDIR}/.platformio_cache ${WORKDIR}/.platformio_platforms ${WORKDIR}/.platformio_packages ${WORKDIR}/.platformio_home

    export PLATFORMIO_CORE_DIR="${WORKDIR}/.platformio_core"
    export PLATFORMIO_HOME_DIR="${WORKDIR}/.platformio_home"
    export PLATFORMIO_CACHE_DIR="${WORKDIR}/.platformio_cache"
    export PLATFORMIO_BUILD_CACHE_DIR="${WORKDIR}/.platformio_cache/build"
    export PLATFORMIO_PLATFORMS_DIR="${WORKDIR}/.platformio_platforms"
    export PLATFORMIO_PACKAGES_DIR="${WORKDIR}/.platformio_packages"
    export PLATFORMIO_SETTING_ENABLE_TELEMETRY="no"
    export PLATFORMIO_DISABLE_PROGRESSBAR=1

    rm -rf ${PLATFORMIO_PLATFORMS_DIR}/platform-native
    install -d ${PLATFORMIO_PLATFORMS_DIR}/platform-native
    cp -r ${WORKDIR}/sources-unpack/platform-native/* ${PLATFORMIO_PLATFORMS_DIR}/platform-native/

    export TARGET_CC="${CC}"
    export TARGET_CXX="${CXX}"
    export TARGET_AR="${AR}"
    export TARGET_AS="${AS}"
    export TARGET_LD="${LD}"
    export TARGET_RANLIB="${RANLIB}"
    export TARGET_OBJCOPY="${OBJCOPY}"

    # Add --sysroot to ensure target headers/libs are used, not host system
    export TARGET_CFLAGS="${CFLAGS} --sysroot=${STAGING_DIR_TARGET}"
    export TARGET_CXXFLAGS="${CXXFLAGS} -std=c++17 --sysroot=${STAGING_DIR_TARGET}"
    export TARGET_LDFLAGS="${LDFLAGS} --sysroot=${STAGING_DIR_TARGET}"

    export PLATFORMIO_BUILD_FLAGS="-std=c++17 ${TARGET_LDFLAGS} -largp -lusb-1.0 -luv"
    export PLATFORMIO_CFLAGS="${TARGET_CFLAGS} -I${STAGING_INCDIR}"
    export PLATFORMIO_CXXFLAGS="${TARGET_CXXFLAGS} -I${STAGING_INCDIR}"
    export PLATFORMIO_LDFLAGS="${TARGET_LDFLAGS} -L${STAGING_LIBDIR}"

    export PKG_CONFIG="${STAGING_BINDIR_NATIVE}/pkg-config"
    export PKG_CONFIG_SYSROOT_DIR="${STAGING_DIR_TARGET}"
    export PKG_CONFIG_LIBDIR="${STAGING_LIBDIR}/pkgconfig:${STAGING_DIR_TARGET}/usr/lib/pkgconfig"
    export PKG_CONFIG_PATH="${PKG_CONFIG_LIBDIR}"

    ${PYTHON} -m platformio run --environment native --project-dir ${S}
}

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${S}/.pio/build/native/program ${D}${sbindir}/meshtasticd

    install -d ${D}${sysconfdir}/meshtasticd/config.d
    install -d ${D}${sysconfdir}/meshtasticd/available.d
    install -m 0644 ${S}/bin/config-dist.yaml ${D}${sysconfdir}/meshtasticd/config.yaml
    cp -r ${S}/bin/config.d/* ${D}${sysconfdir}/meshtasticd/available.d/ 2>/dev/null || true
    find ${D}${sysconfdir}/meshtasticd/available.d -type f -exec chmod 0644 {} \;
    install -m 0644 ${WORKDIR}/config.d/*.yaml ${D}${sysconfdir}/meshtasticd/available.d/ 2>/dev/null || true

    # Link PicoCalc SX1262 LoRA config as default
    ln -sf ../available.d/picocalc-sx1262-lora.yaml ${D}${sysconfdir}/meshtasticd/config.d/000-picocalc-lora.yaml

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/sources-unpack/meshtasticd.service ${D}${systemd_system_unitdir}/

    if ${@bb.utils.contains('PACKAGECONFIG', 'avahi', 'true', 'false', d)}; then
        install -d ${D}${sysconfdir}/avahi/services
        install -m 0644 ${WORKDIR}/sources-unpack/meshtasticd.avahi.xml ${D}${sysconfdir}/avahi/services/meshtasticd.service
    fi

    if ${@bb.utils.contains('PACKAGECONFIG', 'web', 'true', 'false', d)}; then
        install -d ${D}${datadir}/meshtasticd/web
    fi
}

FILES:${PN} += " \
    ${sysconfdir}/meshtasticd \
    ${systemd_system_unitdir}/meshtasticd.service \
"

FILES:${PN}-dbg += "${sbindir}/.debug/meshtasticd"

CONFFILES:${PN} = "${sysconfdir}/meshtasticd/config.yaml"
