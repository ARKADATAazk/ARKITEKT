# @noindex
# Convert Theme DSL hex strings to bytes
# - snap2('#RRGGBB', '#RRGGBB') → snap2(0xRRGGBBFF, 0xRRGGBBFF)
# - lerp2('#RRGGBB', '#RRGGBB') → lerp2(0xRRGGBBFF, 0xRRGGBBFF)
# - snap3/lerp3/offset3 with hex strings → byte format
# - presets: '#RRGGBB' → 0xRRGGBBFF
# - PALETTE .hex = '#RRGGBB' → .color = 0xRRGGBBFF

import re
from pathlib import Path

def hex_to_byte(hex_str):
    """Convert '#RRGGBB' or '#RRGGBBAA' to '0xRRGGBBFF' or '0xRRGGBBAA'"""
    hex_str = hex_str.strip("'\"")
    if hex_str.startswith('#'):
        hex_str = hex_str[1:]
    hex_str = hex_str.upper()
    if len(hex_str) == 6:
        return f'0x{hex_str}FF'
    else:
        return f'0x{hex_str}'

def convert_snap_lerp(content):
    """Convert snap2/snap3/lerp2/lerp3/offset2/offset3 with hex strings to bytes."""

    # Pattern for DSL functions with hex strings
    def replace_dsl_call(match):
        func = match.group(1)  # snap2, snap3, lerp2, lerp3, offset2, offset3
        args = match.group(2)

        # Convert each hex string in the args
        def convert_hex_arg(m):
            return hex_to_byte(m.group(0))

        new_args = re.sub(r"['\"]#[0-9A-Fa-f]{6,8}['\"]", convert_hex_arg, args)
        return f'{func}({new_args})'

    # Match snap2/3, lerp2/3, offset2/3
    content = re.sub(r'(snap[23]|lerp[23]|offset[23])\(([^)]+)\)', replace_dsl_call, content)

    return content

def convert_presets(content):
    """Convert preset hex strings to bytes."""
    # Pattern: name = '#RRGGBB' (with optional comment)
    def replace_preset(match):
        name = match.group(1)
        hex_val = match.group(2)
        comment = match.group(3) or ''
        byte_val = hex_to_byte(hex_val)
        return f"{name} = {byte_val},{comment}"

    content = re.sub(
        r"(\w+)\s*=\s*['\"]#([0-9A-Fa-f]{6,8})['\"],?(\s*--[^\n]*)?",
        replace_preset,
        content
    )
    return content

def convert_palette_hex(content):
    """Convert PALETTE .hex = '#...' to .color = 0x..."""
    def replace_palette_entry(match):
        prefix = match.group(1)
        hex_val = match.group(2)
        byte_val = hex_to_byte('#' + hex_val)
        return f"{prefix}color = {byte_val}"

    content = re.sub(
        r"({\s*id\s*=\s*\d+,\s*name\s*=\s*['\"][^'\"]+['\"],\s*)hex\s*=\s*['\"]#([0-9A-Fa-f]{6,8})['\"]",
        replace_palette_entry,
        content
    )
    return content

def process_file(filepath, dry_run=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        original = f.read()

    content = original
    content = convert_snap_lerp(content)
    content = convert_presets(content)
    content = convert_palette_hex(content)

    changed = content != original

    if changed and not dry_run:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

    return changed, content

if __name__ == '__main__':
    files = [
        r'D:\Dropbox\REAPER\Scripts\ARKITEKT-Dev\ARKITEKT\arkitekt\config\colors\theme.lua',
        r'D:\Dropbox\REAPER\Scripts\ARKITEKT-Dev\ARKITEKT\arkitekt\config\colors\static.lua',
        r'D:\Dropbox\REAPER\Scripts\ARKITEKT-Dev\ARKITEKT\scripts\ItemPicker\config\palette.lua',
        r'D:\Dropbox\REAPER\Scripts\ARKITEKT-Dev\ARKITEKT\scripts\RegionPlaylist\config\palette.lua',
    ]

    print("=== Converting Theme DSL hex strings to bytes ===\n")

    for filepath in files:
        path = Path(filepath)
        if path.exists():
            changed, _ = process_file(filepath, dry_run=False)
            status = "CONVERTED" if changed else "no changes"
            print(f"{status}: {path.name}")
        else:
            print(f"NOT FOUND: {filepath}")
