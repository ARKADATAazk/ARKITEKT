#!/usr/bin/env python3
"""
Convert double-quoted strings to single-quoted strings in Lua files.

Safety features:
1. Skips strings containing single quotes (need manual escaping)
2. Skips external/ directories
3. Preserves strings with escape sequences
4. Dry-run by default
5. Creates backup before modifying

Usage:
    python convert_quotes.py                    # Dry run - shows what would change
    python convert_quotes.py --apply            # Actually modify files
    python convert_quotes.py --apply --no-backup  # Modify without backup
"""

import os
import re
import sys
import shutil
from pathlib import Path
from typing import List, Tuple

# Directories to skip
SKIP_DIRS = {'external', '.git', '__pycache__', 'node_modules', 'references'}

# Pattern to find double-quoted strings
# Matches: "content" where content doesn't contain unescaped " or '
DOUBLE_QUOTE_PATTERN = re.compile(
    r'"'                    # Opening "
    r'('                    # Start capture group
    r'[^"\'\\]*'           # Any chars except ", ', \
    r'(?:\\.[^"\'\\]*)*'   # Escaped sequences followed by more chars
    r')'                    # End capture group
    r'"'                    # Closing "
)

def should_skip_dir(path: Path) -> bool:
    """Check if directory should be skipped."""
    return any(skip in path.parts for skip in SKIP_DIRS)

def contains_single_quote(content: str) -> bool:
    """Check if string content contains a single quote."""
    return "'" in content

def convert_line(line: str) -> Tuple[str, List[str]]:
    """
    Convert double quotes to single quotes in a line.
    Returns (new_line, list of skipped strings).
    """
    skipped = []

    def replace_match(match):
        full_match = match.group(0)
        content = match.group(1)

        # Skip if contains single quote (would need escaping)
        if contains_single_quote(content):
            skipped.append(f'  Skipped (contains \'): {full_match}')
            return full_match

        # Convert to single quotes
        return f"'{content}'"

    new_line = DOUBLE_QUOTE_PATTERN.sub(replace_match, line)
    return new_line, skipped

def process_file(file_path: Path, dry_run: bool = True, create_backup: bool = True) -> dict:
    """
    Process a single Lua file.
    Returns stats about what was changed/skipped.
    """
    stats = {
        'file': str(file_path),
        'lines_changed': 0,
        'quotes_converted': 0,
        'skipped': [],
        'modified': False
    }

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            original_lines = f.readlines()
    except Exception as e:
        stats['error'] = str(e)
        return stats

    new_lines = []
    for i, line in enumerate(original_lines, 1):
        # Count original double quotes
        original_count = len(DOUBLE_QUOTE_PATTERN.findall(line))

        new_line, skipped = convert_line(line)
        new_lines.append(new_line)

        # Count remaining double quotes
        new_count = len(DOUBLE_QUOTE_PATTERN.findall(new_line))
        converted = original_count - new_count

        if converted > 0:
            stats['lines_changed'] += 1
            stats['quotes_converted'] += converted

        if skipped:
            for skip_msg in skipped:
                stats['skipped'].append(f'Line {i}:{skip_msg}')

    # Check if anything changed
    if new_lines != original_lines:
        stats['modified'] = True

        if not dry_run:
            # Create backup
            if create_backup:
                backup_path = file_path.with_suffix('.lua.bak')
                shutil.copy2(file_path, backup_path)

            # Write modified file
            with open(file_path, 'w', encoding='utf-8', newline='') as f:
                f.writelines(new_lines)

    return stats

def find_lua_files(root_dir: Path) -> List[Path]:
    """Find all Lua files, excluding skipped directories."""
    lua_files = []
    for path in root_dir.rglob('*.lua'):
        if not should_skip_dir(path):
            lua_files.append(path)
    return sorted(lua_files)

def main():
    # Parse arguments
    dry_run = '--apply' not in sys.argv
    create_backup = '--no-backup' not in sys.argv

    # Find project root (assume script is in tools/)
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    # Directories to process
    target_dirs = [
        project_root / 'ARKITEKT',              # Full ARKITEKT folder
        project_root / 'scripts',
        project_root / 'devkit',
    ]

    # Filter to existing directories
    target_dirs = [d for d in target_dirs if d.exists()]

    if not target_dirs:
        print("Error: No target directories found")
        sys.exit(1)

    print(f"{'DRY RUN - ' if dry_run else ''}Processing directories:")
    for d in target_dirs:
        print(f"  - {d.relative_to(project_root)}")
    print(f"Skipping: {SKIP_DIRS}")
    print()

    # Find files from all directories
    lua_files = []
    for target_dir in target_dirs:
        lua_files.extend(find_lua_files(target_dir))
    lua_files = sorted(set(lua_files))  # Remove duplicates and sort
    print(f"Found {len(lua_files)} Lua files to process")
    print()

    # Process files
    total_converted = 0
    total_skipped = 0
    files_modified = 0
    all_skipped = []

    for file_path in lua_files:
        stats = process_file(file_path, dry_run=dry_run, create_backup=create_backup)

        if stats.get('error'):
            print(f"ERROR: {stats['file']}: {stats['error']}")
            continue

        if stats['modified']:
            files_modified += 1
            rel_path = file_path.relative_to(project_root)
            print(f"{'Would modify' if dry_run else 'Modified'}: {rel_path}")
            print(f"  Converted: {stats['quotes_converted']} quotes on {stats['lines_changed']} lines")

            total_converted += stats['quotes_converted']

        if stats['skipped']:
            total_skipped += len(stats['skipped'])
            all_skipped.extend([(file_path, s) for s in stats['skipped']])

    # Summary
    print()
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Files processed: {len(lua_files)}")
    print(f"Files {'to modify' if dry_run else 'modified'}: {files_modified}")
    print(f"Quotes {'to convert' if dry_run else 'converted'}: {total_converted}")
    print(f"Strings skipped (contain '): {total_skipped}")

    if all_skipped:
        print()
        print("SKIPPED STRINGS (need manual review):")
        print("-" * 40)
        for file_path, skip_msg in all_skipped:
            rel_path = file_path.relative_to(project_root)
            print(f"{rel_path}: {skip_msg}")

    if dry_run:
        print()
        print("This was a DRY RUN. To apply changes, run:")
        print("  python tools/convert_quotes.py --apply")

if __name__ == '__main__':
    main()
