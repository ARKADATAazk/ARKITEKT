# @noindex
import re
import os
from pathlib import Path

def convert_hex_to_hexrgb(content, filepath):
    """Convert hex literals to hexrgb() calls and add imports if needed."""
    
    # Check if file already has Colors imported
    has_colors_import = 'require(\'arkitekt.core.colors\')' in content or \
                       'require("arkitekt.core.colors")' in content
    has_hexrgb_local = re.search(r'local\s+hexrgb\s*=', content)
    
    # Find hex color literals (0xRRGGBBAA format)
    hex_pattern = r'\b(0x[0-9A-Fa-f]{8})\b'
    
    # Check if file has any hex literals
    if not re.search(hex_pattern, content):
        return content, False  # No changes needed
    
    # Convert hex literals to hexrgb() format
    def hex_to_hexrgb(match):
        hex_val = match.group(1)
        # Extract RRGGBBAA
        rgb = hex_val[2:8]  # Skip '0x', take 6 chars
        aa = hex_val[8:10]  # Alpha channel
        
        # If alpha is FF, omit it; otherwise include
        if aa.upper() == 'FF':
            return f'hexrgb("#{rgb}")'
        else:
            return f'hexrgb("#{rgb}{aa}")'
    
    converted_content = re.sub(hex_pattern, hex_to_hexrgb, content)
    
    # Add imports if needed and conversions were made
    if converted_content != content and not has_colors_import:
        # Find where to insert (after other requires, before local M = {})
        lines = converted_content.split('\n')
        insert_idx = 0
        
        # Find last require or first local M
        for i, line in enumerate(lines):
            if 'require' in line and 'local' in line:
                insert_idx = i + 1
            elif re.match(r'local\s+M\s*=\s*\{', line) and insert_idx == 0:
                insert_idx = i
                break
        
        # Insert Colors import and hexrgb local
        if not has_colors_import:
            lines.insert(insert_idx, "local Colors = require('arkitekt.core.colors')")
            insert_idx += 1
        if not has_hexrgb_local:
            lines.insert(insert_idx, "local hexrgb = Colors.hexrgb")
            insert_idx += 1
            lines.insert(insert_idx, "")  # Blank line
        
        converted_content = '\n'.join(lines)
    
    return converted_content, (converted_content != content)

def process_directory(root_dir, dry_run=True):
    """Process all .lua files in directory."""
    root_path = Path(root_dir)
    stats = {'processed': 0, 'modified': 0, 'errors': 0}
    
    for lua_file in root_path.rglob('*.lua'):
        try:
            with open(lua_file, 'r', encoding='utf-8') as f:
                original = f.read()
            
            converted, changed = convert_hex_to_hexrgb(original, lua_file)
            
            stats['processed'] += 1
            if changed:
                stats['modified'] += 1
                print(f"{'[DRY RUN] ' if dry_run else ''}Modified: {lua_file.relative_to(root_path)}")
                
                if not dry_run:
                    with open(lua_file, 'w', encoding='utf-8') as f:
                        f.write(converted)
        
        except Exception as e:
            stats['errors'] += 1
            print(f"Error processing {lua_file}: {e}")
    
    return stats

if __name__ == '__main__':
    ARKITEKT_DIR = r'd:\Dropbox\REAPER\Scripts\ARKITEKT-Project\ARKITEKT'
    
    print("=== DRY RUN ===")
    stats = process_directory(ARKITEKT_DIR, dry_run=True)
    print(f"\nProcessed: {stats['processed']}, Would modify: {stats['modified']}, Errors: {stats['errors']}")
    
    response = input("\nProceed with actual conversion? (yes/no): ")
    if response.lower() == 'yes':
        print("\n=== ACTUAL RUN ===")
        stats = process_directory(ARKITEKT_DIR, dry_run=False)
        print(f"\nProcessed: {stats['processed']}, Modified: {stats['modified']}, Errors: {stats['errors']}")