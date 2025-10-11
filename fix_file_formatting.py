#!/usr/bin/env python3
"""
Fix file formatting:
- Remove leading empty lines
- Remove trailing empty lines
- Ensure no more than 2 empty lines between functions/classes/etc
"""

import os
import re

def fix_file_formatting(content):
    """Fix formatting issues in file content."""
    if not content:
        return content

    lines = content.split('\n')

    # Remove leading empty lines
    while lines and not lines[0].strip():
        lines.pop(0)

    # Remove trailing empty lines
    while lines and not lines[-1].strip():
        lines.pop()

    # Fix excessive empty lines (no more than 2 consecutive)
    result_lines = []
    empty_count = 0

    for line in lines:
        if not line.strip():
            empty_count += 1
            if empty_count <= 2:
                result_lines.append(line)
        else:
            empty_count = 0
            result_lines.append(line)

    # Join and ensure file ends with exactly one newline
    result = '\n'.join(result_lines)
    if result and not result.endswith('\n'):
        result += '\n'

    return result

def process_file(filepath):
    """Process a single file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content
        fixed_content = fix_file_formatting(content)

        if fixed_content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def find_code_files(root_dir):
    """Find all Swift and Metal files."""
    code_files = []
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Skip hidden directories and build directories
        dirnames[:] = [d for d in dirnames if not d.startswith('.') and d not in ['build', 'DerivedData', 'Pods']]

        for filename in filenames:
            if filename.endswith(('.swift', '.metal')):
                code_files.append(os.path.join(dirpath, filename))

    return code_files

def main():
    root_dir = '/Users/toddbruss/Documents/GitHub/logos'

    print("Finding Swift and Metal files...")
    code_files = find_code_files(root_dir)
    print(f"Found {len(code_files)} files")

    modified_count = 0
    for filepath in code_files:
        rel_path = os.path.relpath(filepath, root_dir)
        if process_file(filepath):
            print(f"✓ Fixed: {rel_path}")
            modified_count += 1

    print(f"\nComplete! Modified {modified_count} files out of {len(code_files)} total files.")

if __name__ == "__main__":
    main()