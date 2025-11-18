FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://0001-opkg-add-image-status-file-support.patch"

do_install:append() {
    conf="${D}${sysconfdir}/opkg/opkg.conf"
    install -d "${D}${sysconfdir}/opkg"

    if [ ! -e "${conf}" ]; then
        touch "${conf}"
    fi

    if ! grep -q "^option[[:space:]]\+image_status_file" "${conf}"; then
        if grep -q "^option[[:space:]]\+status_file" "${conf}"; then
            sed -i '/^option[[:space:]]\+status_file/a option image_status_file /var/lib/opkg/status.image' "${conf}"
        else
            printf '\noption image_status_file /var/lib/opkg/status.image\n' >> "${conf}"
        fi
    fi
}
