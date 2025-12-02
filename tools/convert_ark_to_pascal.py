#!/usr/bin/env python3
"""
Convert Ark.*.snake_case calls to Ark.*.PascalCase

Run from ARKITEKT-Dev root:
    python tools/convert_ark_to_pascal.py
    python tools/convert_ark_to_pascal.py --dry-run
"""

import os
import re
import sys
from pathlib import Path

# Mapping of snake_case -> PascalCase for each module
CONVERSIONS = {
    # Colors module
    'Colors.hexrgb': 'Colors.Hexrgb',
    'Colors.to_hexrgb': 'Colors.ToHexrgb',
    'Colors.to_hexrgba': 'Colors.ToHexrgba',
    'Colors.hexrgba': 'Colors.Hexrgba',
    'Colors.rgba_to_components': 'Colors.RgbaToComponents',
    'Colors.components_to_rgba': 'Colors.ComponentsToRgba',
    'Colors.argb_to_rgba': 'Colors.ArgbToRgba',
    'Colors.rgba_to_argb': 'Colors.RgbaToArgb',
    'Colors.with_alpha': 'Colors.WithAlpha',
    'Colors.opacity': 'Colors.Opacity',
    'Colors.with_opacity': 'Colors.WithOpacity',
    'Colors.to_opacity': 'Colors.ToOpacity',
    'Colors.get_opacity': 'Colors.GetOpacity',
    'Colors.adjust_brightness': 'Colors.AdjustBrightness',
    'Colors.desaturate': 'Colors.Desaturate',
    'Colors.saturate': 'Colors.Saturate',
    'Colors.luminance': 'Colors.Luminance',
    'Colors.lerp_component': 'Colors.LerpComponent',
    'Colors.lerp': 'Colors.Lerp',
    'Colors.auto_text_color': 'Colors.AutoTextColor',
    'Colors.rgb_to_reaper': 'Colors.RgbToReaper',
    'Colors.rgba_to_reaper_native': 'Colors.RgbaToReaperNative',
    'Colors.rgb_to_hsl': 'Colors.RgbToHsl',
    'Colors.hsl_to_rgb': 'Colors.HslToRgb',
    'Colors.adjust_lightness': 'Colors.AdjustLightness',
    'Colors.clamp_bg_color': 'Colors.ClampBgColor',
    'Colors.set_lightness': 'Colors.SetLightness',
    'Colors.adjust_saturation': 'Colors.AdjustSaturation',
    'Colors.adjust_hue': 'Colors.AdjustHue',
    'Colors.lighten': 'Colors.Lighten',
    'Colors.darken': 'Colors.Darken',
    'Colors.blend': 'Colors.Blend',
    'Colors.set_hsl': 'Colors.SetHsl',
    'Colors.get_color_sort_key': 'Colors.GetColorSortKey',
    'Colors.compare_colors': 'Colors.CompareColors',
    'Colors.analyze_color': 'Colors.AnalyzeColor',
    'Colors.derive_normalized': 'Colors.DeriveNormalized',
    'Colors.derive_brightened': 'Colors.DeriveBrightened',
    'Colors.derive_intensified': 'Colors.DeriveIntensified',
    'Colors.derive_muted': 'Colors.DeriveMuted',
    'Colors.derive_fill': 'Colors.DeriveFill',
    'Colors.derive_border': 'Colors.DeriveBorder',
    'Colors.derive_hover': 'Colors.DeriveHover',
    'Colors.derive_selection': 'Colors.DeriveSelection',
    'Colors.derive_marching_ants': 'Colors.DeriveMarchingAnts',
    'Colors.derive_palette': 'Colors.DerivePalette',
    'Colors.derive_palette_adaptive': 'Colors.DerivePaletteAdaptive',
    'Colors.generate_border': 'Colors.GenerateBorder',
    'Colors.generate_hover': 'Colors.GenerateHover',
    'Colors.generate_active_border': 'Colors.GenerateActiveBorder',
    'Colors.generate_selection_color': 'Colors.GenerateSelectionColor',
    'Colors.generate_marching_ants_color': 'Colors.GenerateMarchingAntsColor',
    'Colors.auto_palette': 'Colors.AutoPalette',
    'Colors.flashy_palette': 'Colors.FlashyPalette',
    'Colors.same_hue_variant': 'Colors.SameHueVariant',
    'Colors.tile_text_colors': 'Colors.TileTextColors',
    'Colors.tile_meta_color': 'Colors.TileMetaColor',

    # Draw module
    'Draw.snap': 'Draw.Snap',
    'Draw.centered_text': 'Draw.CenteredText',
    'Draw.rect': 'Draw.Rect',
    'Draw.rect_filled': 'Draw.RectFilled',
    'Draw.line': 'Draw.Line',
    'Draw.text': 'Draw.Text',
    'Draw.text_right': 'Draw.TextRight',
    'Draw.point_in_rect': 'Draw.PointInRect',
    'Draw.rects_intersect': 'Draw.RectsIntersect',
    'Draw.text_clipped': 'Draw.TextClipped',

    # Button module
    'Button.draw': 'Button.Draw',
    'Button.draw_at_cursor': 'Button.DrawAtCursor',
    'Button.cleanup': 'Button.Cleanup',

    # Checkbox module
    'Checkbox.draw': 'Checkbox.Draw',
    'Checkbox.measure': 'Checkbox.Measure',
    'Checkbox.draw_at_cursor': 'Checkbox.DrawAtCursor',
    'Checkbox.cleanup': 'Checkbox.Cleanup',

    # Combo module
    'Combo.draw': 'Combo.Draw',
    'Combo.measure': 'Combo.Measure',
    'Combo.get_value': 'Combo.GetValue',
    'Combo.set_value': 'Combo.SetValue',
    'Combo.get_direction': 'Combo.GetDirection',
    'Combo.set_direction': 'Combo.SetDirection',
    'Combo.draw_at_cursor': 'Combo.DrawAtCursor',
    'Combo.cleanup': 'Combo.Cleanup',

    # Slider module
    'Slider.draw': 'Slider.Draw',
    'Slider.percent': 'Slider.Percent',
    'Slider.int': 'Slider.Int',
    'Slider.draw_at_cursor': 'Slider.DrawAtCursor',
    'Slider.cleanup': 'Slider.Cleanup',
}

# Also handle local variable assignments like:
# local Colors_with_alpha = Ark.Colors.with_alpha
LOCAL_VAR_CONVERSIONS = {
    'Colors_hexrgb': 'Colors_Hexrgb',
    'Colors_with_alpha': 'Colors_WithAlpha',
    'Colors_adjust_brightness': 'Colors_AdjustBrightness',
    'Colors_same_hue_variant': 'Colors_SameHueVariant',
    'Colors_rgba_to_components': 'Colors_RgbaToComponents',
    'Colors_components_to_rgba': 'Colors_ComponentsToRgba',
    'Colors_rgb_to_hsl': 'Colors_RgbToHsl',
    'Colors_hsl_to_rgb': 'Colors_HslToRgb',
    'Colors_with_opacity': 'Colors_WithOpacity',
    'Colors_opacity': 'Colors_Opacity',
}

# Local module references (Colors.method instead of Ark.Colors.method)
# Complete list of all Colors module functions
LOCAL_MODULE_CONVERSIONS = {
    # Basic
    'Colors.hexrgb': 'Colors.Hexrgb',
    'Colors.to_hexrgb': 'Colors.ToHexrgb',
    'Colors.to_hexrgba': 'Colors.ToHexrgba',
    'Colors.hexrgba': 'Colors.Hexrgba',
    'Colors.rgba_to_components': 'Colors.RgbaToComponents',
    'Colors.components_to_rgba': 'Colors.ComponentsToRgba',
    'Colors.argb_to_rgba': 'Colors.ArgbToRgba',
    'Colors.rgba_to_argb': 'Colors.RgbaToArgb',
    'Colors.with_alpha': 'Colors.WithAlpha',
    'Colors.opacity': 'Colors.Opacity',
    'Colors.with_opacity': 'Colors.WithOpacity',
    'Colors.to_opacity': 'Colors.ToOpacity',
    'Colors.get_opacity': 'Colors.GetOpacity',
    'Colors.adjust_brightness': 'Colors.AdjustBrightness',
    'Colors.desaturate': 'Colors.Desaturate',
    'Colors.saturate': 'Colors.Saturate',
    'Colors.luminance': 'Colors.Luminance',
    'Colors.lerp_component': 'Colors.LerpComponent',
    'Colors.lerp': 'Colors.Lerp',
    'Colors.auto_text_color': 'Colors.AutoTextColor',
    # Conversions
    'Colors.rgb_to_reaper': 'Colors.RgbToReaper',
    'Colors.rgba_to_reaper_native': 'Colors.RgbaToReaperNative',
    'Colors.rgb_to_hsl': 'Colors.RgbToHsl',
    'Colors.hsl_to_rgb': 'Colors.HslToRgb',
    # HSL manipulation
    'Colors.adjust_lightness': 'Colors.AdjustLightness',
    'Colors.clamp_bg_color': 'Colors.ClampBgColor',
    'Colors.set_lightness': 'Colors.SetLightness',
    'Colors.adjust_saturation': 'Colors.AdjustSaturation',
    'Colors.adjust_hue': 'Colors.AdjustHue',
    'Colors.lighten': 'Colors.Lighten',
    'Colors.darken': 'Colors.Darken',
    'Colors.blend': 'Colors.Blend',
    'Colors.set_hsl': 'Colors.SetHsl',
    # Sorting
    'Colors.get_color_sort_key': 'Colors.GetColorSortKey',
    'Colors.compare_colors': 'Colors.CompareColors',
    # Analysis
    'Colors.analyze_color': 'Colors.AnalyzeColor',
    # Derivation
    'Colors.derive_normalized': 'Colors.DeriveNormalized',
    'Colors.derive_brightened': 'Colors.DeriveBrightened',
    'Colors.derive_intensified': 'Colors.DeriveIntensified',
    'Colors.derive_muted': 'Colors.DeriveMuted',
    'Colors.derive_fill': 'Colors.DeriveFill',
    'Colors.derive_border': 'Colors.DeriveBorder',
    'Colors.derive_hover': 'Colors.DeriveHover',
    'Colors.derive_selection': 'Colors.DeriveSelection',
    'Colors.derive_marching_ants': 'Colors.DeriveMarchingAnts',
    'Colors.derive_palette': 'Colors.DerivePalette',
    'Colors.derive_palette_adaptive': 'Colors.DerivePaletteAdaptive',
    # Legacy generators
    'Colors.generate_border': 'Colors.GenerateBorder',
    'Colors.generate_hover': 'Colors.GenerateHover',
    'Colors.generate_active_border': 'Colors.GenerateActiveBorder',
    'Colors.generate_selection_color': 'Colors.GenerateSelectionColor',
    'Colors.generate_marching_ants_color': 'Colors.GenerateMarchingAntsColor',
    'Colors.auto_palette': 'Colors.AutoPalette',
    'Colors.flashy_palette': 'Colors.FlashyPalette',
    # Hue helpers
    'Colors.same_hue_variant': 'Colors.SameHueVariant',
    'Colors.tile_text_colors': 'Colors.TileTextColors',
    'Colors.tile_meta_color': 'Colors.TileMetaColor',
    # Aliases for other module names
    'ColorUtils.hexrgb': 'ColorUtils.Hexrgb',
    'CoreColors.hexrgb': 'CoreColors.Hexrgb',

    # Direct module references (local Checkbox = require(...))
    'Checkbox.draw': 'Checkbox.Draw',
    'Checkbox.measure': 'Checkbox.Measure',
    'Checkbox.draw_at_cursor': 'Checkbox.DrawAtCursor',
    'Checkbox.cleanup': 'Checkbox.Cleanup',

    'Button.draw': 'Button.Draw',
    'Button.draw_at_cursor': 'Button.DrawAtCursor',
    'Button.cleanup': 'Button.Cleanup',

    'Combo.draw': 'Combo.Draw',
    'Combo.measure': 'Combo.Measure',
    'Combo.get_value': 'Combo.GetValue',
    'Combo.set_value': 'Combo.SetValue',
    'Combo.get_direction': 'Combo.GetDirection',
    'Combo.set_direction': 'Combo.SetDirection',
    'Combo.draw_at_cursor': 'Combo.DrawAtCursor',
    'Combo.cleanup': 'Combo.Cleanup',

    'Slider.draw': 'Slider.Draw',
    'Slider.percent': 'Slider.Percent',
    'Slider.int': 'Slider.Int',
    'Slider.draw_at_cursor': 'Slider.DrawAtCursor',
    'Slider.cleanup': 'Slider.Cleanup',

    # Draw module direct refs
    'Draw.snap': 'Draw.Snap',
    'Draw.centered_text': 'Draw.CenteredText',
    'Draw.rect': 'Draw.Rect',
    'Draw.rect_filled': 'Draw.RectFilled',
    'Draw.line': 'Draw.Line',
    'Draw.text': 'Draw.Text',
    'Draw.text_right': 'Draw.TextRight',
    'Draw.point_in_rect': 'Draw.PointInRect',
    'Draw.rects_intersect': 'Draw.RectsIntersect',
    'Draw.text_clipped': 'Draw.TextClipped',

    # Other widgets with .draw methods
    'Chip.draw': 'Chip.Draw',
    'ChipList.draw': 'ChipList.Draw',
    'MarchingAnts.draw': 'MarchingAnts.Draw',
    'Background.draw': 'Background.Draw',
    'RadioButton.draw': 'RadioButton.Draw',
    'InputText.draw': 'InputText.Draw',
    'Spinner.draw': 'Spinner.Draw',
    'ProgressBar.draw': 'ProgressBar.Draw',
    'Splitter.draw': 'Splitter.Draw',
    'HatchedFill.draw': 'HatchedFill.Draw',
    'CornerButton.draw': 'CornerButton.Draw',
    'Badge.draw': 'Badge.Draw',
    'HueSlider.draw': 'HueSlider.Draw',
    'Scrollbar.draw': 'Scrollbar.Draw',
    'CloseButton.draw': 'CloseButton.Draw',
    'Knob.draw': 'Knob.Draw',

    # Ark.* widget draw methods
    'Ark.Spinner.draw': 'Ark.Spinner.Draw',
    'Ark.InputText.draw': 'Ark.InputText.Draw',
    'Ark.Splitter.draw': 'Ark.Splitter.Draw',
    'Ark.ProgressBar.draw': 'Ark.ProgressBar.Draw',
    'Ark.HueSlider.draw': 'Ark.HueSlider.Draw',
}

def convert_file(filepath, dry_run=False):
    """Convert a single file. Returns (changed, num_replacements)."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        return False, 0

    original = content
    total_replacements = 0

    # Convert Ark.Module.method patterns
    for old, new in CONVERSIONS.items():
        # Match both Ark.Colors.method and just Colors.method (for local refs)
        pattern_ark = r'\bArk\.' + re.escape(old) + r'\b'
        pattern_local = r'\b' + re.escape(old) + r'\b'

        # Count matches
        ark_matches = len(re.findall(pattern_ark, content))

        if ark_matches > 0:
            content = re.sub(pattern_ark, 'Ark.' + new, content)
            total_replacements += ark_matches

    # Convert local variable names (Colors_with_alpha -> Colors_WithAlpha)
    for old, new in LOCAL_VAR_CONVERSIONS.items():
        pattern = r'\b' + re.escape(old) + r'\b'
        matches = len(re.findall(pattern, content))
        if matches > 0:
            content = re.sub(pattern, new, content)
            total_replacements += matches

    # Convert local module references (Colors.hexrgb -> Colors.Hexrgb)
    for old, new in LOCAL_MODULE_CONVERSIONS.items():
        pattern = r'\b' + re.escape(old) + r'\b'
        matches = len(re.findall(pattern, content))
        if matches > 0:
            content = re.sub(pattern, new, content)
            total_replacements += matches

    changed = content != original

    if changed and not dry_run:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

    return changed, total_replacements

def main():
    dry_run = '--dry-run' in sys.argv

    # Find root directory
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    arkitekt_root = project_root / 'ARKITEKT'
    devkit_root = project_root / 'devkit'

    if not arkitekt_root.exists():
        print(f"Error: ARKITEKT directory not found at {arkitekt_root}")
        sys.exit(1)

    print(f"{'[DRY RUN] ' if dry_run else ''}Converting Ark.*.snake_case to PascalCase...")
    print(f"Project: {project_root}")
    print()

    total_files = 0
    total_replacements = 0
    changed_files = []

    # Process all .lua files in ARKITEKT
    for lua_file in arkitekt_root.rglob('*.lua'):
        # Skip external libraries
        if 'external' in str(lua_file):
            continue

        changed, num_replacements = convert_file(lua_file, dry_run)

        if changed:
            total_files += 1
            total_replacements += num_replacements
            changed_files.append((lua_file.relative_to(project_root), num_replacements))

    # Process devkit folder
    if devkit_root.exists():
        for lua_file in devkit_root.rglob('*.lua'):
            changed, num_replacements = convert_file(lua_file, dry_run)

            if changed:
                total_files += 1
                total_replacements += num_replacements
                changed_files.append((lua_file.relative_to(project_root), num_replacements))

    # Print results
    print(f"{'Would change' if dry_run else 'Changed'} {total_files} files with {total_replacements} replacements:")
    print()

    for filepath, count in sorted(changed_files):
        print(f"  {filepath}: {count} replacements")

    print()
    print(f"Total: {total_files} files, {total_replacements} replacements")

    if dry_run:
        print("\nRun without --dry-run to apply changes.")

if __name__ == '__main__':
    main()
