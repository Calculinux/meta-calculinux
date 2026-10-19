SUMMARY = "Build CRUFTFN1 console fonts (native)"
DESCRIPTION = "Host tool mkcruftfont from Calculinux/cruft — single source of truth \
for font blob layout. Font recipes must DEPEND on this instead of bundling a copy."

HOMEPAGE = "https://github.com/Calculinux/cruft"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0a1f0030369f9d1f26870e0bfc24c47b"

# TEMP (revert with cruft_git.bb when the full stack — cruft
# #4/#5/#6/#10/#11/#14 — merges): fetch from the stack-tip branch so
# this SRCREV (the branch tip) resolves against branch=.
SRC_URI = "git://github.com/Calculinux/cruft.git;protocol=https;branch=feat/image-tests"
# Keep in sync with recipes-core/cruft/cruft_git.bb SRCREV (bump both together).
SRCREV = "5f009aa0c7ab3725c8d2550dd8d1960c782614e3"
PV = "0.2.10+git${SRCPV}"

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
