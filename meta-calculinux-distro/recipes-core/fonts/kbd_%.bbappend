FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://enhance-psf-unicode.py"

DEPENDS += "python3-native"

do_install:append() {
    # Enhance kbd console fonts with additional Unicode mappings for better international support
    # This adds mappings for common characters like smart quotes, various dashes, etc.
    # Note: Terminus fonts (ter-*) are handled by terminus-font_%.bbappend
    
    cd ${D}${datadir}/consolefonts
    
    # Process kbd's own fonts (lat*, iso*)
    for font in lat*.psf* iso*.psf*; do
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
