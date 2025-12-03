# @noindex
# Remove dead 'local hex = X.Colors.hex' imports after bytes migration
import re
from pathlib import Path

def remove_hex_import(content):
    """Remove local hex = X.hex / X.Colors.hex import lines."""

    # Pattern: local hex = <anything>.hex or local hex = <anything>.Colors.hex
    # But NOT: local hex = s:sub... (legitimate code use)
    # Match: local hex = Ark.Colors.hex, Colors.hex, CoreColors.hex, ColorUtils.hex, Arkit.hex

    pattern = r'^local hex = (?:Ark\.Colors|Colors|CoreColors|ColorUtils|Arkit)\.hex\s*\n'

    original = content
    content = re.sub(pattern, '', content, flags=re.MULTILINE)

    return content, content != original

def process_file(filepath, dry_run=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        original = f.read()

    fixed, changed = remove_hex_import(original)

    if changed and not dry_run:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(fixed)

    return changed

def process_directory(root_dir, dry_run=True):
    root_path = Path(root_dir)
    stats = {'processed': 0, 'modified': 0}

    for lua_file in root_path.rglob('*.lua'):
        if 'references' in str(lua_file).lower():
            continue

        try:
            changed = process_file(lua_file, dry_run)
            stats['processed'] += 1
            if changed:
                stats['modified'] += 1
                prefix = '[DRY RUN] ' if dry_run else ''
                print(f"{prefix}Cleaned: {lua_file.relative_to(root_path)}")
        except Exception as e:
            print(f"Error: {lua_file}: {e}")

    return stats

if __name__ == '__main__':
    ARKITEKT_DIR = r'D:\Dropbox\REAPER\Scripts\ARKITEKT-Dev'

    print("=== Removing dead hex imports ===")
    stats = process_directory(ARKITEKT_DIR, dry_run=False)
    print(f"\nProcessed: {stats['processed']}, Cleaned: {stats['modified']}")
