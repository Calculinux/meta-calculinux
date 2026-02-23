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
    ffmpeg \
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
    picocalc-drivers \
    picocalc-m0-firmware \
    picocalc-kbd-test \
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
