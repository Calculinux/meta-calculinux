SUMMARY = "Build CRUFTFN1 console fonts (native)"
DESCRIPTION = "Host tool mkcruftfont from Calculinux/cruft — single source of truth \
for font blob layout. Font recipes must DEPEND on this instead of bundling a copy."

HOMEPAGE = "https://github.com/Calculinux/cruft"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0a1f0030369f9d1f26870e0bfc24c47b"

# TEMP (revert with cruft_git.bb when the scrollback stack — cruft
# #4/#5/#6/#10 — merges): fetch from the stack-tip branch so this SRCREV
# (the branch tip) resolves against branch=.
SRC_URI = "git://github.com/Calculinux/cruft.git;protocol=https;branch=feat/sb-disk"
# Keep in sync with recipes-core/cruft/cruft_git.bb SRCREV (bump both together).
SRCREV = "5c19d54843d41a0df6a6f7eb0dea7c2783183e6f"
PV = "0.2.9+git${SRCPV}"

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
