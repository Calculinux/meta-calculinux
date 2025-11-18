SUMMARY = "CLI frontend for Calculinux RAUC update bundles"
HOMEPAGE = "https://github.com/Calculinux/calculinux-update"
DESCRIPTION = "Typer-based helper that lists Calculinux RAUC bundles from the mirror, \ 
validates checksums, and launches installs via rauc."

LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

SRC_URI = "git://github.com/Calculinux/calculinux-update.git;branch=main;protocol=https"
SRCREV = "b3671cf86761c3861856cb10708458842c292785"

S = "${WORKDIR}/git"

inherit python3-dir python3native

RDEPENDS:${PN} += " \
    python3-core \
    python3-tomllib \
    python3-httpx \
    python3-rich \
    python3-typer \
    python3-typing-extensions \
    rauc \
"

FILES:${PN} += "${PYTHON_SITEPACKAGES_DIR}"

install_python_package() {
    install -d ${D}${PYTHON_SITEPACKAGES_DIR}
    cp -r ${S}/src/calculinux_update ${D}${PYTHON_SITEPACKAGES_DIR}/
}

install_entrypoint() {
    install -d ${D}${bindir}
    cat <<'EOF' > ${D}${bindir}/calculinux-update
#!/usr/bin/env python3
from calculinux_update.cli import app

if __name__ == "__main__":
    app()
EOF
    chmod 0755 ${D}${bindir}/calculinux-update
}

do_install() {
    install_python_package
    install_entrypoint
}
