import os
import re
from pathlib import Path
def remove_comments_and_blank_lines(file_path):
    """Remove all // and /// comments and clean up resulting blank lines"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        original_content = ''.join(lines)
        new_lines = []
        for line in lines:
            stripped = line.lstrip()
            if stripped.startswith('//'):
                continue
            if '//' in line:
                in_string = False
                quote_char = None
                comment_pos = -1
                i = 0
                while i < len(line):
                    char = line[i]
                    if char == '\\' and in_string:
                        i += 2
                        continue
                    if char in ('"', "'") and (i == 0 or line[i-1] != '\\'):
                        if not in_string:
                            in_string = True
                            quote_char = char
                        elif char == quote_char:
                            in_string = False
                            quote_char = None
                    if not in_string and i < len(line) - 1 and line[i:i+2] == '//':
                        comment_pos = i
                        break
                    i += 1
                if comment_pos >= 0:
                    line_without_comment = line[:comment_pos].rstrip()
                    if line_without_comment.strip():
                        new_lines.append(line_without_comment + '\n')
                    continue
            new_lines.append(line)
        final_lines = []
        prev_blank = False
        for line in new_lines:
            is_blank = line.strip() == ''
            if is_blank and prev_blank:
                continue
            final_lines.append(line)
            prev_blank = is_blank
        new_content = ''.join(final_lines)
        if new_content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
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
        if remove_comments_and_blank_lines(swift_file):
            modified_count += 1
            print(f"Fixed: {swift_file}")
    print(f"\nTotal files modified: {modified_count}")
if __name__ == '__main__':
    main()
