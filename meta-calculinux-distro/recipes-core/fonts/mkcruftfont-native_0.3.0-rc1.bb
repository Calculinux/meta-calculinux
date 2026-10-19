SUMMARY = "Build CRUFTFN1 console fonts (native)"
DESCRIPTION = "Host tool mkcruftfont from Calculinux/cruft — single source of truth \
for font blob layout. Font recipes must DEPEND on this instead of bundling a copy."

HOMEPAGE = "https://github.com/Calculinux/cruft"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0a1f0030369f9d1f26870e0bfc24c47b"

# Tracks the v0.3.0-rc1 tag alongside
# recipes-core/cruft/cruft_0.3.0-rc1.bb (same upstream revision; move
# both to the next tag together).
SRC_URI = "git://github.com/Calculinux/cruft.git;protocol=https;tag=v0.3.0-rc1;nobranch=1"
SRCREV = "5f009aa0c7ab3725c8d2550dd8d1960c782614e3"

S = "${WORKDIR}/git"

inherit native

do_configure[noexec] = "1"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -std=c99 -O2 \
        -o ${B}/mkcruftfont ${S}/tools/mkcruftfont.c
    ${B}/mkcruftfont --self-check
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/mkcruftfont ${D}${bindir}/mkcruftfont
}
