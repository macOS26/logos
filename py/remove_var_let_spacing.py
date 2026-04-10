#!/usr/bin/env python3
import os
import re
from pathlib import Path

def remove_var_let_spacing(file_path):
    """Remove single blank lines between consecutive var/let declarations"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content

        # Pattern to match var/let followed by blank line followed by var/let
        # This handles various line ending types and indentation

        # Match: (var/let line) + (blank line with possible whitespace) + (var/let line)
        # We need to preserve the indentation and structure

        # Pattern explanation:
        # (^[ \t]*(?:var|let|@\w+)\s+.*$) - First var/let line (with possible @State, @Binding, etc)
        # [\r\n]+                          - Line ending
        # [ \t]*[\r\n]+                   - Blank line (whitespace + line ending)
        # ([ \t]*(?:var|let|@\w+))        - Start of next var/let line

        pattern = r'(^[ \t]*(?:@\w+[ \t]+)*(?:var|let)\s+.*$)([\r\n]+)[ \t]*[\r\n]+([ \t]*(?:@\w+[ \t]+)*(?:var|let)\s+)'

        modified = re.sub(pattern, r'\1\2\3', content, flags=re.MULTILINE)

        if modified != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(modified)
            return True
        return False
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    base_dir = Path('/Users/toddbruss/Documents/GitHub/logos')
    swift_files = list(base_dir.rglob('*.swift'))

    modified_count = 0

    for swift_file in swift_files:
        if remove_var_let_spacing(swift_file):
            modified_count += 1
            print(f"Fixed: {swift_file}")

    print(f"\nTotal files modified: {modified_count}")

if __name__ == '__main__':
    main()
