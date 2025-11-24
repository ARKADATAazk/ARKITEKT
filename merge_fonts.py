#!/usr/bin/env python3
"""
Merge Roboto with DejaVu Sans - keeps all Roboto glyphs,
adds ALL missing glyphs from DejaVu Sans
"""

from fontTools.ttLib import TTFont
import sys

def merge_fonts(base_path, donor_path, output_path):
    """
    Merge fonts: keep all glyphs from base, add missing glyphs from donor
    """
    print(f"Loading base font: {base_path}")
    base = TTFont(base_path)

    print(f"Loading donor font: {donor_path}")
    donor = TTFont(donor_path)

    # Get character maps
    base_cmap = base['cmap'].getBestCmap()
    donor_cmap = donor['cmap'].getBestCmap()

    # Find glyphs in donor that are missing from base
    missing_codepoints = set(donor_cmap.keys()) - set(base_cmap.keys())

    print(f"\nFound {len(missing_codepoints)} glyphs in DejaVu that Roboto doesn't have")
    print(f"Adding them to {output_path}...")

    # Track special characters
    special_chars = {0x22EE: '⋮', 0x2191: '↑', 0x2193: '↓'}
    found_special = []

    copied = 0
    for codepoint in missing_codepoints:
        glyph_name = donor_cmap[codepoint]

        try:
            # Copy glyph outline data (TrueType format)
            if 'glyf' in donor and glyph_name in donor['glyf']:
                base['glyf'][glyph_name] = donor['glyf'][glyph_name]

            # Copy metrics (width, height)
            if glyph_name in donor['hmtx']:
                base['hmtx'][glyph_name] = donor['hmtx'][glyph_name]

            # Update character map
            base_cmap[codepoint] = glyph_name

            copied += 1

            # Track our special characters
            if codepoint in special_chars:
                found_special.append(f"U+{codepoint:04X} ({special_chars[codepoint]})")

        except Exception as e:
            print(f"Warning: Couldn't copy U+{codepoint:04X}: {e}")

    # Save merged font
    base.save(output_path)

    print(f"\n✓ Success! Created: {output_path}")
    print(f"  Copied {copied} new glyphs from DejaVu to Roboto")

    if found_special:
        print(f"\n  Key glyphs added:")
        for glyph in found_special:
            print(f"    • {glyph}")

if __name__ == "__main__":
    import os

    # Paths to your fonts
    FONTS_DIR = "/home/user/ARKITEKT-Toolkit/ARKITEKT/arkitekt/fonts/"

    print("=" * 70)
    print("  Roboto + DejaVu Font Merger")
    print("=" * 70)
    print()

    # Merge Regular weight
    print("Merging Regular weight...")
    merge_fonts(
        base_path=FONTS_DIR + "Roboto-Regular.ttf",
        donor_path=FONTS_DIR + "DejaVuSans.ttf",
        output_path=FONTS_DIR + "Roboto-Extended-Regular.ttf"
    )

    print("\n" + "=" * 70 + "\n")

    # Merge Medium weight
    print("Merging Medium weight...")
    merge_fonts(
        base_path=FONTS_DIR + "Roboto-Medium.ttf",
        donor_path=FONTS_DIR + "DejaVuSans-Bold.ttf",
        output_path=FONTS_DIR + "Roboto-Extended-Medium.ttf"
    )

    print("\n" + "=" * 70)
    print("✓ All done!")
    print()
    print("Created fonts:")
    print("  • Roboto-Extended-Regular.ttf")
    print("  • Roboto-Extended-Medium.ttf")
    print()
    print("Update fonts.lua to use these new fonts.")
    print("=" * 70)
