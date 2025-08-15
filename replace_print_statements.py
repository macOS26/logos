#!/usr/bin/env python3
"""
Script to replace print statements with Swift logging calls in the logos project.
This script will systematically replace print statements based on their content and context.
"""

import os
import re
import glob

def replace_print_statements():
    """Replace print statements with appropriate logging calls."""
    
    # Define replacement patterns
    replacements = [
        # Error patterns
        (r'print\("❌ ([^"]+)"\)', r'Log.error("❌ \1", category: .error)'),
        (r'print\("❌ ([^"]+)"\)', r'Log.error("❌ \1", category: .error)'),
        
        # Success patterns
        (r'print\("✅ ([^"]+)"\)', r'Log.info("✅ \1", category: .fileOperations)'),
        (r'print\("✅ ([^"]+)"\)', r'Log.info("✅ \1", category: .general)'),
        
        # Info patterns
        (r'print\("📊 ([^"]+)"\)', r'Log.fileOperation("📊 \1", level: .info)'),
        (r'print\("🔄 ([^"]+)"\)', r'Log.fileOperation("🔄 \1", level: .info)'),
        (r'print\("📋 ([^"]+)"\)', r'Log.fileOperation("📋 \1", level: .info)'),
        (r'print\("🔧 ([^"]+)"\)', r'Log.fileOperation("🔧 \1", level: .info)'),
        (r'print\("🎨 ([^"]+)"\)', r'Log.fileOperation("🎨 \1", level: .info)'),
        (r'print\("🔤 ([^"]+)"\)', r'Log.fileOperation("🔤 \1", level: .info)'),
        (r'print\("📝 ([^"]+)"\)', r'Log.fileOperation("📝 \1", level: .info)'),
        (r'print\("📐 ([^"]+)"\)', r'Log.fileOperation("📐 \1", level: .info)'),
        (r'print\("🏷️ ([^"]+)"\)', r'Log.fileOperation("🏷️ \1", level: .info)'),
        (r'print\("🎯 ([^"]+)"\)', r'Log.fileOperation("🎯 \1", level: .info)'),
        (r'print\("🧬 ([^"]+)"\)', r'Log.fileOperation("🧬 \1", level: .info)'),
        (r'print\("🚨 ([^"]+)"\)', r'Log.fileOperation("🚨 \1", level: .info)'),
        (r'print\("⚠️ ([^"]+)"\)', r'Log.fileOperation("⚠️ \1", level: .info)'),
        (r'print\("💡 ([^"]+)"\)', r'Log.fileOperation("💡 \1", level: .info)'),
        (r'print\("🖼️ ([^"]+)"\)', r'Log.fileOperation("🖼️ \1", level: .info)'),
        (r'print\("🖊️ ([^"]+)"\)', r'Log.fileOperation("🖊️ \1", level: .info)'),
        (r'print\("⚪ ([^"]+)"\)', r'Log.fileOperation("⚪ \1", level: .info)'),
        (r'print\("🔥 ([^"]+)"\)', r'Log.fileOperation("🔥 \1", level: .info)'),
        
        # Warning patterns
        (r'print\("⚠️ ([^"]+)"\)', r'Log.warning("⚠️ \1", category: .fileOperations)'),
        
        # Debug patterns for specific categories
        (r'print\("🔍 ([^"]+)"\)', r'Log.debug("🔍 \1", category: .general)'),
        
        # General patterns that don't fit above
        (r'print\("([^"]+)"\)', r'Log.info("\1", category: .general)'),
    ]
    
    # Get all Swift files
    swift_files = glob.glob("logos inkpen.io/**/*.swift", recursive=True)
    
    for file_path in swift_files:
        print(f"Processing: {file_path}")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            
            # Apply replacements
            for pattern, replacement in replacements:
                content = re.sub(pattern, replacement, content)
            
            # Write back if changed
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"  Updated: {file_path}")
            else:
                print(f"  No changes: {file_path}")
                
        except Exception as e:
            print(f"  Error processing {file_path}: {e}")

if __name__ == "__main__":
    replace_print_statements()
    print("Print statement replacement completed!")
