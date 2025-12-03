# @noindex
# Convert hex('#RRGGBB') and hex('#RRGGBBAA') to 0xRRGGBBFF / 0xRRGGBBAA byte literals
import re
import sys
from pathlib import Path

def convert_hex_to_bytes(content):
    """Convert hex() calls to byte literals."""

    # Pattern: hex('#RRGGBB') or hex('#RRGGBBAA') or hex("#RRGGBB") etc
    # Also handles optional second param: hex('#RRGGBB', 0.5)

    def replace_hex_call(match):
        quote = match.group(1)  # ' or "
        hex_val = match.group(2).upper()  # RRGGBB or RRGGBBAA
        opacity = match.group(3)  # Optional opacity param like ", 0.5"

        if opacity:
            # Has opacity param - convert to WithOpacity call
            # hex('#FF0000', 0.5) → Colors.WithOpacity(0xFF0000FF, 0.5)
            # Note: We keep the opacity application, caller may need to add Colors. prefix
            opacity_val = opacity.strip(', ')
            if len(hex_val) == 6:
                return f'Colors.WithOpacity(0x{hex_val}FF, {opacity_val})'
            else:
                return f'Colors.WithOpacity(0x{hex_val}, {opacity_val})'
        else:
            # No opacity - straight conversion
            if len(hex_val) == 6:
                return f'0x{hex_val}FF'
            else:
                return f'0x{hex_val}'

    # Match hex('#RRGGBB') or hex('#RRGGBB', 0.5) etc
    pattern = r'hex\(([\'"])#([0-9A-Fa-f]{6,8})\1(,\s*[\d.]+)?\)'

    converted = re.sub(pattern, replace_hex_call, content)
    return converted, converted != content

def remove_hex_imports(content):
    """Remove hex-related imports that are no longer needed."""
    lines = content.split('\n')
    new_lines = []

    for line in lines:
        # Skip lines that only import hex
        if re.match(r'^local hex = .+\.hex\s*$', line):
            continue
        # Skip lines that are just the Colors require if followed by hex local
        new_lines.append(line)

    return '\n'.join(new_lines)

def process_file(filepath, dry_run=True):
    """Process a single file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    converted, changed = convert_hex_to_bytes(content)

    if changed and not dry_run:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(converted)

    return changed

def process_directory(root_dir, dry_run=True):
    """Process all .lua files in directory."""
    root_path = Path(root_dir)
    stats = {'processed': 0, 'modified': 0, 'errors': 0}

    for lua_file in root_path.rglob('*.lua'):
        # Skip references folder
        if 'references' in str(lua_file).lower():
            continue

        try:
            changed = process_file(lua_file, dry_run)
            stats['processed'] += 1

            if changed:
                stats['modified'] += 1
                prefix = '[DRY RUN] ' if dry_run else ''
                print(f"{prefix}Modified: {lua_file.relative_to(root_path)}")

        except Exception as e:
            stats['errors'] += 1
            print(f"Error processing {lua_file}: {e}")

    return stats

if __name__ == '__main__':
    ARKITEKT_DIR = r'D:\Dropbox\REAPER\Scripts\ARKITEKT-Dev'

    print("=== DRY RUN ===")
    stats = process_directory(ARKITEKT_DIR, dry_run=True)
    print(f"\nProcessed: {stats['processed']}, Would modify: {stats['modified']}, Errors: {stats['errors']}")

    response = input("\nProceed with actual conversion? (yes/no): ")
    if response.lower() == 'yes':
        print("\n=== ACTUAL RUN ===")
        stats = process_directory(ARKITEKT_DIR, dry_run=False)
        print(f"\nProcessed: {stats['processed']}, Modified: {stats['modified']}, Errors: {stats['errors']}")
