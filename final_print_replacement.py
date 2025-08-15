#!/usr/bin/env python3
"""
Final script to replace all remaining print statements with Swift logging calls.
This script handles all the remaining cases comprehensively.
"""

import os
import re
import glob

def replace_final_prints():
    """Replace all remaining print statements with appropriate logging calls."""
    
    # Define replacement patterns for all remaining print statements
    replacements = [
        # FileOperations specific patterns
        (r'print\("   Mapping: ([^"]+)"\)', r'Log.debug("   Mapping: \1", category: .fileOperations)'),
        (r'print\("   - x1: ([^"]+)"\)', r'Log.debug("   - x1: \1", category: .fileOperations)'),
        (r'print\("   - x2: ([^"]+)"\)', r'Log.debug("   - x2: \1", category: .fileOperations)'),
        (r'print\("   - y1: ([^"]+)"\)', r'Log.debug("   - y1: \1", category: .fileOperations)'),
        (r'print\("   - y2: ([^"]+)"\)', r'Log.debug("   - y2: \1", category: .fileOperations)'),
        (r'print\("   - gradientUnits: ([^"]+)"\)', r'Log.debug("   - gradientUnits: \1", category: .fileOperations)'),
        (r'print\("🎯 GRADIENT FROM SVG: ([^"]+)"\)', r'Log.debug("🎯 GRADIENT FROM SVG: \1", category: .fileOperations)'),
        (r'print\("   Start: ([^"]+)"\)', r'Log.debug("   Start: \1", category: .fileOperations)'),
        (r'print\("   End: ([^"]+)"\)', r'Log.debug("   End: \1", category: .fileOperations)'),
        (r'print\("🔥 FINAL GRADIENT: ([^"]+)"\)', r'Log.debug("🔥 FINAL GRADIENT: \1", category: .fileOperations)'),
        (r'print\("   - Start: ([^"]+)"\)', r'Log.debug("   - Start: \1", category: .fileOperations)'),
        (r'print\("🔧 Raw values: ([^"]+)"\)', r'Log.debug("🔧 Raw values: \1", category: .fileOperations)'),
        (r'print\("🎯 AUTO-CENTERED RADIAL: ([^"]+)"\)', r'Log.debug("🎯 AUTO-CENTERED RADIAL: \1", category: .fileOperations)'),
        (r'print\("🎯 STANDARD RADIAL: ([^"]+)"\)', r'Log.debug("🎯 STANDARD RADIAL: \1", category: .fileOperations)'),
        (r'print\("   Original: ([^"]+)"\)', r'Log.debug("   Original: \1", category: .fileOperations)'),
        (r'print\("   - Center: ([^"]+)"\)', r'Log.debug("   - Center: \1", category: .fileOperations)'),
        (r'print\("   Document size: ([^"]+)"\)', r'Log.debug("   Document size: \1", category: .fileOperations)'),
        (r'print\("   Focal: ([^"]+)"\)', r'Log.debug("   Focal: \1", category: .fileOperations)'),
        
        # Corner radius toolbar specific
        (r'print\("🔄 Updated corner ([^"]+)"\)', r'Log.debug("🔄 Updated corner \1", category: .shapes)'),
        
        # GPU acceleration specific
        (r'print\("✅ GPU Math Accelerator \(Simple\): Ready with ([^"]+)"\)', r'Log.metal("✅ GPU Math Accelerator (Simple): Ready with \1", level: .info)'),
        (r'print\("   Time: ([^"]+)"\)', r'Log.performance("   Time: \1", level: .debug)'),
        (r'print\("   Reduction: ([^"]+)"\)', r'Log.performance("   Reduction: \1", level: .debug)'),
        (r'print\("✅ Metal Drawing Optimizer: Initialized with ([^"]+)"\)', r'Log.metal("✅ Metal Drawing Optimizer: Initialized with \1", level: .info)'),
        
        # VectorDocument specific
        (r'print\("🔄 Unit changed to ([^"]+)"\)', r'Log.info("🔄 Unit changed to \1", category: .general)'),
        
        # Marker tool specific
        (r'print\("🎨 MARKER PRESSURE: ([^"]+)"\)', r'Log.debug("🎨 MARKER PRESSURE: \1", category: .pressure)'),
        (r'print\("🖊️ DOUGLAS-PEUCKER: ([^"]+)"\)', r'Log.debug("🖊️ DOUGLAS-PEUCKER: \1", category: .pressure)'),
        
        # Corner radius tool specific
        (r'print\("🔄 CORNER RADIUS TOOL: Ratio mode - scaling by ([^"]+)"\)', r'Log.debug("🔄 CORNER RADIUS TOOL: Ratio mode - scaling by \1", category: .shapes)'),
        (r'print\("🔄 CORNER RADIUS TOOL: Uniform mode - setting all corners to ([^"]+)"\)', r'Log.debug("🔄 CORNER RADIUS TOOL: Uniform mode - setting all corners to \1", category: .shapes)'),
        
        # PasteboardDiagnostics specific (these are debug/test outputs)
        (r'print\("  Layer names: ([^"]+)"\)', r'Log.debug("  Layer names: \1", category: .general)'),
        (r'print\("  Lock status: ([^"]+)"\)', r'Log.debug("  Lock status: \1", category: .general)'),
        (r'print\("  Overall: ([^"]+)"\)', r'Log.debug("  Overall: \1", category: .general)'),
        (r'print\("  Pasteboard shape: ([^"]+)"\)', r'Log.debug("  Pasteboard shape: \1", category: .general)'),
        (r'print\("  Canvas shape: ([^"]+)"\)', r'Log.debug("  Canvas shape: \1", category: .general)'),
        (r'print\("  Sizing: ([^"]+)"\)', r'Log.debug("  Sizing: \1", category: .general)'),
        (r'print\("  Positioning: ([^"]+)"\)', r'Log.debug("  Positioning: \1", category: .general)'),
        (r'print\("  Pasteboard hit: ([^"]+)"\)', r'Log.debug("  Pasteboard hit: \1", category: .general)'),
        (r'print\("  Canvas priority: ([^"]+)"\)', r'Log.debug("  Canvas priority: \1", category: .general)'),
        (r'print\("  Layer iteration: ([^"]+)"\)', r'Log.debug("  Layer iteration: \1", category: .general)'),
        (r'print\("      Testing Layer ([^"]+)"\)', r'Log.debug("      Testing Layer \1", category: .general)'),
        (r'print\("      Layers tested: ([^"]+)"\)', r'Log.debug("      Layers tested: \1", category: .general)'),
        (r'print\("      Background shapes tested: ([^"]+)"\)', r'Log.debug("      Background shapes tested: \1", category: .general)'),
        (r'print\("  Pasteboard object hit: ([^"]+)"\)', r'Log.debug("  Pasteboard object hit: \1", category: .general)'),
        (r'print\("  Canvas object hit: ([^"]+)"\)', r'Log.debug("  Canvas object hit: \1", category: .general)'),
        (r'print\("  Empty pasteboard hit: ([^"]+)"\)', r'Log.debug("  Empty pasteboard hit: \1", category: .general)'),
        (r'print\("  Total time: ([^"]+)"\)', r'Log.debug("  Total time: \1", category: .general)'),
        (r'print\("  Average per hit test: ([^"]+)"\)', r'Log.debug("  Average per hit test: \1", category: .general)'),
        (r'print\("Layer Structure:     ([^"]+)"\)', r'Log.debug("Layer Structure:     \1", category: .general)'),
        (r'print\("Background Shapes:   ([^"]+)"\)', r'Log.debug("Background Shapes:   \1", category: .general)'),
        (r'print\("Hit Testing:         ([^"]+)"\)', r'Log.debug("Hit Testing:         \1", category: .general)'),
        (r'print\("Real-World Scenarios:([^"]+)"\)', r'Log.debug("Real-World Scenarios:\1", category: .general)'),
        (r'print\("Performance:         ([^"]+)"\)', r'Log.debug("Performance:         \1", category: .general)'),
        (r'print\("OVERALL:             ([^"]+)"\)', r'Log.debug("OVERALL:             \1", category: .general)'),
        
        # Zoom specific
        (r'print\("🔍 PROFESSIONAL ZOOM COMPLETED: ([^"]+)"\)', r'Log.debug("🔍 PROFESSIONAL ZOOM COMPLETED: \1", category: .zoom)'),
        
        # Freehand tool specific
        (r'print\("🖊️ DOUGLAS-PEUCKER: Simplified to ([^"]+)"\)', r'Log.debug("🖊️ DOUGLAS-PEUCKER: Simplified to \1", category: .pressure)'),
        
        # Corner radius edit tool specific
        (r'print\("🔄 PROPORTIONAL CORNER RADIUS: Ratio mode - scaling by ([^"]+)"\)', r'Log.debug("🔄 PROPORTIONAL CORNER RADIUS: Ratio mode - scaling by \1", category: .shapes)'),
        (r'print\("🔄 PROPORTIONAL CORNER RADIUS: Uniform mode - setting all corners to ([^"]+)"\)', r'Log.debug("🔄 PROPORTIONAL CORNER RADIUS: Uniform mode - setting all corners to \1", category: .shapes)'),
        (r'print\("🔄 PROPORTIONAL CORNER RADIUS \(fallback\): Ratio mode - scaling by ([^"]+)"\)', r'Log.debug("🔄 PROPORTIONAL CORNER RADIUS (fallback): Ratio mode - scaling by \1", category: .shapes)'),
        (r'print\("🔄 PROPORTIONAL CORNER RADIUS \(fallback\): Uniform mode - setting all corners to ([^"]+)"\)', r'Log.debug("🔄 PROPORTIONAL CORNER RADIUS (fallback): Uniform mode - setting all corners to \1", category: .shapes)'),
        (r'print\("🔄 PROPORTIONAL ROUNDING: Ratio mode - scaling by ([^"]+)"\)', r'Log.debug("🔄 PROPORTIONAL ROUNDING: Ratio mode - scaling by \1", category: .shapes)'),
        (r'print\("🔄 PROPORTIONAL ROUNDING: Uniform mode - setting all corners to ([^"]+)"\)', r'Log.debug("🔄 PROPORTIONAL ROUNDING: Uniform mode - setting all corners to \1", category: .shapes)'),
        
        # Bezier tool specific
        (r'print\("🎯 BEZIER PEN: Drag distance ([^"]+)"\)', r'Log.debug("🎯 BEZIER PEN: Drag distance \1", category: .shapes)'),
        (r'print\("🎯 EXISTING POINT: Using last point at ([^"]+)"\)', r'Log.debug("🎯 EXISTING POINT: Using last point at \1", category: .shapes)'),
        
        # Font panel specific
        (r'print\("🎯 FONT PANEL: Updating weight from ([^"]+)"\)', r'Log.info("🎯 FONT PANEL: Updating weight from \1", category: .general)'),
        (r'print\("🎯 FONT PANEL: Updating style from ([^"]+)"\)', r'Log.info("🎯 FONT PANEL: Updating style from \1", category: .general)'),
        (r'print\("🎯 FONT PANEL: Updating document weight from ([^"]+)"\)', r'Log.info("🎯 FONT PANEL: Updating document weight from \1", category: .general)'),
        (r'print\("🎯 FONT PANEL: Updating document style from ([^"]+)"\)', r'Log.info("🎯 FONT PANEL: Updating document style from \1", category: .general)'),
        
        # Text handling specific
        (r'print\("📝 TEXT BOX CREATED: User-drawn size ([^"]+)"\)', r'Log.debug("📝 TEXT BOX CREATED: User-drawn size \1", category: .shapes)'),
        (r'print\("✅ RESIZE HANDLE HIT: ([^"]+)"\)', r'Log.debug("✅ RESIZE HANDLE HIT: \1", category: .shapes)'),
        
        # Professional text canvas specific
        (r'print\("🎯 NSTextView MODE \([^"]+\):"\)', r'Log.debug("🎯 NSTextView MODE (\1):", category: .shapes)'),
        (r'print\("📏 UPDATING TEXT CONTAINER WIDTH: ([^"]+)"\)', r'Log.debug("📏 UPDATING TEXT CONTAINER WIDTH: \1", category: .shapes)'),
        
        # Layer view specific patterns (all the complex ones)
        (r'print\("🔄 SCALING START: ([^"]+)"\)', r'Log.debug("🔄 SCALING START: \1", category: .shapes)'),
        (r'print\("   📐 Initial bounds: ([^"]+)"\)', r'Log.debug("   📐 Initial bounds: \1", category: .shapes)'),
        (r'print\("   🖱️ Start cursor: screen([^"]+)"\)', r'Log.debug("   🖱️ Start cursor: screen\1", category: .shapes)'),
        (r'print\("🔀 PROPORTIONAL SCALING: ([^"]+)"\)', r'Log.debug("🔀 PROPORTIONAL SCALING: \1", category: .shapes)'),
        (r'print\("🔢 SCALING: ([^"]+)"\)', r'Log.debug("🔢 SCALING: \1", category: .shapes)'),
        (r'print\("   🖱️ Cursor: ([^"]+)"\)', r'Log.debug("   🖱️ Cursor: \1", category: .shapes)'),
        (r'print\("   ⚓ Anchor screen: ([^"]+)"\)', r'Log.debug("   ⚓ Anchor screen: \1", category: .shapes)'),
        (r'print\("   🎯 Adaptive thresholds: ([^"]+)"\)', r'Log.debug("   🎯 Adaptive thresholds: \1", category: .shapes)'),
        (r'print\("   📊 Preview transform: ([^"]+)"\)', r'Log.debug("   📊 Preview transform: \1", category: .shapes)'),
        (r'print\("   🎯 FINAL MARQUEE: ([^"]+)"\)', r'Log.debug("   🎯 FINAL MARQUEE: \1", category: .shapes)'),
        (r'print\("   📐 Old bounds: ([^"]+)"\)', r'Log.debug("   📐 Old bounds: \1", category: .shapes)'),
        (r'print\("   📐 New bounds: ([^"]+)"\)', r'Log.debug("   📐 New bounds: \1", category: .shapes)'),
        (r'print\("🔴 LOCKED PIN: ([^"]+)"\)', r'Log.debug("🔴 LOCKED PIN: \1", category: .shapes)'),
        (r'print\("🔢 SCALING AWAY FROM PIN: ([^"]+)"\)', r'Log.debug("🔢 SCALING AWAY FROM PIN: \1", category: .shapes)'),
        (r'print\("   📐 Original bounds: ([^"]+)"\)', r'Log.debug("   📐 Original bounds: \1", category: .shapes)'),
        (r'print\("🔄 FORCE UPDATED scale points - ([^"]+)"\)', r'Log.debug("🔄 FORCE UPDATED scale points - \1", category: .shapes)'),
        (r'print\("      Original bounds: ([^"]+)"\)', r'Log.debug("      Original bounds: \1", category: .shapes)'),
        (r'print\("      Final marquee bounds: ([^"]+)"\)', r'Log.debug("      Final marquee bounds: \1", category: .shapes)'),
        (r'print\("      Anchor point: ([^"]+)"\)', r'Log.debug("      Anchor point: \1", category: .shapes)'),
        (r'print\("      Scale factors: ([^"]+)"\)', r'Log.debug("      Scale factors: \1", category: .shapes)'),
        (r'print\("🎯 ANCHOR SELECTED: ([^"]+)"\)', r'Log.debug("🎯 ANCHOR SELECTED: \1", category: .shapes)'),
        (r'print\("🔄 ROTATING: ([^"]+)"\)', r'Log.debug("🔄 ROTATING: \1", category: .shapes)'),
        (r'print\("🔄 ROTATION START: ([^"]+)"\)', r'Log.debug("🔄 ROTATION START: \1", category: .shapes)'),
        (r'print\("   📐 Using ORIGINAL bounds: ([^"]+)"\)', r'Log.debug("   📐 Using ORIGINAL bounds: \1", category: .shapes)'),
        (r'print\("🔄 FORCE UPDATED rotation points - ([^"]+)"\)', r'Log.debug("🔄 FORCE UPDATED rotation points - \1", category: .shapes)'),
        (r'print\("🔄 ROTATION START: Corner ([^"]+)"\)', r'Log.debug("🔄 ROTATION START: Corner \1", category: .shapes)'),
        (r'print\("      Anchor point: ([^"]+)"\)', r'Log.debug("      Anchor point: \1", category: .shapes)'),
        (r'print\("      Rotation angle: ([^"]+)"\)', r'Log.debug("      Rotation angle: \1", category: .shapes)'),
        (r'print\("   📊 Rotation preview updated: ([^"]+)"\)', r'Log.debug("   📊 Rotation preview updated: \1", category: .shapes)'),
        (r'print\("   📊 Preview transform: ([^"]+)"\)', r'Log.debug("   📊 Preview transform: \1", category: .shapes)'),
        
        # Catch any remaining print statements
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
    replace_final_prints()
    print("Final print statement replacement completed!")
