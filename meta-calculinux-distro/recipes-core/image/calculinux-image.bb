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
    diffutils \
    dosfstools \
    e2fsprogs \
    e2fsprogs-resize2fs \
    ffmpeg \
    file \
    findutils \
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
    less \
    libdrm-tests \
    libsdl \
    libsdl2 \
    freetype \
    links \
    man-db \
    mtd-utils \
    musl-locales \
    nano \
    notcurses \
    notcurses-tools \
    ntp \
    oldschool-console-fonts \
    openssh \
    opkg \
    overlayfs-tools \
    ovl-restore \
    packagegroup-core-buildessential \
    picocalc-dt-overlays \
    picocalc-kbd-test \
    rauc \
    sdl2-test \
    shadow \
    sudo \
    systemd-analyze \
    default-merged-fit \
    merge-dt-overlays-boot \
    terminus-font \
    tmux \
    tree \
    tzdata \
    u-boot-fw-config \
    u-boot-ota \
    u-boot-rockchip-bootscript \
    console-font \
    unifont-console \
    unzip \
    usb-gadget-network \
    usbutils \
    uwific \
    util-linux \
    wget \
    which \
    wireless-regdb-static \
    yaft \
    zip \
"

OVERLAYFS_ETC_INIT_TEMPLATE = "${CALCULINUX_DISTRO_LAYER_DIR}/files/overlayfs-etc-preinit.sh.in"

# rockchip-image.bbclass do_fixup_wks only greps *.img. Mainline U-Boot deploys
# u-boot-rockchip.bin; an empty grep exits 1 under set -e and aborts the image.
# Also treat .bin blobs as optional the same way .img was.
do_fixup_wks() {
	[ -f "${WKS_FULL_PATH}" ] || return 0

	IMAGES=$(grep -oE '[^=[:space:]]+\.(img|bin)' "${WKS_FULL_PATH}" || true)

	for image in ${IMAGES}; do
		if [ ! -f "${DEPLOY_DIR_IMAGE}/${image}" ]; then
			echo "${image} not provided, ignoring it."
			sed -i "/file=${image}/d" "${WKS_FULL_PATH}"
		fi
	done
}

ROOTFS_POSTPROCESS_COMMAND += " calculinux_create_version_manifest;"
IMAGE_POSTPROCESS_COMMAND += " calculinux_export_bundle_extras;"

calculinux_create_version_manifest() {
    manifest_dir="${IMAGE_ROOTFS}/var/lib/calculinux"
    manifest_file="${manifest_dir}/version-manifest.env"
    install -d "${manifest_dir}"
    {
        echo "# Distribution Version Manifest (generated at image build time)"
        echo "CALCULINUX_VERSION=\"${DISTRO_VERSION}\""
        echo "CALCULINUX_CODENAME=\"${DISTRO_CODENAME}\""
        echo "MIN_CALCULINUX_VERSION=\"${CALCULINUX_MIN_VERSION}\""
        echo "MIN_BUILD_TIMESTAMP=\"${CALCULINUX_MIN_BUILD_TIMESTAMP}\""
        echo "YOCTO_VERSION=\"${LAYERSERIES_CORENAMES}\""
        echo "KERNEL_VERSION=\"${KERNEL_VERSION}\""
        echo "PYTHON_VERSION=\"${PYTHON_BASEVERSION}\""
        echo "FEED_BASE_URL=\"${PACKAGE_FEED_URIS}\""
        echo "FEED_PATH=\"${PACKAGE_FEED_BASE_PATHS}\""
        # SOURCE_DATE_EPOCH keeps the rootfs bit-identical across rebuilds.
        build_ts="$(date -u -d "@${SOURCE_DATE_EPOCH}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "BUILD_TIMESTAMP=\"${build_ts}\""
    } > "${manifest_file}"
    chmod 644 "${manifest_file}"
}

calculinux_export_bundle_extras() {
    extras_work="${WORKDIR}/bundle-extras"
    extras_base="${extras_work}/extras"
    extras_tar="${IMGDEPLOYDIR}/bundle-extras.tar.gz"
    extras_manifest="${IMGDEPLOYDIR}/version-manifest.env"
    rm -rf "${extras_work}"
    rm -f "${extras_tar}" "${extras_manifest}"
    if [ -f "${IMAGE_ROOTFS}/var/lib/calculinux/version-manifest.env" ]; then
        install -d "${extras_base}"
        install -m 0644 "${IMAGE_ROOTFS}/var/lib/calculinux/version-manifest.env" \
            "${extras_base}/version-manifest.env"
        install -m 0644 "${IMAGE_ROOTFS}/var/lib/calculinux/version-manifest.env" \
            "${extras_manifest}"
        tar -czf "${extras_tar}" -C "${extras_work}" extras
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
