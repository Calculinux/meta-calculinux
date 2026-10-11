SUMMARY = "Calculinux emulator AppImage"
DESCRIPTION = "Self-contained AppImage for ${SDKMACHINE} hosts: QEMU (SDL window), \
U-Boot and a launcher that lists the published calculinux-qemuarm disk images \
and downloads the chosen one (or boot your own with --image). Built like an \
SDK: bitbake calculinux-emulator -c populate_sdk (SDKMACHINE selects the host)."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

COMPATIBLE_MACHINE = "calculinux-qemuarm"

# Pinned AppImage type2 runtime (static; uses FUSE 3 or extract-and-run).
APPIMAGE_RUNTIME_VERSION = "20251108"
APPIMAGE_RUNTIME_URI = "https://github.com/AppImage/type2-runtime/releases/download/${APPIMAGE_RUNTIME_VERSION}"

SRC_URI = " \
    file://AppRun.in \
    file://calculinux-emulator.desktop \
    file://calculinux-emulator.svg \
    ${APPIMAGE_RUNTIME_URI}/runtime-x86_64;name=runtime-x86_64;downloadfilename=appimage-runtime-${APPIMAGE_RUNTIME_VERSION}-x86_64 \
    ${APPIMAGE_RUNTIME_URI}/runtime-aarch64;name=runtime-aarch64;downloadfilename=appimage-runtime-${APPIMAGE_RUNTIME_VERSION}-aarch64 \
"
SRC_URI[runtime-x86_64.sha256sum] = "2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d"
SRC_URI[runtime-aarch64.sha256sum] = "00cbdfcf917cc6c0ff6d3347d59e0ca1f7f45a6df1a428a0d6d8a78664d87444"

# Bootloader bundled in the AppImage.
EMULATOR_BIOS = "${DEPLOY_DIR_IMAGE}/u-boot.bin"
# The launcher offers the disk images listed in this index (written by
# .github/scripts/generate-emulator-index.py on every emulator publish) and
# preselects this build's own: its tag for a release build (DISTRO_VERSION
# is the tag), else the latest image of its branch.
EMULATOR_INDEX_URL ?= "${PACKAGE_FEED_URIS}emulator/${MACHINE}/index.json"
EMULATOR_DEFAULT_ID ?= "${@d.getVar('DISTRO_VERSION') if d.getVar('CALCULINUX_FEED_SUBFOLDER') == 'release' else 'continuous-develop' if d.getVar('DISTRO_CODENAME') == 'develop' else 'continuous-main'}"
# The same image by URL, offered when the index cannot be fetched: the
# wic.qcow2c that CI publishes for this feed (see publish-emulator.sh). A
# release build names its tag's image: prerelease tags publish no
# un-versioned copy.
EMULATOR_IMAGE ?= "calculinux-image"
EMULATOR_IMAGE_TAG = "${@'-' + d.getVar('DISTRO_VERSION') if d.getVar('CALCULINUX_FEED_SUBFOLDER') == 'release' else ''}"
EMULATOR_IMAGE_URL ?= "${PACKAGE_FEED_URIS}image/${DISTRO_CODENAME}/${CALCULINUX_FEED_SUBFOLDER}/${EMULATOR_IMAGE}-${MACHINE}.rootfs${EMULATOR_IMAGE_TAG}.qcow2"

# Host side: QEMU and what it needs at runtime (see the qemu/libsdl2
# bbappends in this layer for the trimmed-down configuration), and the
# launcher with CA certificates for its downloads (it prefers the host's,
# but a minimal host may have none).
TOOLCHAIN_HOST_TASK = " \
    nativesdk-sdk-provides-dummy \
    nativesdk-qemu-system-arm \
    nativesdk-calculinux-emulator-launcher \
    nativesdk-ca-certificates \
"
TOOLCHAIN_TARGET_TASK = ""

TOOLCHAIN_OUTPUTNAME = "calculinux-emulator-${SDK_ARCH}-${DISTRO_VERSION}"
SDK_TITLE = "Calculinux emulator"

# Host-only SDK, as in buildtools-tarball.
MULTIMACH_TARGET_SYS = "${SDK_ARCH}-nativesdk${SDK_VENDOR}-${SDK_OS}"
PACKAGE_ARCH = "${SDK_ARCH}_${SDK_OS}"
PACKAGE_ARCHS = ""
TARGET_ARCH = "none"
TARGET_OS = "none"
REAL_MULTIMACH_TARGET_SYS = "none"
TOOLCHAIN_NEED_CONFIGSITE_CACHE = ""
INHIBIT_DEFAULT_DEPS = "1"
EXCLUDE_FROM_WORLD = "1"
RDEPENDS = "${TOOLCHAIN_HOST_TASK}"

inherit populate_sdk
inherit nopackages

deltask install
deltask populate_sysroot
SDK_CLASSES:remove = "testsdk"

do_populate_sdk[stamp-extra-info] = "${PACKAGE_ARCH}"
addtask populate_sdk after do_unpack
SDK_DEPENDS:append = " squashfs-tools-native"
do_populate_sdk[depends] += "virtual/bootloader:do_deploy"

# Package the host sysroot and images as an AppImage instead of the usual
# tarball + shell installer.
SDK_POSTPROCESS_COMMAND = "build_appimage"
build_appimage[vardeps] += "CALCULINUX_QEMU_MACHINE CALCULINUX_QEMU_CPU CALCULINUX_QEMU_SMP CALCULINUX_QEMU_MEM DISTRO_VERSION EMULATOR_IMAGE_URL EMULATOR_INDEX_URL EMULATOR_DEFAULT_ID"

fakeroot build_appimage() {
    appdir="${WORKDIR}/AppDir"
    rm -rf "$appdir"
    install -d "$appdir/images"

    cp -a "${SDK_OUTPUT}${SDKPATHNATIVE}" "$appdir/sysroot"
    rm -rf "$appdir/sysroot/usr/include" \
           "$appdir/sysroot/usr/share/man" \
           "$appdir/sysroot/usr/share/doc" \
           "$appdir/sysroot/usr/share/info" \
           "$appdir/sysroot/usr/lib/pkgconfig" \
           "$appdir/sysroot/usr/share/pkgconfig" \
           "$appdir/sysroot/environment-setup.d"
    find "$appdir/sysroot" -name '*.a' -delete
    ls "$appdir"/sysroot/lib/ld-linux-*.so.* >/dev/null || \
        bbfatal "no dynamic loader in the nativesdk sysroot"
    # Without these SDL has no way to open a window.
    for lib in libX11.so.6 libwayland-client.so.0; do
        [ -e "$appdir/sysroot/usr/lib/$lib" ] || \
            bbfatal "$lib missing from the AppImage (SDL display backend)"
    done
    [ -x "$appdir/sysroot/usr/bin/calculinux-emulator-launcher" ] || \
        bbfatal "launcher missing from the AppImage"
    [ -e "$appdir/sysroot/usr/lib/libcurl.so.4" ] || \
        bbfatal "libcurl.so.4 missing from the AppImage (launcher downloads)"

    # Of ca-certificates only the bundle is used (the launcher is told where
    # it is); drop the single certificates, the links to them and the tools
    # that maintain them.
    [ -f "$appdir/sysroot/etc/ssl/certs/ca-certificates.crt" ] && \
        [ ! -L "$appdir/sysroot/etc/ssl/certs/ca-certificates.crt" ] && \
        [ -s "$appdir/sysroot/etc/ssl/certs/ca-certificates.crt" ] || \
        bbfatal "CA bundle missing from the AppImage (launcher downloads)"
    find "$appdir/sysroot/etc/ssl/certs" -mindepth 1 ! -name ca-certificates.crt -delete
    rm -rf "$appdir/sysroot/usr/share/ca-certificates" \
           "$appdir/sysroot/usr/sbin/update-ca-certificates" \
           "$appdir/sysroot/usr/bin/openssl" \
           "$appdir/sysroot/usr/bin/c_rehash"

    sed -e 's|@QEMU_MACHINE@|${CALCULINUX_QEMU_MACHINE}|' \
        -e 's|@QEMU_CPU@|${CALCULINUX_QEMU_CPU}|' \
        -e 's|@QEMU_SMP@|${CALCULINUX_QEMU_SMP}|' \
        -e 's|@QEMU_MEM@|${CALCULINUX_QEMU_MEM}|' \
        "${UNPACKDIR}/AppRun.in" > "$appdir/AppRun"
    chmod 0755 "$appdir/AppRun"
    install -m 0644 "${UNPACKDIR}/calculinux-emulator.desktop" "$appdir/"
    install -m 0644 "${UNPACKDIR}/calculinux-emulator.svg" "$appdir/"
    ln -s calculinux-emulator.svg "$appdir/.DirIcon"

    install -m 0644 "${EMULATOR_BIOS}" "$appdir/images/u-boot.bin"
    echo "${EMULATOR_IMAGE_URL}" > "$appdir/images/image-url"
    echo "${EMULATOR_INDEX_URL}" > "$appdir/images/index-url"
    echo "${EMULATOR_DEFAULT_ID}" > "$appdir/images/default-id"
    echo "${DISTRO_VERSION}" > "$appdir/images/version"

    mksquashfs "$appdir" "${WORKDIR}/emulator.squashfs" \
        -noappend -all-root -comp zstd -quiet
    cat "${UNPACKDIR}/appimage-runtime-${APPIMAGE_RUNTIME_VERSION}-${SDK_ARCH}" \
        "${WORKDIR}/emulator.squashfs" > "${SDKDEPLOYDIR}/${TOOLCHAIN_OUTPUTNAME}.AppImage"
    chmod 0755 "${SDKDEPLOYDIR}/${TOOLCHAIN_OUTPUTNAME}.AppImage"
    rm -f "${WORKDIR}/emulator.squashfs"
}
