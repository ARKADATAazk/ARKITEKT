# @noindex
# Fix conversion errors:
# 1. Ark.Colors.0x... → 0x...
# 2. Colors.Colors.WithOpacity → Colors.WithOpacity
# 3. Ark.Colors.Colors.WithOpacity → Ark.Colors.WithOpacity
# 4. M.0x... → 0x... (module self-reference)
import re
from pathlib import Path

def fix_conversion_errors(content):
    """Fix errors from hex_to_bytes conversion."""

    # Fix: Ark.Colors.0x... → 0x...
    content = re.sub(r'Ark\.Colors\.0x([0-9A-Fa-f]+)', r'0x\1', content)

    # Fix: Colors.0x... → 0x...
    content = re.sub(r'Colors\.0x([0-9A-Fa-f]+)', r'0x\1', content)

    # Fix: M.0x... → 0x... (module self-reference in colors.lua)
    content = re.sub(r'M\.0x([0-9A-Fa-f]+)', r'0x\1', content)

    # Fix: Ark.Colors.Colors.WithOpacity → Ark.Colors.WithOpacity
    content = re.sub(r'Ark\.Colors\.Colors\.WithOpacity', r'Ark.Colors.WithOpacity', content)

    # Fix: Colors.Colors.WithOpacity → Colors.WithOpacity
    content = re.sub(r'Colors\.Colors\.WithOpacity', r'Colors.WithOpacity', content)

    return content

def process_file(filepath, dry_run=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        original = f.read()

    fixed = fix_conversion_errors(original)
    changed = fixed != original

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
                print(f"{prefix}Fixed: {lua_file.relative_to(root_path)}")
        except Exception as e:
            print(f"Error: {lua_file}: {e}")

    return stats

if __name__ == '__main__':
    ARKITEKT_DIR = r'D:\Dropbox\REAPER\Scripts\ARKITEKT-Dev'

    print("=== Fixing conversion errors ===")
    stats = process_directory(ARKITEKT_DIR, dry_run=False)
    print(f"\nProcessed: {stats['processed']}, Fixed: {stats['modified']}")
