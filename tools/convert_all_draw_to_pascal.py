#!/usr/bin/env python3
"""
Convert ALL .draw method calls to .Draw (PascalCase)
Also converts function definitions from function M.draw to function M.Draw

Run from ARKITEKT-Dev root:
    python tools/convert_all_draw_to_pascal.py
    python tools/convert_all_draw_to_pascal.py --dry-run
"""

import os
import re
import sys
from pathlib import Path

# Methods to convert (snake_case -> PascalCase)
METHODS_TO_CONVERT = [
    'draw',
    'measure',
    'cleanup',
    'draw_at_cursor',
    'get_value',
    'set_value',
    'get_direction',
    'set_direction',
    'percent',
    'int',
    # InputText methods
    'search',
    'get_text',
    'set_text',
    'clear',
    # Draw primitives
    'snap',
    'centered_text',
    'rect',
    'rect_filled',
    'line',
    'text',
    'text_right',
    'point_in_rect',
    'rects_intersect',
    'text_clipped',
    # Additional widget methods
    'begin_draw',
    'end_draw',
    'update',
    'reset',
    'get_id',
]

def snake_to_pascal(name):
    """Convert snake_case to PascalCase"""
    return ''.join(word.capitalize() for word in name.split('_'))

def convert_file(filepath, dry_run=False):
    """Convert a single file. Returns (changed, num_replacements)."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        return False, 0

    original = content
    total_replacements = 0

    for method in METHODS_TO_CONVERT:
        pascal = snake_to_pascal(method)

        # Pattern 1: Module.method( - where Module starts with uppercase
        # e.g., Chip.draw(, Button.draw(, MarchingAnts.draw(
        pattern = r'\b([A-Z][a-zA-Z0-9_]*)\.' + re.escape(method) + r'\('
        replacement = r'\1.' + pascal + '('
        matches = len(re.findall(pattern, content))
        if matches > 0:
            content = re.sub(pattern, replacement, content)
            total_replacements += matches

        # Pattern 2: function M.method( - module function definition
        pattern = r'function M\.' + re.escape(method) + r'\('
        replacement = 'function M.' + pascal + '('
        matches = len(re.findall(pattern, content))
        if matches > 0:
            content = re.sub(pattern, replacement, content)
            total_replacements += matches

        # Pattern 3: component.method then - condition checks (component.draw then, component.measure then)
        pattern = r'component\.' + re.escape(method) + r'\b'
        replacement = 'component.' + pascal
        matches = len(re.findall(pattern, content))
        if matches > 0:
            content = re.sub(pattern, replacement, content)
            total_replacements += matches

        # Pattern 4: M.method = for aliases at end of file
        pattern = r'\bM\.' + re.escape(method) + r' = M\.'
        # Don't convert these - they're backwards compat aliases we want to remove

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

    print(f"{'[DRY RUN] ' if dry_run else ''}Converting all .draw/.method calls to PascalCase...")
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
