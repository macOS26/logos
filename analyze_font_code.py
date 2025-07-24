#!/usr/bin/env python3
"""
Font and Color Code Analysis Script
Identifies unused, redundant, and legacy font/color code in the logos project
"""

import os
import re
import json
from pathlib import Path
from collections import defaultdict

class CodeAnalyzer:
    def __init__(self, project_path):
        self.project_path = Path(project_path)
        self.swift_files = []
        self.findings = {
            'unused_font_properties': [],
            'redundant_color_code': [],
            'legacy_implementations': [],
            'duplicate_font_handling': [],
            'unused_imports': [],
            'dead_code_blocks': []
        }
        
    def scan_swift_files(self):
        """Scan for all Swift files in the project"""
        for file_path in self.project_path.rglob("*.swift"):
            if "xcodeproj" not in str(file_path):  # Skip Xcode project files
                self.swift_files.append(file_path)
        print(f"Found {len(self.swift_files)} Swift files to analyze")
    
    def analyze_font_properties(self):
        """Analyze font-related properties and their usage"""
        font_properties = [
            'fontFamily', 'fontWeight', 'fontStyle', 'fontSize',
            'lineHeight', 'lineSpacing', 'letterSpacing',
            'strokeColor', 'fillColor', 'strokeWidth', 'fillOpacity'
        ]
        
        property_usage = defaultdict(list)
        
        for file_path in self.swift_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                for prop in font_properties:
                    # Look for property declarations and usage
                    if re.search(rf'\b{prop}\b', content):
                        property_usage[prop].append(str(file_path.relative_to(self.project_path)))
                        
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
        
        # Identify rarely used properties
        for prop, files in property_usage.items():
            if len(files) <= 2:  # Used in 2 or fewer files
                self.findings['unused_font_properties'].append({
                    'property': prop,
                    'usage_count': len(files),
                    'files': files
                })
    
    def analyze_redundant_color_code(self):
        """Find redundant color handling code"""
        color_patterns = [
            r'VectorColor\.\w+',  # VectorColor static properties
            r'NSColor\(.+?\)',    # NSColor initializers
            r'Color\(.+?\)',      # SwiftUI Color initializers
            r'CGColor\(',         # Core Graphics colors
            r'\.foregroundColor\(',  # SwiftUI foregroundColor
            r'\.textColor\s*=',   # NSView textColor assignments
        ]
        
        color_usage = defaultdict(set)
        
        for file_path in self.swift_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                for pattern in color_patterns:
                    matches = re.findall(pattern, content)
                    for match in matches:
                        color_usage[match].add(str(file_path.relative_to(self.project_path)))
                        
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
        
        # Find colors used in only one place
        for color_code, files in color_usage.items():
            if len(files) == 1:
                self.findings['redundant_color_code'].append({
                    'color_code': color_code,
                    'file': list(files)[0]
                })
    
    def analyze_legacy_code(self):
        """Find legacy code marked for removal"""
        legacy_markers = [
            r'// LEGACY.*',
            r'// REMOVED.*',
            r'// TODO.*remove.*',
            r'// FIXME.*remove.*',
            r'// DEPRECATED.*',
            r'// OLD.*',
            r'// Legacy.*',
            r'Legacy\w+',  # Classes/structs with "Legacy" in name
        ]
        
        for file_path in self.swift_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    
                for i, line in enumerate(lines):
                    for pattern in legacy_markers:
                        if re.search(pattern, line, re.IGNORECASE):
                            self.findings['legacy_implementations'].append({
                                'file': str(file_path.relative_to(self.project_path)),
                                'line': i + 1,
                                'content': line.strip(),
                                'type': 'legacy_marker'
                            })
                            
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
    
    def analyze_duplicate_font_handling(self):
        """Find duplicate font handling implementations"""
        font_patterns = [
            r'NSFont\(',
            r'Font\.',
            r'FontManager',
            r'FontPickerView',
            r'fontFamily',
            r'NSFontManager',
            r'createFont',
            r'selectedFont'
        ]
        
        font_implementations = defaultdict(list)
        
        for file_path in self.swift_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                # Count font-related patterns per file
                font_count = 0
                for pattern in font_patterns:
                    font_count += len(re.findall(pattern, content))
                
                if font_count > 10:  # Files with heavy font usage
                    font_implementations['heavy_font_usage'].append({
                        'file': str(file_path.relative_to(self.project_path)),
                        'font_references': font_count
                    })
                    
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
        
        self.findings['duplicate_font_handling'] = font_implementations
    
    def analyze_unused_imports(self):
        """Find potentially unused imports related to fonts/colors"""
        target_imports = [
            'import AppKit',
            'import Foundation',
            'import SwiftUI',
            'import CoreText',
            'import CoreGraphics'
        ]
        
        for file_path in self.swift_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    lines = content.split('\n')
                    
                imports = []
                for line in lines:
                    for target_import in target_imports:
                        if line.strip().startswith(target_import):
                            imports.append(target_import)
                
                # Simple heuristic: if file has imports but minimal code
                if imports and len(content.split('\n')) < 50:
                    self.findings['unused_imports'].append({
                        'file': str(file_path.relative_to(self.project_path)),
                        'imports': imports,
                        'line_count': len(content.split('\n'))
                    })
                    
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
    
    def analyze_dead_code(self):
        """Find commented out code blocks that might be removable"""
        for file_path in self.swift_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    
                comment_block = []
                in_comment_block = False
                
                for i, line in enumerate(lines):
                    stripped = line.strip()
                    
                    # Detect start of comment block
                    if stripped.startswith('//') and any(keyword in stripped.lower() for keyword in ['removed', 'unused', 'legacy', 'old', 'todo']):
                        if not in_comment_block:
                            comment_block = [(i + 1, line.strip())]
                            in_comment_block = True
                        else:
                            comment_block.append((i + 1, line.strip()))
                    elif stripped.startswith('//') and in_comment_block:
                        comment_block.append((i + 1, line.strip()))
                    else:
                        if in_comment_block and len(comment_block) > 3:  # Only report longer comment blocks
                            self.findings['dead_code_blocks'].append({
                                'file': str(file_path.relative_to(self.project_path)),
                                'start_line': comment_block[0][0],
                                'end_line': comment_block[-1][0],
                                'lines': len(comment_block),
                                'preview': comment_block[0][1]
                            })
                        comment_block = []
                        in_comment_block = False
                        
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
    
    def generate_report(self):
        """Generate analysis report"""
        print("\n" + "="*80)
        print("FONT AND COLOR CODE ANALYSIS REPORT")
        print("="*80)
        
        print(f"\n📊 ANALYSIS SUMMARY:")
        print(f"   • Files analyzed: {len(self.swift_files)}")
        print(f"   • Unused font properties: {len(self.findings['unused_font_properties'])}")
        print(f"   • Redundant color code: {len(self.findings['redundant_color_code'])}")
        print(f"   • Legacy implementations: {len(self.findings['legacy_implementations'])}")
        print(f"   • Dead code blocks: {len(self.findings['dead_code_blocks'])}")
        
        # Unused Font Properties
        if self.findings['unused_font_properties']:
            print(f"\n🚫 UNUSED FONT PROPERTIES ({len(self.findings['unused_font_properties'])}):")
            for item in self.findings['unused_font_properties']:
                print(f"   • {item['property']} (used in {item['usage_count']} files)")
                for file in item['files'][:3]:  # Show first 3 files
                    print(f"     - {file}")
        
        # Legacy Code
        if self.findings['legacy_implementations']:
            print(f"\n🗂️ LEGACY CODE MARKERS ({len(self.findings['legacy_implementations'])}):")
            for item in self.findings['legacy_implementations'][:10]:  # Show first 10
                print(f"   • {item['file']}:{item['line']} - {item['content'][:60]}...")
        
        # Dead Code Blocks
        if self.findings['dead_code_blocks']:
            print(f"\n💀 DEAD CODE BLOCKS ({len(self.findings['dead_code_blocks'])}):")
            for item in self.findings['dead_code_blocks'][:5]:  # Show first 5
                print(f"   • {item['file']} lines {item['start_line']}-{item['end_line']} ({item['lines']} lines)")
                print(f"     Preview: {item['preview']}")
        
        # Redundant Color Code
        if self.findings['redundant_color_code']:
            print(f"\n🎨 SINGLE-USE COLOR CODE ({len(self.findings['redundant_color_code'])}):")
            for item in self.findings['redundant_color_code'][:10]:  # Show first 10
                print(f"   • {item['color_code']} in {item['file']}")
        
        # Font Handling Analysis
        if 'heavy_font_usage' in self.findings['duplicate_font_handling']:
            print(f"\n🔤 HEAVY FONT USAGE FILES:")
            for item in self.findings['duplicate_font_handling']['heavy_font_usage']:
                print(f"   • {item['file']} ({item['font_references']} font references)")
        
        print(f"\n💡 RECOMMENDATIONS:")
        print("   1. Review legacy code markers for removal opportunities")
        print("   2. Consolidate font handling in FontManager and FontPanel")
        print("   3. Remove Test/FontPickerView.swift if ProfessionalTextCanvas is working")
        print("   4. Clean up commented-out code blocks")
        print("   5. Consider removing rarely-used font properties")
        
        return self.findings
    
    def run_analysis(self):
        """Run complete analysis"""
        print("Starting font and color code analysis...")
        
        self.scan_swift_files()
        self.analyze_font_properties()
        self.analyze_redundant_color_code()
        self.analyze_legacy_code()
        self.analyze_duplicate_font_handling()
        self.analyze_unused_imports()
        self.analyze_dead_code()
        
        return self.generate_report()

def main():
    # Analyze the current project
    project_path = "logos inkpen.io"
    
    if not os.path.exists(project_path):
        print(f"Error: Project path '{project_path}' not found")
        print("Please run this script from the project root directory")
        return
    
    analyzer = CodeAnalyzer(project_path)
    findings = analyzer.run_analysis()
    
    # Save findings to JSON for further analysis
    with open("font_analysis_results.json", "w") as f:
        json.dump(findings, f, indent=2)
    
    print(f"\n📄 Detailed findings saved to: font_analysis_results.json")

if __name__ == "__main__":
    main() 