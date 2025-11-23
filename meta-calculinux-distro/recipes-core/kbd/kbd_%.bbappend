FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://enhance-psf-unicode.py"

DEPENDS += "python3-native"

do_install:append() {
    # Enhance console fonts with additional Unicode mappings for better international support
    # This adds mappings for common characters like smart quotes, various dashes, etc.
    
    cd ${D}${datadir}/consolefonts
    
    # Process both kbd fonts (lat*, iso*) and terminus fonts (ter*)
    for font in lat*.psf* iso*.psf* ter*.psf*; do
        [ -f "$font" ] || continue
        
        # Skip if already processed
        [ -f "${font}.enhanced" ] && continue
        
        # Decompress if needed
        if echo "$font" | grep -q '\.gz$'; then
            gunzip -c "$font" > "${font%.gz}.tmp"
            input_font="${font%.gz}.tmp"
            needs_compress=1
        else
            input_font="$font"
            needs_compress=0
        fi
        
        # Enhance the font
        python3 ${UNPACKDIR}/enhance-psf-unicode.py "$input_font" "${input_font}.enhanced" || continue
        
        # Replace original with enhanced version
        if [ "$needs_compress" = "1" ]; then
            gzip -c "${input_font}.enhanced" > "$font"
            rm -f "${input_font}.tmp" "${input_font}.enhanced"
        else
            mv "${input_font}.enhanced" "$font"
        fi
        
        bbwarn "Enhanced $font with additional Unicode mappings"
    done
}
