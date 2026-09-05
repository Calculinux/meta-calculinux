SUMMARY = "Build CRUFTFN1 console fonts (native)"
DESCRIPTION = "Host tool mkcruftfont from Calculinux/cruft — single source of truth \
for font blob layout. Font recipes must DEPEND on this instead of bundling a copy."

HOMEPAGE = "https://github.com/Calculinux/cruft"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0a1f0030369f9d1f26870e0bfc24c47b"

SRC_URI = "git://github.com/Calculinux/cruft.git;protocol=https;branch=main"
# Keep in sync with recipes-core/cruft/cruft_git.bb SRCREV (bump both together).
SRCREV = "d4a83c30caa33de9c11f145a8fe362ee025ea4c1"
PV = "0.1.0+git${SRCPV}"

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
