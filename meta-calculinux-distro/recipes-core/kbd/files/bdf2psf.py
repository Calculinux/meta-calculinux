#!/usr/bin/env python3
"""
Convert a bitmap distribution format (BDF) font into a PSF2 console font.

This script creates PSF2 (PC Screen Font version 2) files from BDF (Bitmap 
Distribution Format) sources. PSF2 is the format used by the Linux console.

PSF2 Format Specification:
- Magic number: 0x864AB572
- Header: 32 bytes containing font dimensions and flags  
- Glyph data: Raw bitmap data for each glyph
- Unicode table: UTF-8 encoded codepoints mapping glyphs to Unicode

For fonts with glyphs encoded 0-255, this creates a simple 1:1 Unicode mapping.
For fonts needing more complex mappings, use the standard bdf2psf tool from
the console-setup/bdf2psf package with appropriate .set and .equiv files.
"""

from __future__ import annotations

import argparse
import struct
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List

# PSF2 format constants (from Linux kernel documentation)
PSF2_MAGIC = 0x864AB572
PSF2_HEADER_SIZE = 32
PSF2_HAS_UNICODE_TABLE = 0x01
PSF2_SEPARATOR = 0xFF
PSF2_STARTSEQ = 0xFE


def encode_utf8(codepoint: int) -> bytes:
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


@dataclass
class Glyph:
    encoding: int
    width: int
    height: int
    x_offset: int
    y_offset: int
    bitmap: List[str]


def _bits_from_hex(hex_line: str, width: int) -> List[int]:
    if not hex_line:
        return [0] * width
    byte_len = max(1, (width + 7) // 8)
    value = int(hex_line, 16)
    bits = f"{value:0{byte_len * 8}b}"[-byte_len * 8 :]
    return [1 if b == "1" else 0 for b in bits][-width:]


def _parse_bdf(path: Path) -> tuple[int, int, int, int, Dict[int, Glyph]]:
    glyphs: Dict[int, Glyph] = {}
    font_width = None
    font_bbox_height = None
    ascent = None
    descent = None
    encoding = None
    bbx = None
    reading_bitmap = False
    bitmap_lines: List[str] = []

    with path.open("r", encoding="ascii", errors="ignore") as handle:
        for raw in handle:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("FONTBOUNDINGBOX"):
                parts = line.split()
                font_width = int(parts[1])
                font_bbox_height = int(parts[2])
            elif line.startswith("FONT_ASCENT"):
                ascent = int(line.split()[1])
            elif line.startswith("FONT_DESCENT"):
                descent = int(line.split()[1])
            elif line.startswith("ENCODING"):
                encoding = int(line.split()[1])
            elif line.startswith("BBX"):
                parts = line.split()
                bbx = tuple(int(x) for x in parts[1:])
            elif line == "BITMAP":
                reading_bitmap = True
                bitmap_lines = []
            elif line == "ENDCHAR":
                reading_bitmap = False
                if (
                    encoding is not None
                    and encoding >= 0
                    and bbx is not None
                ):
                    glyphs[encoding] = Glyph(
                        encoding,
                        bbx[0],
                        bbx[1],
                        bbx[2],
                        bbx[3],
                        bitmap_lines[:],
                    )
                encoding = None
                bbx = None
                bitmap_lines = []
            elif reading_bitmap:
                bitmap_lines.append(line)

    if font_width is None or font_bbox_height is None:
        raise ValueError(f"Missing FONTBOUNDINGBOX in {path}")
    if ascent is None or descent is None:
        ascent = font_bbox_height
        descent = 0

    return font_width, ascent + descent, ascent, descent, glyphs


def _render_glyph(
    glyph: Glyph,
    font_width: int,
    font_height: int,
    ascent: int,
) -> bytes:
    bytes_per_row = (font_width + 7) // 8
    canvas = [[0] * font_width for _ in range(font_height)]
    top_pad = ascent - (glyph.height + glyph.y_offset)
    if top_pad < 0:
        top_pad = 0
    row_index = top_pad
    for line in glyph.bitmap:
        if row_index >= font_height:
            break
        bits = _bits_from_hex(line, glyph.width)
        for idx, bit in enumerate(bits):
            dest = glyph.x_offset + idx
            if 0 <= dest < font_width:
                canvas[row_index][dest] = bit
        row_index += 1

    data = bytearray(font_height * bytes_per_row)
    for y, row in enumerate(canvas):
        for x, bit in enumerate(row):
            if bit:
                data[y * bytes_per_row + x // 8] |= (0x80 >> (x % 8))
    return bytes(data)


def bdf_to_psf(bdf_path: Path, psf_path: Path, glyph_count: int) -> None:
    font_width, font_height, ascent, descent, glyphs = _parse_bdf(bdf_path)
    bytes_per_row = (font_width + 7) // 8
    bytes_per_glyph = bytes_per_row * font_height
    psf_path.parent.mkdir(parents=True, exist_ok=True)

    glyph_blob = bytearray()
    unicode_blob = bytearray()

    for codepoint in range(glyph_count):
        glyph = glyphs.get(codepoint)
        if glyph is None:
            glyph_blob.extend(b"\x00" * bytes_per_glyph)
        else:
            glyph_blob.extend(
                _render_glyph(glyph, font_width, font_height, ascent)
            )
        
        # PSF2 Unicode table: UTF-8 encoded codepoints followed by 0xFF separator
        unicode_blob.extend(encode_utf8(codepoint))
        unicode_blob.append(PSF2_SEPARATOR)

    header = struct.pack(
        "<IIIIIIII",
        PSF2_MAGIC,
        0,
        PSF2_HEADER_SIZE,
        PSF2_HAS_UNICODE_TABLE,
        glyph_count,
        bytes_per_glyph,
        font_height,
        font_width,
    )

    with psf_path.open("wb") as handle:
        handle.write(header)
        handle.write(glyph_blob)
        handle.write(unicode_blob)


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert BDF font to PSF2")
    parser.add_argument("bdf", type=Path)
    parser.add_argument("psf", type=Path)
    parser.add_argument(
        "--glyph-count",
        type=int,
        default=256,
        help="Number of glyphs to emit (default: 256)",
    )
    args = parser.parse_args()
    bdf_to_psf(args.bdf, args.psf, args.glyph_count)


if __name__ == "__main__":
    main()
