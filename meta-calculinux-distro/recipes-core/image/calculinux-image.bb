SUMMARY = "Minimal fast booting image"
LICENSE = "MIT"

inherit core-image extrausers
# password hash of "root"
PASSWD = "\$6\$mwqqduWKbrqg9ufl\$i6fl1JW5RP0KABiva.fBfzyt6bAj5so4Tg5OpwuhqhCOSFfwD9dq8V8u3BEvkYTf5oSreqFnVBecE78DeZXCV0"

# password hash of "calc"
PICO_PASSWORD = "\$6\$G4enDnQY4liXfauo\$UUz007.Y/oxzq6A5.LaTizALFZVjlEA3iDbMqHhqcUilx2H.19rYEnWKWQvcA2yI7YtgJappJTlrb3SfiETYe."


EXTRA_USERS_PARAMS = "\
    useradd -G wheel -s /bin/bash pico; \
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
    android-tools \
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
    gdb \
    git \
    grep \
    htop \
    i2c-tools \
    iw \
    iwd \
    kbd-keymaps \
    kernel-modules \
    links \
    man-db \
    mtd-utils \
    musl-locales \
    ntp \
    openssh \
    opkg \
    overlayfs-tools \
    packagegroup-core-buildessential \
    rauc \
    shadow \
    sudo \
    systemd-analyze \
    terminus-font \
    u-boot-fw-config \
    u-boot-rockchip-bootscript \
    usbutils \
    util-linux \
    wget \
"

OVERLAYFS_ETC_INIT_TEMPLATE = "${CALCULINUX_DISTRO_LAYER_DIR}/files/overlayfs-etc-preinit.sh.in"

ROOTFS_POSTPROCESS_COMMAND += " calculinux_install_opkg_image_status; calculinux_export_bundle_extras;"

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
    extras_dir="${DEPLOY_DIR_IMAGE}/bundle-extras/extras/opkg"
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

    # Create a tarball only if we have data to include in the bundle
    if [ "$has_data" = "1" ] && [ -d "${DEPLOY_DIR_IMAGE}/bundle-extras/extras" ]; then
        tar -czf "${DEPLOY_DIR_IMAGE}/bundle-extras.tar.gz" -C "${DEPLOY_DIR_IMAGE}/bundle-extras" extras
    fi
}
