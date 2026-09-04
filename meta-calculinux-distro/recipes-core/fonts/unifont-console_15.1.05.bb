SUMMARY = "Demand-paged GNU Unifont blob for the cruft console (optional BMP/CJK profile)"
DESCRIPTION = "Converts GNU Unifont .hex into a native 8x16 CRUFTFN1 mmap-friendly glyph \
file used by cruft when CRUFT_FONT / CONSOLE_FONT=unifont points at this blob. Full \
BMP/CJK coverage for sessions that need Han ideographs beyond the default 6x12 font."

LICENSE = "GPL-2.0-or-later | OFL-1.1"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-or-later;md5=fed54355545ffd980b814dab4a3b312c \
                    file://${COMMON_LICENSE_DIR}/OFL-1.1;md5=fac3a519e5e9eb96316656e0ca4f2b90"

PV = "15.1.05"

SRC_URI = "https://unifoundry.com/pub/unifont/unifont-${PV}/font-builds/unifont-${PV}.hex.gz;downloadfilename=unifont-${PV}.hex.gz"
SRC_URI[sha256sum] = "e2b2e2c3c85a26e76afec499d27be66f2ebb356be6634cc2f3339e6a41026eeb"

S = "${UNPACKDIR}"
B = "${WORKDIR}/build"

DEPENDS = "python3-native mkcruftfont-native"

do_configure[noexec] = "1"

do_compile() {
    mkdir -p ${B}

    ${STAGING_BINDIR_NATIVE}/mkcruftfont --self-check

    if [ -f ${UNPACKDIR}/unifont-${PV}.hex ]; then
        HEX=${UNPACKDIR}/unifont-${PV}.hex
    elif [ -f ${UNPACKDIR}/unifont-${PV}.hex.gz ]; then
        gunzip -c ${UNPACKDIR}/unifont-${PV}.hex.gz > ${B}/unifont.hex
        HEX=${B}/unifont.hex
    else
        bbfatal "unifont-${PV}.hex not found in UNPACKDIR"
    fi

    ${STAGING_BINDIR_NATIVE}/mkcruftfont --cell 8x16 "$HEX" ${B}/unifont.cruftfont

    python3 - <<'PY' ${B}/unifont.cruftfont
import struct, sys
path = sys.argv[1]
with open(path, "rb") as f:
    hdr = f.read(24)
magic, cw, ch, gs, ps = struct.unpack("<8sIIII", hdr)
assert magic == b"CRUFTFN1", magic
assert (cw, ch, gs, ps) == (8, 16, 40, 8), (cw, ch, gs, ps)
print("unifont.cruftfont ok:", cw, "x", ch)
PY
}

do_install() {
    install -d ${D}${datadir}/cruft
    install -m 0644 ${B}/unifont.cruftfont ${D}${datadir}/cruft/unifont.cruftfont
}

FILES:${PN} = "${datadir}/cruft/unifont.cruftfont"
