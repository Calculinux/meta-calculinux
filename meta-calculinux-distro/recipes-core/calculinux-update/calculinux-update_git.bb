SUMMARY = "CLI frontend for Calculinux RAUC update bundles"
HOMEPAGE = "https://github.com/Calculinux/calculinux-update"
DESCRIPTION = "Typer-based helper that lists Calculinux RAUC bundles from the mirror, \ 
validates checksums, and launches installs via rauc."

LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

SRC_URI = "git://github.com/Calculinux/calculinux-update.git;nobranch=1;protocol=https"
SRCREV = "f8b3f036fe1cd5f153c2d303f6e6b3d6ab50d0b6"

S = "${WORKDIR}/git"

# Use SRCPV for automatic git-based versioning (format: <base>+git<revision>)
PV = "0.6.0+git${SRCPV}"

inherit python3-dir python3native systemd

RDEPENDS:${PN} += " \
    python3-core \
    python3-difflib \
    python3-httpx \
    python3-mmap \
    python3-rich \
    python3-tomllib \
    python3-typer \
    python3-typing-extensions \
    rauc \
    squashfs-tools \
"

FILES:${PN} += "${PYTHON_SITEPACKAGES_DIR} ${libdir}/calculinux-update ${sysconfdir}/calculinux-update ${localstatedir}/cache/calculinux-update ${localstatedir}/lib/calculinux-update ${mandir}/man1"

SYSTEMD_SERVICE:${PN} = "cup-postreboot.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

# Compile Python modules to bytecode for faster startup
PACKAGE_PREPROCESS_FUNCS += "compile_python_modules"

install_python_package() {
    install -d ${D}${PYTHON_SITEPACKAGES_DIR}
    cp -r ${S}/src/calculinux_update ${D}${PYTHON_SITEPACKAGES_DIR}/
}

compile_python_modules() {
    # Compile Python modules to optimized bytecode (.pyc) for faster startup
    # Using optimization level 2 (-OO) removes docstrings and assertions
    ${STAGING_BINDIR_NATIVE}/python3-native/python3 -OO -m compileall -f -q ${D}${PYTHON_SITEPACKAGES_DIR}/calculinux_update
}

install_entrypoint() {
    install -d ${D}${bindir}
    install -d ${D}${libdir}/calculinux-update
    install -m 0755 ${S}/scripts/cup ${D}${bindir}/cup
    install -m 0755 ${S}/scripts/cup-hook ${D}${libdir}/calculinux-update/cup-hook
    install -m 0755 ${S}/scripts/cup-postreboot ${D}${libdir}/calculinux-update/cup-postreboot
}

install_default_config() {
    install -d ${D}${sysconfdir}/calculinux-update
    install -m 0644 ${S}/config/calculinux-update.toml ${D}${sysconfdir}/calculinux-update/calculinux-update.toml
}

install_state_dirs() {
    install -d ${D}${localstatedir}/cache/calculinux-update/prefetch
    install -d ${D}${localstatedir}/lib/calculinux-update
}

install_man_page() {
    install -d ${D}${mandir}/man1
    install -m 0644 ${S}/man/cup.1 ${D}${mandir}/man1/cup.1
}

install_service() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/systemd/cup-postreboot.service ${D}${systemd_system_unitdir}/cup-postreboot.service
}

do_install() {
    install_python_package
    install_entrypoint
    install_default_config
    install_state_dirs
    install_man_page
    install_service
}
