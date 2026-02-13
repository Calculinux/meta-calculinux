SUMMARY = "Minimal fast booting image"
LICENSE = "MIT"

inherit core-image extrausers
# password hash of "root"
PASSWD = "\$6\$mwqqduWKbrqg9ufl\$i6fl1JW5RP0KABiva.fBfzyt6bAj5so4Tg5OpwuhqhCOSFfwD9dq8V8u3BEvkYTf5oSreqFnVBecE78DeZXCV0"

# password hash of "calc"
PICO_PASSWORD = "\$6\$G4enDnQY4liXfauo\$UUz007.Y/oxzq6A5.LaTizALFZVjlEA3iDbMqHhqcUilx2H.19rYEnWKWQvcA2yI7YtgJappJTlrb3SfiETYe."


EXTRA_USERS_PARAMS = "\
    useradd -G wheel,video,render,input -s /bin/bash pico; \
    usermod -p '${PASSWD}' root; \
    usermod -p '${PICO_PASSWORD}' pico; \
"

IMAGE_FEATURES += "\
    overlayfs-etc \
    package-management \
    doc-pkgs \
"

IMAGE_INSTALL += " \
    acpid \
    alsa-lib \
    alsa-plugins \
    alsa-tools \
    alsa-utils \
    autoconf \
    bash \
    bash-completion \
    btrfs-tools \
    busybox \
    calculinux-update \
    cloud-utils-growpart \
    curl \
    dosfstools \
    e2fsprogs \
    e2fsprogs-resize2fs \
    file \
    gcompat \
    gdb \
    git \
    gptfdisk \
    grep \
    groff \
    hoard-of-bitfonts-commodore \
    htop \
    i2c-tools \
    iw \
    iwd \
    kbd-consolefonts \
    kbd-keymaps \
    kernel-modules \
    libdrm-tests \
    libsdl \
    libsdl2 \
    freetype \
    links \
    man-db \
    mtd-utils \
    musl-locales \
    notcurses \
    notcurses-tools \
    ntp \
    oldschool-console-fonts \
    openssh \
    opkg \
    overlayfs-tools \
    ovl-restore \
    packagegroup-core-buildessential \
    rauc \
    sdl2-test \
    shadow \
    sudo \
    systemd-analyze \
    terminus-font \
    u-boot-fw-config \
    u-boot-rockchip-bootscript \
    usb-gadget-network \
    usbutils \
    util-linux \
    wget \
"

OVERLAYFS_ETC_INIT_TEMPLATE = "${CALCULINUX_DISTRO_LAYER_DIR}/files/overlayfs-etc-preinit.sh.in"

ROOTFS_POSTPROCESS_COMMAND += " calculinux_create_version_manifest; calculinux_install_opkg_image_status; calculinux_export_bundle_extras;"

calculinux_create_version_manifest() {
    manifest_dir="${IMAGE_ROOTFS}/var/lib/calculinux"
    manifest_file="${manifest_dir}/version-manifest.env"
    install -d "${manifest_dir}"
    {
        echo "# Distribution Version Manifest (generated at image build time)"
        echo "CALCULINUX_VERSION=\"${DISTRO_VERSION}\""
        echo "CALCULINUX_CODENAME=\"${DISTRO_CODENAME}\""
        echo "YOCTO_VERSION=\"${LAYERSERIES}\""
        echo "KERNEL_VERSION=\"${KERNEL_VERSION}\""
        echo "PYTHON_VERSION=\"${PYTHON_BASEVERSION}\""
        echo "FEED_BASE_URL=\"${PACKAGE_FEED_URIS}\""
        echo "FEED_PATH=\"${PACKAGE_FEED_BASE_PATHS}\""
        echo "BUILD_TIMESTAMP=\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
    } > "${manifest_file}"
    chmod 644 "${manifest_file}"
}

calculinux_install_opkg_image_status() {
    status_dir="${IMAGE_ROOTFS}/var/lib/opkg"
    status_file="${status_dir}/status"
    image_status_file="${status_dir}/status.image"
    image_status_dir="$(dirname "${image_status_file}")"

    install -d "${status_dir}"
    install -d "${image_status_dir}"

    if [ -f "${status_file}" ]; then
        install -m 0644 "${status_file}" "${image_status_file}"
    else
        : > "${image_status_file}"
    fi

    : > "${status_file}"
}

calculinux_export_bundle_extras() {
    extras_base="${DEPLOY_DIR_IMAGE}/bundle-extras/extras"
    extras_dir="${extras_base}/opkg"
    rm -rf "${DEPLOY_DIR_IMAGE}/bundle-extras"
    
    # Only create extras if we have data to export
    has_data=0
    
    if [ -d "${IMAGE_ROOTFS}/etc/opkg" ]; then
        install -d "${extras_dir}/etc"
        cp -r "${IMAGE_ROOTFS}/etc/opkg" "${extras_dir}/etc/"
        has_data=1
    fi

    if [ -f "${IMAGE_ROOTFS}/var/lib/opkg/status.image" ]; then
        install -d "${extras_dir}"
        install -m 0644 "${IMAGE_ROOTFS}/var/lib/opkg/status.image" "${extras_dir}/status.image"
        has_data=1
    fi

    # Version manifest for major-version upgrade compatibility checking
    if [ -f "${IMAGE_ROOTFS}/var/lib/calculinux/version-manifest.env" ]; then
        install -d "${extras_base}"
        install -m 0644 "${IMAGE_ROOTFS}/var/lib/calculinux/version-manifest.env" "${extras_base}/version-manifest.env"
        has_data=1
    fi

    # Create a tarball only if we have data to include in the bundle
    if [ "$has_data" = "1" ] && [ -d "${DEPLOY_DIR_IMAGE}/bundle-extras/extras" ]; then
        tar -czf "${DEPLOY_DIR_IMAGE}/bundle-extras.tar.gz" -C "${DEPLOY_DIR_IMAGE}/bundle-extras" extras
    fi
}

# Override rockchip-image.bbclass to remove Android-style firmware symlinks
#
# The upstream meta-rockchip layer creates /system/etc/firmware and /vendor/etc/firmware
# symlinks pointing to /usr/lib/firmware for compatibility with Rockchip's Android-based
# rkwifibt drivers. Calculinux uses standard Linux firmware loading and doesn't need these.
ROOTFS_POSTPROCESS_COMMAND:remove = " do_post_rootfs;"
ROOTFS_POSTPROCESS_COMMAND:append = " do_post_rootfs_calculinux;"

do_post_rootfs_calculinux() {
        # Apply RK_OVERLAY_DIRS without creating Android firmware symlinks
        for overlay in ${RK_OVERLAY_DIRS};do
                [ -d "${overlay}" ] || continue
                echo "Installing overlay: ${overlay}..."
                rsync -av --chmod=u=rwX,go=rX "${overlay}/" "${IMAGE_ROOTFS}"
        done

        # Run post-rootfs scripts
        for script in ${RK_POST_ROOTFS_SCRIPTS};do
                [ -f "${script}" ] || continue
                echo "Running script: ${script}..."
                cd "${script%/*}"
                "${script}" "${IMAGE_ROOTFS}"
        done
}
