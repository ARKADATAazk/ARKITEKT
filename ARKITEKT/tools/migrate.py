#!/usr/bin/env python3
"""
Migrates ARKITEKT files from direct requires to ark.* namespace
Usage: python3 tools/migrate.py [--dry-run] [--user-only]
"""

import re
import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Set

# Module path -> Namespace key mapping
MODULE_MAP = {
    'arkitekt.gui.widgets.primitives.badge': 'Badge',
    'arkitekt.gui.widgets.primitives.button': 'Button',
    'arkitekt.gui.widgets.primitives.checkbox': 'Checkbox',
    'arkitekt.gui.widgets.primitives.close_button': 'CloseButton',
    'arkitekt.gui.widgets.primitives.combo': 'Combo',
    'arkitekt.gui.widgets.primitives.corner_button': 'CornerButton',
    'arkitekt.gui.widgets.primitives.hue_slider': 'HueSlider',
    'arkitekt.gui.widgets.primitives.inputtext': 'InputText',
    'arkitekt.gui.widgets.primitives.markdown_field': 'MarkdownField',
    'arkitekt.gui.widgets.primitives.radio_button': 'RadioButton',
    'arkitekt.gui.widgets.primitives.scrollbar': 'Scrollbar',
    'arkitekt.gui.widgets.primitives.separator': 'Separator',
    'arkitekt.gui.widgets.primitives.slider': 'Slider',
    'arkitekt.gui.widgets.primitives.spinner': 'Spinner',
    'arkitekt.gui.widgets.containers.panel': 'Panel',
    'arkitekt.gui.widgets.containers.tile_group': 'TileGroup',
    'arkitekt.core.colors': 'Colors',
    'arkitekt.gui.style.defaults': 'Style',
    'arkitekt.gui.draw': 'Draw',
    'arkitekt.gui.fx.animation.easing': 'Easing',
    'arkitekt.core.math': 'Math',
    'arkitekt.core.uuid': 'UUID',
}

def find_files_to_migrate(root: Path, user_only: bool) -> List[Path]:
    """Find all Lua files that should be migrated."""
    files = []

    # Always include user scripts and entry points
    for pattern in ['scripts/**/*.lua', 'ARK_*.lua', 'ARKITEKT.lua']:
        files.extend(root.glob(pattern))

    if not user_only:
        # Also include arkitekt library files (excluding primitives/containers)
        for lua_file in root.rglob('arkitekt/**/*.lua'):
            # Skip primitive and container implementations
            if 'widgets/primitives' in str(lua_file):
                continue
            if 'widgets/containers' in str(lua_file):
                continue
            # Skip tools, tests, examples
            if any(x in str(lua_file) for x in ['tools', 'tests', 'examples', 'docs']):
                continue
            files.append(lua_file)

    return sorted(set(files))

def parse_requires(content: str) -> Dict[str, str]:
    """
    Parse require statements and return mapping of local_var -> ns_key.
    Returns empty dict if no arkitekt modules found.
    """
    var_to_ns = {}
    pattern = r"^local\s+(\w+)\s*=\s*require\s*\(?['\"]([^'\"]+)['\"]\)?"

    for line in content.split('\n'):
        match = re.match(pattern, line)
        if match:
            var_name, module_path = match.groups()
            if module_path in MODULE_MAP:
                var_to_ns[var_name] = MODULE_MAP[module_path]

    return var_to_ns

def migrate_file(file_path: Path, dry_run: bool = False) -> Tuple[bool, str]:
    """
    Migrate a single file to use ark.* namespace.
    Returns (success, message).
    """
    content = file_path.read_text()
    original = content

    # Check if already migrated
    if re.search(r"local\s+ark\s*=\s*require\s*\(?['\"]arkitekt['\"]\)?", content):
        return False, "Already uses ark namespace"

    # Find all arkitekt requires
    var_to_ns = parse_requires(content)

    if not var_to_ns:
        return False, "No arkitekt modules found"

    # Remove old require lines
    for var_name in var_to_ns.keys():
        # Match the full require line
        pattern = rf"^local\s+{re.escape(var_name)}\s*=\s*require\s*\(?['\"][^'\"]*['\"]\)?\s*\n"
        content = re.sub(pattern, '', content, flags=re.MULTILINE)

    # Replace widget usages
    for var_name, ns_key in var_to_ns.items():
        # Replace VarName. with ark.NsKey.
        content = re.sub(rf'\b{re.escape(var_name)}\.', f'ark.{ns_key}.', content)
        # Replace VarName: with ark.NsKey:
        content = re.sub(rf'\b{re.escape(var_name)}:', f'ark.{ns_key}:', content)

    # Add ark require at appropriate location
    # Find first require statement
    first_require_match = re.search(r'^local\s+\w+\s*=\s*require', content, re.MULTILINE)

    ark_require = "local ark = require('arkitekt')\n"

    if first_require_match:
        # Insert after first require block
        pos = first_require_match.start()
        # Find end of line
        eol = content.find('\n', pos)
        if eol != -1:
            content = content[:eol+1] + ark_require + content[eol+1:]
    else:
        # No requires, add after initial comments
        lines = content.split('\n')
        insert_pos = 0
        for i, line in enumerate(lines):
            if line.strip() and not line.strip().startswith('--'):
                insert_pos = i
                break
        lines.insert(insert_pos, ark_require.rstrip())
        content = '\n'.join(lines)

    # Write back
    if content != original:
        if not dry_run:
            file_path.write_text(content)
        return True, f"Migrated {len(var_to_ns)} modules"
    else:
        return False, "No changes needed"

def main():
    dry_run = '--dry-run' in sys.argv
    user_only = '--user-only' in sys.argv or True  # Default to user-only (safer!)

    root = Path(__file__).parent.parent
    print(f"ARKITEKT Namespace Migration")
    print(f"Root: {root}")
    print(f"Mode: {'DRY RUN' if dry_run else 'LIVE'}")
    print(f"Scope: {'User scripts only' if user_only else 'All files'}")
    print("=" * 50)
    print()

    files = find_files_to_migrate(root, user_only)
    print(f"Found {len(files)} files to process\n")

    migrated = 0
    skipped = 0
    errors = 0

    for file_path in files:
        rel_path = file_path.relative_to(root)
        try:
            success, message = migrate_file(file_path, dry_run)
            if success:
                print(f"✓ {rel_path}: {message}")
                migrated += 1
            else:
                print(f"⊘ {rel_path}: {message}")
                skipped += 1
        except Exception as e:
            print(f"✗ {rel_path}: ERROR - {e}")
            errors += 1

    print()
    print("=" * 50)
    print(f"Complete: {migrated} migrated, {skipped} skipped, {errors} errors")

if __name__ == '__main__':
    main()
