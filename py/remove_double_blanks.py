#!/usr/bin/env python3
import os
import re
from pathlib import Path

def is_in_string_literal(content, pos):
    """Check if position is inside a string literal (between quotes)"""
    # Find all string literal ranges
    triple_quote_pattern = r'"""[\s\S]*?"""'
    single_quote_pattern = r'"(?:[^"\\]|\\.)*?"'

    ranges = []
    for match in re.finditer(triple_quote_pattern, content):
        ranges.append((match.start(), match.end()))
    for match in re.finditer(single_quote_pattern, content):
        ranges.append((match.start(), match.end()))

    for start, end in ranges:
        if start <= pos < end:
            return True
    return False

def remove_double_blank_lines(file_path):
    """Remove double blank lines from a file, excluding string literals"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content

        # Replace 3+ consecutive newlines with exactly 2 newlines (1 blank line)
        # This handles \n\n\n+ patterns
        modified = re.sub(r'\n\n\n+', '\n\n', content)

        # Handle \r\n\r\n\r\n+ patterns
        modified = re.sub(r'\r\n\r\n\r\n+', '\r\n\r\n', modified)

        # Handle \r\r\r+ patterns
        modified = re.sub(r'\r\r\r+', '\r\r', modified)

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
        if remove_double_blank_lines(swift_file):
            modified_count += 1
            print(f"Fixed: {swift_file}")

    print(f"\nTotal files modified: {modified_count}")

if __name__ == '__main__':
    main()
