SUMMARY = "Ultimate Oldschool PC console fonts"
DESCRIPTION = "Bitmap console font collection based on VileR's Ultimate Oldschool PC Font Pack. Fonts are converted to PSF for use with setfont and the Linux console."
HOMEPAGE = "https://int10h.org/oldschool-pc-fonts/"
LICENSE = "CC-BY-SA-4.0"
LIC_FILES_CHKSUM = "file://LICENSE.TXT;md5=e277f2eefa979e093628e4fb368f5044"

# Use shared scripts from kbd files directory
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = "https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v${PV}_linux.zip \
           file://simple.equivalents \
           file://unicode-all.set \
           file://enhance-psf-unicode.py \
           "
SRC_URI[sha256sum] = "b30dc3ecc9931ad2dd8be7517dd01813c8834a1911b582ab7643191b41a3d759"

S = "${WORKDIR}/oldschool_pc_font_pack_v${PV}_linux"

inherit allarch python3native

DEPENDS += "fontforge-native bdf2psf-native python3-native"

FONT_SUBDIR = "otb - Bm (linux bitmap)"
PSF_OUT_DIR = "${B}/psf"

# Set environment for fontforge
FONTFORGE_LANGUAGE = "en"
export FONTFORGE_LANGUAGE

do_compile() {
    font_dir="${S}/${FONT_SUBDIR}"
    bdf_dir="${B}/bdf"
    psf_dir="${PSF_OUT_DIR}"

    install -d "$bdf_dir" "$psf_dir"

    # Convert OTB (bitmap OpenType) fonts to BDF using fontforge
    find "$font_dir" -type f -name '*.otb' -print0 | while IFS= read -r -d '' src; do
        base=$(basename "$src" .otb)
        target="$bdf_dir/${base}.bdf"
        
        # Use fontforge to convert OTB to BDF
        fontforge -lang=ff -c "Open(\$1); SelectWorthOutputting(); Generate(\$2)" "$src" "$target"
        
        if [ ! -f "$target" ]; then
            # Sometimes fontforge adds a suffix, try to find it
            generated=$(find "$bdf_dir" -maxdepth 1 -type f -name "${base}-*.bdf" -print -quit)
            if [ -n "$generated" ]; then
                mv "$generated" "$target"
            else
                bbfatal "Failed to convert $src into BDF"
            fi
        fi
        
        # Convert BDF to PSF2 format using standard bdf2psf tool
        # The fonts already have Unicode encodings, so we use minimal mapping files
        bdf2psf --log "$psf_dir/${base}.log" \
            "$target" \
            "${WORKDIR}/simple.equivalents" \
            "${WORKDIR}/unicode-all.set" \
            256 \
            "$psf_dir/${base}.psf" || bbfatal "Failed to convert $target to PSF"
    done
}

do_install() {
    install -d ${D}${datadir}/consolefonts/oldschool
    install -m 0644 ${PSF_OUT_DIR}/*.psf ${D}${datadir}/consolefonts/oldschool/
    
    # Enhance oldschool console fonts with additional Unicode mappings
    # This adds fallback mappings for common characters like smart quotes, various dashes, etc.
    
    cd ${D}${datadir}/consolefonts/oldschool
    
    for font in *.psf; do
        [ -f "$font" ] || continue
        
        bbdebug 1 "Processing font: $font"
        
        # Enhance the font
        if python3 ${WORKDIR}/enhance-psf-unicode.py "$font" "${font}.enhanced"; then
            mv "${font}.enhanced" "$font"
            bbnote "Enhanced $font with additional Unicode mappings"
        else
            bbwarn "Failed to enhance $font, keeping original"
            rm -f "${font}.enhanced"
        fi
    done
}

FILES:${PN} = "${datadir}/consolefonts/oldschool"

RDEPENDS:${PN} = "console-tools"
