SUMMARY = "Miniwi 4x8 cruft console font"
DESCRIPTION = "Tiny 4x8 bitmap font (geekmaster/miniwi) packaged as a demand-paged \
CRUFTFN1 blob for the cruft framebuffer console. On a 320x320 PicoCalc panel this \
yields an 80x40 character grid. Select via CONSOLE_FONT=miniwi in /etc/default/console."

LICENSE = "WTFPL"
LIC_FILES_CHKSUM = "file://LICENCE;md5=f312a7c4d02230e8f2b537295d375c69"

SRC_URI = "git://github.com/geekmaster/miniwi.git;protocol=https;branch=master \
           file://mkcruftfont.c \
           "
SRCREV = "32b4633bdb1cdedc9b472804cea085ddb7c7da60"
PV = "1.0+git${SRCPV}"

S = "${WORKDIR}/git"
B = "${WORKDIR}/build"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

DEPENDS = "python3-native"

do_configure[noexec] = "1"

do_compile() {
    mkdir -p ${B}

    ${BUILD_CC} ${BUILD_CFLAGS} ${BUILD_LDFLAGS} -std=c11 -O2 \
        -o ${B}/mkcruftfont ${UNPACKDIR}/mkcruftfont.c
    ${B}/mkcruftfont --self-check

    ${B}/mkcruftfont --cell 4x8 ${S}/miniwi-8.bdf ${B}/miniwi.cruftfont

    python3 - <<'PY' ${B}/miniwi.cruftfont
import os, struct, sys
path = sys.argv[1]
with open(path, "rb") as f:
    hdr = f.read(24)
magic, cw, ch, gs, ps = struct.unpack("<8sIIII", hdr)
assert magic == b"CRUFTFN1", magic
assert (cw, ch, gs, ps) == (4, 8, 24, 8), (cw, ch, gs, ps)
size = os.path.getsize(path)
assert size > 50000, size
print("miniwi.cruftfont ok:", cw, "x", ch, size, "bytes")
PY
}

do_install() {
    install -d ${D}${datadir}/cruft
    install -m 0644 ${B}/miniwi.cruftfont ${D}${datadir}/cruft/miniwi.cruftfont
}

FILES:${PN} = "${datadir}/cruft/miniwi.cruftfont"
