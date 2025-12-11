SUMMARY = "Terminus console font"
DESCRIPTION = "Monospaced font designed for long (8+ hours per day) work with computers. \
Contains 1326 characters, supports about 120 language sets, many IBM, Windows and Macintosh \
code pages, IBM VGA / vt100 / xterm pseudographic characters and Esperanto. \
The PSF fonts include Unicode mapping tables for proper character coverage."

LICENSE = "OFL-1.1"
LIC_FILES_CHKSUM = "file://OFL.TXT;md5=f57e6cca943dbc6ef83dc14f1855bdcc"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = "https://download.sourceforge.net/${BPN}/${BPN}-${PV}.tar.gz \
           file://enhance-psf-unicode.py \
           "
SRC_URI[sha256sum] = "d961c1b781627bf417f9b340693d64fc219e0113ad3a3af1a3424c7aa373ef79"

DEPENDS = "bdftopcf-native python3-native"
RDEPENDS:${PN} = "console-tools"

do_configure () {
    # Configure terminus to build PSF fonts with Unicode mapping tables
    ${S}/configure --prefix=${prefix} --psfdir=${datadir}/consolefonts
}

do_compile () {
    # Build PSF fonts - these automatically include Unicode mapping tables
    # The ter-vXXn variants have particularly good Unicode codepoint mapping
    oe_runmake psf
}

do_install () {
    # Install PSF fonts with Unicode mappings to /usr/share/consolefonts
    oe_runmake install-psf DESTDIR=${D}
    
    # Enhance Terminus console fonts with additional Unicode mappings
    # This adds fallback mappings for common characters like smart quotes, various dashes, etc.
    
    cd ${D}${datadir}/consolefonts
    
    for font in ter-*.psf*; do
        [ -f "$font" ] || continue
        
        bbdebug 1 "Processing font: $font"
        
        # Decompress if needed
        if echo "$font" | grep -q '\.gz$'; then
            gunzip -c "$font" > "${font%.gz}.tmp"
            input_font="${font%.gz}.tmp"
            output_font="${font%.gz}.enhanced"
            needs_compress=1
        else
            input_font="$font"
            output_font="${font}.enhanced"
            needs_compress=0
        fi
        
        # Enhance the font
        if python3 ${WORKDIR}/enhance-psf-unicode.py "$input_font" "$output_font"; then
            # Replace original with enhanced version
            if [ "$needs_compress" = "1" ]; then
                gzip -c "$output_font" > "$font"
                rm -f "${font%.gz}.tmp" "$output_font"
            else
                mv "$output_font" "$font"
            fi
            bbnote "Enhanced $font with additional Unicode mappings"
        else
            bbwarn "Failed to enhance $font, keeping original"
            rm -f "${input_font}.tmp" "$output_font"
        fi
    done
}

FILES:${PN} = "${datadir}/consolefonts/"
