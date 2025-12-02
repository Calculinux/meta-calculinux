SUMMARY = "Hoard of Bitfonts - Bitmap fonts from classic systems"
DESCRIPTION = "A collection of bitmapped fonts from disused operating systems and \
graphical user interfaces (1980s-1990s). Fonts are converted from YAFF format \
to PSF for Linux console use."

HOMEPAGE = "https://github.com/robhagemans/hoard-of-bitfonts"
SECTION = "fonts"
LICENSE = "MIT & OFL-1.1 & PD"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=bb4f3c7e024810b7ec7c501b1a0db5fc"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = "git://github.com/robhagemans/hoard-of-bitfonts.git;protocol=https;branch=master \
           file://enhance-psf-unicode.py \
          "
SRCREV = "${AUTOREV}"

S = "${WORKDIR}/git"

DEPENDS = "python3-native"

inherit python3native

# Install monobit converter at build time
do_configure:prepend() {
    # Install monobit Python package
    ${PYTHON} -m pip install --target=${WORKDIR}/monobit-install monobit
}

do_compile() {
    export PYTHONPATH="${WORKDIR}/monobit-install:${PYTHONPATH}"
    
    # Create output directory
    mkdir -p ${B}/psf-fonts
    
    # Convert fonts from the specified collection
    # FONT_COLLECTION should be set by the specific recipe
    if [ -n "${FONT_COLLECTION}" ]; then
        for font in ${S}/${FONT_COLLECTION}/*.yaff; do
            [ -f "$font" ] || continue
            base=$(basename "$font" .yaff)
            
            # Convert YAFF to PSF using monobit
            ${PYTHON} -m monobit.convert "$font" to "${B}/psf-fonts/${base}.psf" || \
                bbwarn "Failed to convert $base"
        done
    fi
    
    # Apply Unicode enhancements to converted fonts
    for font in ${B}/psf-fonts/*.psf; do
        [ -f "$font" ] || continue
        
        if python3 ${WORKDIR}/enhance-psf-unicode.py "$font" "${font}.enhanced"; then
            mv "${font}.enhanced" "$font"
            bbnote "Enhanced $(basename $font) with additional Unicode mappings"
        fi
    done
}

do_install() {
    install -d ${D}${datadir}/consolefonts
    
    # Install converted PSF fonts
    if [ -d ${B}/psf-fonts ] && [ "$(ls -A ${B}/psf-fonts)" ]; then
        install -m 0644 ${B}/psf-fonts/*.psf ${D}${datadir}/consolefonts/
    fi
}

FILES:${PN} = "${datadir}/consolefonts"

RDEPENDS:${PN} = "kbd"
