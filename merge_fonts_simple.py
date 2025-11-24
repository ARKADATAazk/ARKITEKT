#!/usr/bin/env python3
"""
Merge specific glyphs from DejaVu into Roboto
Only copies the 3 characters we need: ⋮, ↑, ↓
"""

from fontTools.ttLib import TTFont
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

def copy_simple_glyph(base_font, donor_font, codepoint):
    """Copy a single glyph safely"""
    donor_cmap = donor_font['cmap'].getBestCmap()
    base_cmap = base_font['cmap'].getBestCmap()

    if codepoint not in donor_cmap:
        print(f"  Warning: U+{codepoint:04X} not found in donor font")
        return False

    glyph_name = donor_cmap[codepoint]

    try:
        # For simple glyphs, just copy the data
        if glyph_name in donor_font['glyf']:
            # Get the glyph
            donor_glyph = donor_font['glyf'][glyph_name]

            # Only copy if it's a simple glyph (not composite)
            if donor_glyph.numberOfContours >= 0:
                base_font['glyf'][glyph_name] = donor_glyph
                base_font['hmtx'][glyph_name] = donor_font['hmtx'][glyph_name]
                base_cmap[codepoint] = glyph_name
                return True
            else:
                print(f"  Skipping composite glyph: {glyph_name}")
                return False
    except Exception as e:
        print(f"  Error copying U+{codepoint:04X}: {e}")
        return False

    return False

def merge_specific_glyphs(base_path, donor_path, output_path, glyphs):
    """Merge only specific glyphs"""
    print(f"Loading base font: {base_path}")
    base = TTFont(base_path)

    print(f"Loading donor font: {donor_path}")
    donor = TTFont(donor_path)

    print(f"\nCopying glyphs:")
    success_count = 0
    for codepoint, char in glyphs.items():
        print(f"  • U+{codepoint:04X} ({char})...", end=" ")
        if copy_simple_glyph(base, donor, codepoint):
            print("✓")
            success_count += 1
        else:
            print("✗")

    if success_count > 0:
        print(f"\nSaving to: {output_path}")
        base.save(output_path)
        print(f"✓ Successfully merged {success_count}/{len(glyphs)} glyphs")
        return True
    else:
        print("✗ No glyphs were successfully copied")
        return False

if __name__ == "__main__":
    FONTS_DIR = "/home/user/ARKITEKT-Toolkit/ARKITEKT/arkitekt/fonts/"

    # Only the glyphs we actually need
    GLYPHS = {
        0x22EE: '⋮',  # Vertical ellipsis
        0x2191: '↑',  # Upwards arrow
        0x2193: '↓',  # Downwards arrow
    }

    print("=" * 60)
    print("  Roboto + DejaVu Glyph Merger (Simple)")
    print("=" * 60)
    print()

    # Merge Regular
    print("Merging Regular weight...")
    if merge_specific_glyphs(
        base_path=FONTS_DIR + "Roboto-Regular.ttf",
        donor_path=FONTS_DIR + "DejaVuSans.ttf",
        output_path=FONTS_DIR + "Roboto-Extended-Regular.ttf",
        glyphs=GLYPHS
    ):
        print()
        print("=" * 60)
        print()

        # Merge Medium
        print("Merging Medium weight...")
        merge_specific_glyphs(
            base_path=FONTS_DIR + "Roboto-Medium.ttf",
            donor_path=FONTS_DIR + "DejaVuSans-Bold.ttf",
            output_path=FONTS_DIR + "Roboto-Extended-Medium.ttf",
            glyphs=GLYPHS
        )

        print()
        print("=" * 60)
        print("✓ Done! Use Roboto-Extended-*.ttf in fonts.lua")
        print("=" * 60)
