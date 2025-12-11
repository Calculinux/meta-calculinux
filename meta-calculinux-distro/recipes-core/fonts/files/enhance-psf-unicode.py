#!/usr/bin/env python3
"""
Enhance PSF console fonts with additional Unicode mappings.

This script adds mappings for commonly missing Unicode codepoints to existing
glyphs, improving international character support. It uses the PSF2 format's
Unicode mapping table to map similar-looking characters to available glyphs.

Common mappings added:
- U+2010 (HYPHEN) → U+002D (HYPHEN-MINUS)
- U+2011 (NON-BREAKING HYPHEN) → U+002D
- U+2012 (FIGURE DASH) → U+002D
- U+2013 (EN DASH) → U+002D
- U+2014 (EM DASH) → U+002D  
- U+2015 (HORIZONTAL BAR) → U+002D
- U+2212 (MINUS SIGN) → U+002D
- U+2018 (LEFT SINGLE QUOTATION MARK) → U+0027 (APOSTROPHE)
- U+2019 (RIGHT SINGLE QUOTATION MARK) → U+0027
- U+201C (LEFT DOUBLE QUOTATION MARK) → U+0022 (QUOTATION MARK)
- U+201D (RIGHT DOUBLE QUOTATION MARK) → U+0022
"""

import struct
import sys
from pathlib import Path

# PSF2 format constants
PSF2_MAGIC = b'\x72\xb5\x4a\x86'
PSF2_HAS_UNICODE_TABLE = 0x01
PSF2_SEPARATOR = 0xFF
PSF2_STARTSEQ = 0xFE

# Unicode mappings to add: target_codepoint -> source_glyph_codepoint
UNICODE_MAPPINGS = {
    # Dashes and hyphens → ASCII hyphen-minus
    0x2010: 0x002D,  # HYPHEN
    0x2011: 0x002D,  # NON-BREAKING HYPHEN
    0x2012: 0x002D,  # FIGURE DASH
    0x2013: 0x002D,  # EN DASH
    0x2014: 0x002D,  # EM DASH
    0x2015: 0x002D,  # HORIZONTAL BAR
    0x2212: 0x002D,  # MINUS SIGN
    
    # Smart quotes → ASCII quotes
    0x2018: 0x0027,  # LEFT SINGLE QUOTATION MARK → APOSTROPHE
    0x2019: 0x0027,  # RIGHT SINGLE QUOTATION MARK → APOSTROPHE
    0x201A: 0x0027,  # SINGLE LOW-9 QUOTATION MARK → APOSTROPHE
    0x201B: 0x0027,  # SINGLE HIGH-REVERSED-9 QUOTATION MARK → APOSTROPHE
    0x201C: 0x0022,  # LEFT DOUBLE QUOTATION MARK → QUOTATION MARK
    0x201D: 0x0022,  # RIGHT DOUBLE QUOTATION MARK → QUOTATION MARK
    0x201E: 0x0022,  # DOUBLE LOW-9 QUOTATION MARK → QUOTATION MARK
    0x201F: 0x0022,  # DOUBLE HIGH-REVERSED-9 QUOTATION MARK → QUOTATION MARK
    
    # Additional useful mappings
    0x00A0: 0x0020,  # NO-BREAK SPACE → SPACE
    0x2022: 0x002A,  # BULLET → ASTERISK
    0x2026: 0x002E,  # HORIZONTAL ELLIPSIS → PERIOD (will show as ...)
    0x2032: 0x0027,  # PRIME → APOSTROPHE
    0x2033: 0x0022,  # DOUBLE PRIME → QUOTATION MARK
}


def read_utf8_char(data, offset):
    """Read a UTF-8 encoded character from bytes."""
    if offset >= len(data):
        return None, offset
    
    byte = data[offset]
    if byte == PSF2_SEPARATOR or byte == PSF2_STARTSEQ:
        return byte, offset + 1
    
    # Determine UTF-8 character length
    if byte < 0x80:
        return byte, offset + 1
    elif byte < 0xE0:
        if offset + 1 >= len(data):
            return None, offset
        char = ((byte & 0x1F) << 6) | (data[offset + 1] & 0x3F)
        return char, offset + 2
    elif byte < 0xF0:
        if offset + 2 >= len(data):
            return None, offset
        char = ((byte & 0x0F) << 12) | ((data[offset + 1] & 0x3F) << 6) | (data[offset + 2] & 0x3F)
        return char, offset + 3
    else:
        if offset + 3 >= len(data):
            return None, offset
        char = ((byte & 0x07) << 18) | ((data[offset + 1] & 0x3F) << 12) | \
               ((data[offset + 2] & 0x3F) << 6) | (data[offset + 3] & 0x3F)
        return char, offset + 4


def encode_utf8(codepoint):
    """Encode a Unicode codepoint as UTF-8 bytes."""
    if codepoint < 0x80:
        return bytes([codepoint])
    elif codepoint < 0x800:
        return bytes([0xC0 | (codepoint >> 6), 0x80 | (codepoint & 0x3F)])
    elif codepoint < 0x10000:
        return bytes([0xE0 | (codepoint >> 12), 
                      0x80 | ((codepoint >> 6) & 0x3F), 
                      0x80 | (codepoint & 0x3F)])
    else:
        return bytes([0xF0 | (codepoint >> 18),
                      0x80 | ((codepoint >> 12) & 0x3F),
                      0x80 | ((codepoint >> 6) & 0x3F),
                      0x80 | (codepoint & 0x3F)])


def enhance_psf_font(input_path, output_path):
    """Enhance a PSF2 font with additional Unicode mappings."""
    with open(input_path, 'rb') as f:
        data = f.read()
    
    # Check if this is a PSF2 font
    if data[:4] != PSF2_MAGIC:
        print(f"Skipping {input_path}: not a PSF2 font", file=sys.stderr)
        return False
    
    # Parse header
    header = struct.unpack('<4sIIIIIII', data[:32])
    magic, version, headersize, flags, length, charsize, height, width = header
    
    if not (flags & PSF2_HAS_UNICODE_TABLE):
        print(f"Skipping {input_path}: no Unicode table", file=sys.stderr)
        return False
    
    # Extract font bitmap data
    bitmaps_end = headersize + (length * charsize)
    bitmaps = data[headersize:bitmaps_end]
    unicode_table = data[bitmaps_end:]
    
    # Parse existing Unicode table to find which glyph has which codepoint
    glyph_mappings = [[] for _ in range(length)]  # List of codepoints for each glyph
    offset = 0
    current_glyph = 0
    
    while offset < len(unicode_table) and current_glyph < length:
        char, offset = read_utf8_char(unicode_table, offset)
        if char is None:
            break
        if char == PSF2_SEPARATOR:
            current_glyph += 1
        elif char == PSF2_STARTSEQ:
            # Skip sequences for now
            while offset < len(unicode_table):
                char, offset = read_utf8_char(unicode_table, offset)
                if char is None or char == PSF2_SEPARATOR:
                    current_glyph += 1
                    break
        else:
            glyph_mappings[current_glyph].append(char)
    
    # Find which glyph we need to map new codepoints to
    codepoint_to_glyph = {}
    for glyph_idx, codepoints in enumerate(glyph_mappings):
        for cp in codepoints:
            codepoint_to_glyph[cp] = glyph_idx
    
    # Add new mappings
    new_mappings_added = 0
    for target_cp, source_cp in UNICODE_MAPPINGS.items():
        if target_cp not in codepoint_to_glyph and source_cp in codepoint_to_glyph:
            glyph_idx = codepoint_to_glyph[source_cp]
            glyph_mappings[glyph_idx].append(target_cp)
            codepoint_to_glyph[target_cp] = glyph_idx
            new_mappings_added += 1
    
    if new_mappings_added == 0:
        print(f"No new mappings needed for {input_path}")
        return False
    
    # Rebuild Unicode table
    new_unicode_table = bytearray()
    for glyph_idx, codepoints in enumerate(glyph_mappings):
        for cp in sorted(codepoints):  # Sort for consistency
            new_unicode_table.extend(encode_utf8(cp))
        new_unicode_table.append(PSF2_SEPARATOR)
    
    # Write enhanced font
    with open(output_path, 'wb') as f:
        f.write(data[:bitmaps_end])  # Header + bitmaps
        f.write(new_unicode_table)
    
    print(f"Enhanced {input_path} -> {output_path} ({new_mappings_added} new mappings)")
    return True


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <input.psf> <output.psf>")
        sys.exit(1)
    
    input_file = Path(sys.argv[1])
    output_file = Path(sys.argv[2])
    
    try:
        if enhance_psf_font(input_file, output_file):
            sys.exit(0)
        else:
            sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
