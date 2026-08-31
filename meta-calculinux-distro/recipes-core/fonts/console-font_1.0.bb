SUMMARY = "Default 6x12 yaft console font (Terminus + Fairfax)"
DESCRIPTION = "Native 6x12 bitmap merge for the yaft framebuffer console: Terminus \
ter-u12n (sharp Latin) with Fairfax filling kana, symbols, and extended Unicode. \
Fairfax.kbitx is converted to BDF at build time via kbitx2bdf-native. \
Demand-paged mmap blob for the Luckfox Lyra 128 MB RAM budget."

LICENSE = "OFL-1.1"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/OFL-1.1;md5=fac3a519e5e9eb96316656e0ca4f2b90"

PV = "1.0"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

TERMINUS_PV = "4.49.1"

SRC_URI = "https://download.sourceforge.net/terminus-font/terminus-font-${TERMINUS_PV}.tar.gz;name=terminus \
           https://raw.githubusercontent.com/kreativekorp/open-relay/master/Fairfax/Fairfax.kbitx;name=fairfax \
           file://mkyaftfont.c \
           "
SRC_URI[terminus.sha256sum] = "d961c1b781627bf417f9b340693d64fc219e0113ad3a3af1a3424c7aa373ef79"
SRC_URI[fairfax.sha256sum] = "439247d7e783bf4a2cf5912bc914fc64c025d53edbfa79ea1d23066275473e68"

S = "${UNPACKDIR}"
B = "${WORKDIR}/build"

DEPENDS = "kbitx2bdf-native"

do_configure[noexec] = "1"

do_compile() {
    mkdir -p ${B}

    ${BUILD_CC} ${BUILD_CFLAGS} ${BUILD_LDFLAGS} -std=c11 -O2 \
        -o ${B}/mkyaftfont ${UNPACKDIR}/mkyaftfont.c
    ${B}/mkyaftfont --self-check

    TER_BDF=${UNPACKDIR}/terminus-font-${TERMINUS_PV}/ter-u12n.bdf
    FFX_KBITX=${UNPACKDIR}/Fairfax.kbitx
    FFX_BDF=${B}/Fairfax.bdf

    [ -f "$TER_BDF" ] || bbfatal "ter-u12n.bdf not found in Terminus tarball"
    [ -f "$FFX_KBITX" ] || bbfatal "Fairfax.kbitx not found"

    ${STAGING_BINDIR_NATIVE}/kbitx2bdf "$FFX_KBITX" "$FFX_BDF"
    [ -s "$FFX_BDF" ] || bbfatal "kbitx2bdf failed to export Fairfax.bdf"

    ${B}/mkyaftfont --cell 6x12 "$TER_BDF" "$FFX_BDF" ${B}/console.yaftfont

    python3 - <<'PY' ${B}/console.yaftfont
import struct, sys
path = sys.argv[1]
with open(path, "rb") as f:
    hdr = f.read(24)
magic, cw, ch, gs, _ = struct.unpack("<8sIIII", hdr)
assert magic == b"YAFTFNT1", magic
assert (cw, ch, gs) == (6, 12, 32), (cw, ch, gs)
size = f.seek(0, 2)
assert size > 500000, size
print("console.yaftfont ok:", cw, "x", ch, size, "bytes")
PY
}

do_install() {
    install -d ${D}${datadir}/yaft
    install -m 0644 ${B}/console.yaftfont ${D}${datadir}/yaft/console.yaftfont
}

FILES:${PN} = "${datadir}/yaft/console.yaftfont"
