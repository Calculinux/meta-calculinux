SUMMARY = "CLI frontend for Calculinux RAUC update bundles"
HOMEPAGE = "https://github.com/Calculinux/calculinux-update"
DESCRIPTION = "Typer-based helper that lists Calculinux RAUC bundles from the mirror, \ 
validates checksums, and launches installs via rauc."

LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = "git://github.com/Calculinux/calculinux-update.git;branch=main;protocol=https \
           file://cup-postreboot.service;subdir=."
SRCREV = "f2434fd47caec6537254f22f25cf7af5235c5881"

S = "${WORKDIR}/git"

inherit python3-dir python3native systemd

RDEPENDS:${PN} += " \
    python3-core \
    python3-httpx \
    python3-mmap \
    python3-rich \
    python3-tomllib \
    python3-typer \
    python3-typing-extensions \
    rauc \
    squashfs-tools \
"

FILES:${PN} += "${PYTHON_SITEPACKAGES_DIR} ${sysconfdir}/calculinux-update ${localstatedir}/cache/calculinux-update ${localstatedir}/lib/calculinux-update"

SYSTEMD_SERVICE:${PN} = "cup-postreboot.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

install_python_package() {
    install -d ${D}${PYTHON_SITEPACKAGES_DIR}
    cp -r ${S}/src/calculinux_update ${D}${PYTHON_SITEPACKAGES_DIR}/
}

install_entrypoint() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/scripts/cup ${D}${bindir}/cup
    install -m 0755 ${S}/scripts/cup-hook ${D}${bindir}/cup-hook
    install -m 0755 ${S}/scripts/cup-postreboot ${D}${bindir}/cup-postreboot
}

install_default_config() {
    install -d ${D}${sysconfdir}/calculinux-update
    install -m 0644 ${S}/config/calculinux-update.toml ${D}${sysconfdir}/calculinux-update/calculinux-update.toml
}

install_state_dirs() {
    install -d ${D}${localstatedir}/cache/calculinux-update/prefetch
    install -d ${D}${localstatedir}/lib/calculinux-update
}

install_service() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/sources-unpack/cup-postreboot.service ${D}${systemd_system_unitdir}/cup-postreboot.service
}

do_install() {
    install_python_package
    install_entrypoint
    install_default_config
    install_state_dirs
    install_service
}
