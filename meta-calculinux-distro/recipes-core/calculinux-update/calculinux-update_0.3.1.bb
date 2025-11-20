SUMMARY = "CLI frontend for Calculinux RAUC update bundles"
HOMEPAGE = "https://github.com/Calculinux/calculinux-update"
DESCRIPTION = "Typer-based helper that lists Calculinux RAUC bundles from the mirror, \ 
validates checksums, and launches installs via rauc."

LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

SRC_URI = "git://github.com/Calculinux/calculinux-update.git;branch=main;protocol=https"
SRCREV = "4461268468f1986fc16269aee8d4c85ae1813770"

S = "${WORKDIR}/git"

inherit python3-dir python3native

RDEPENDS:${PN} += " \
    python3-core \
    python3-httpx \
    python3-mmap \
    python3-rich \
    python3-tomllib \
    python3-typer \
    python3-typing-extensions \
    rauc \
"

FILES:${PN} += "${PYTHON_SITEPACKAGES_DIR} ${sysconfdir}/calculinux-update"

install_python_package() {
    install -d ${D}${PYTHON_SITEPACKAGES_DIR}
    cp -r ${S}/src/calculinux_update ${D}${PYTHON_SITEPACKAGES_DIR}/
}

install_entrypoint() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/scripts/cup ${D}${bindir}/cup
}

install_default_config() {
    install -d ${D}${sysconfdir}/calculinux-update
    install -m 0644 ${S}/config/calculinux-update.toml ${D}${sysconfdir}/calculinux-update/calculinux-update.toml
}

do_install() {
    install_python_package
    install_entrypoint
    install_default_config
}
