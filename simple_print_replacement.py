#!/usr/bin/env python3
"""
Simple script to replace remaining print statements with Swift logging calls.
This script uses simple string replacement to avoid regex complexity.
"""

import os
import glob

def replace_simple_prints():
    """Replace remaining print statements with simple string replacement."""
    
    # Define simple replacements
    replacements = [
        # FileOperations specific
        ('print("   Mapping:', 'Log.debug("   Mapping:', '.fileOperations)'),
        ('print("   - x1:', 'Log.debug("   - x1:', '.fileOperations)'),
        ('print("   - x2:', 'Log.debug("   - x2:', '.fileOperations)'),
        ('print("   - y1:', 'Log.debug("   - y1:', '.fileOperations)'),
        ('print("   - y2:', 'Log.debug("   - y2:', '.fileOperations)'),
        ('print("   - gradientUnits:', 'Log.debug("   - gradientUnits:', '.fileOperations)'),
        ('print("🎯 GRADIENT FROM SVG:', 'Log.debug("🎯 GRADIENT FROM SVG:', '.fileOperations)'),
        ('print("   Start:', 'Log.debug("   Start:', '.fileOperations)'),
        ('print("   End:', 'Log.debug("   End:', '.fileOperations)'),
        ('print("🔥 FINAL GRADIENT:', 'Log.debug("🔥 FINAL GRADIENT:', '.fileOperations)'),
        ('print("   - Start:', 'Log.debug("   - Start:', '.fileOperations)'),
        ('print("🔧 Raw values:', 'Log.debug("🔧 Raw values:', '.fileOperations)'),
        ('print("🎯 AUTO-CENTERED RADIAL:', 'Log.debug("🎯 AUTO-CENTERED RADIAL:', '.fileOperations)'),
        ('print("🎯 STANDARD RADIAL:', 'Log.debug("🎯 STANDARD RADIAL:', '.fileOperations)'),
        ('print("   Original:', 'Log.debug("   Original:', '.fileOperations)'),
        ('print("   - Center:', 'Log.debug("   - Center:', '.fileOperations)'),
        ('print("   Document size:', 'Log.debug("   Document size:', '.fileOperations)'),
        ('print("   Focal:', 'Log.debug("   Focal:', '.fileOperations)'),
        
        # GPU acceleration specific
        ('print("✅ GPU Math Accelerator (Simple): Ready with', 'Log.metal("✅ GPU Math Accelerator (Simple): Ready with', ', level: .info)'),
        ('print("   Time:', 'Log.performance("   Time:', ', level: .debug)'),
        ('print("   Reduction:', 'Log.performance("   Reduction:', ', level: .debug)'),
        ('print("✅ Metal Drawing Optimizer: Initialized with', 'Log.metal("✅ Metal Drawing Optimizer: Initialized with', ', level: .info)'),
        
        # VectorDocument specific
        ('print("🔄 Unit changed to', 'Log.info("🔄 Unit changed to', ', category: .general)'),
        
        # Marker tool specific
        ('print("🎨 MARKER PRESSURE:', 'Log.debug("🎨 MARKER PRESSURE:', ', category: .pressure)'),
        ('print("🖊️ DOUGLAS-PEUCKER:', 'Log.debug("🖊️ DOUGLAS-PEUCKER:', ', category: .pressure)'),
        
        # Corner radius tool specific
        ('print("🔄 CORNER RADIUS TOOL: Ratio mode - scaling by', 'Log.debug("🔄 CORNER RADIUS TOOL: Ratio mode - scaling by', ', category: .shapes)'),
        ('print("🔄 CORNER RADIUS TOOL: Uniform mode - setting all corners to', 'Log.debug("🔄 CORNER RADIUS TOOL: Uniform mode - setting all corners to', ', category: .shapes)'),
        
        # Corner radius toolbar specific
        ('print("🔄 Updated corner', 'Log.debug("🔄 Updated corner', ', category: .shapes)'),
        
        # Zoom specific
        ('print("🔍 PROFESSIONAL ZOOM COMPLETED:', 'Log.debug("🔍 PROFESSIONAL ZOOM COMPLETED:', ', category: .zoom)'),
        
        # Freehand tool specific
        ('print("🖊️ DOUGLAS-PEUCKER: Simplified to', 'Log.debug("🖊️ DOUGLAS-PEUCKER: Simplified to', ', category: .pressure)'),
        
        # Corner radius edit tool specific
        ('print("🔄 PROPORTIONAL CORNER RADIUS: Ratio mode - scaling by', 'Log.debug("🔄 PROPORTIONAL CORNER RADIUS: Ratio mode - scaling by', ', category: .shapes)'),
        ('print("🔄 PROPORTIONAL CORNER RADIUS: Uniform mode - setting all corners to', 'Log.debug("🔄 PROPORTIONAL CORNER RADIUS: Uniform mode - setting all corners to', ', category: .shapes)'),
        ('print("🔄 PROPORTIONAL CORNER RADIUS (fallback): Ratio mode - scaling by', 'Log.debug("🔄 PROPORTIONAL CORNER RADIUS (fallback): Ratio mode - scaling by', ', category: .shapes)'),
        ('print("🔄 PROPORTIONAL CORNER RADIUS (fallback): Uniform mode - setting all corners to', 'Log.debug("🔄 PROPORTIONAL CORNER RADIUS (fallback): Uniform mode - setting all corners to', ', category: .shapes)'),
        ('print("🔄 PROPORTIONAL ROUNDING: Ratio mode - scaling by', 'Log.debug("🔄 PROPORTIONAL ROUNDING: Ratio mode - scaling by', ', category: .shapes)'),
        ('print("🔄 PROPORTIONAL ROUNDING: Uniform mode - setting all corners to', 'Log.debug("🔄 PROPORTIONAL ROUNDING: Uniform mode - setting all corners to', ', category: .shapes)'),
        
        # Bezier tool specific
        ('print("🎯 BEZIER PEN: Drag distance', 'Log.debug("🎯 BEZIER PEN: Drag distance', ', category: .shapes)'),
        ('print("🎯 EXISTING POINT: Using last point at', 'Log.debug("🎯 EXISTING POINT: Using last point at', ', category: .shapes)'),
        
        # Font panel specific
        ('print("🎯 FONT PANEL: Updating weight from', 'Log.info("🎯 FONT PANEL: Updating weight from', ', category: .general)'),
        ('print("🎯 FONT PANEL: Updating style from', 'Log.info("🎯 FONT PANEL: Updating style from', ', category: .general)'),
        ('print("🎯 FONT PANEL: Updating document weight from', 'Log.info("🎯 FONT PANEL: Updating document weight from', ', category: .general)'),
        ('print("🎯 FONT PANEL: Updating document style from', 'Log.info("🎯 FONT PANEL: Updating document style from', ', category: .general)'),
        
        # Text handling specific
        ('print("📝 TEXT BOX CREATED: User-drawn size', 'Log.debug("📝 TEXT BOX CREATED: User-drawn size', ', category: .shapes)'),
        ('print("✅ RESIZE HANDLE HIT:', 'Log.debug("✅ RESIZE HANDLE HIT:', ', category: .shapes)'),
        
        # Professional text canvas specific
        ('print("🎯 NSTextView MODE (', 'Log.debug("🎯 NSTextView MODE (', ', category: .shapes)'),
        ('print("📏 UPDATING TEXT CONTAINER WIDTH:', 'Log.debug("📏 UPDATING TEXT CONTAINER WIDTH:', ', category: .shapes)'),
        
        # Layer view specific patterns
        ('print("🔄 SCALING START:', 'Log.debug("🔄 SCALING START:', ', category: .shapes)'),
        ('print("   📐 Initial bounds:', 'Log.debug("   📐 Initial bounds:', ', category: .shapes)'),
        ('print("   🖱️ Start cursor: screen', 'Log.debug("   🖱️ Start cursor: screen', ', category: .shapes)'),
        ('print("🔀 PROPORTIONAL SCALING:', 'Log.debug("🔀 PROPORTIONAL SCALING:', ', category: .shapes)'),
        ('print("🔢 SCALING:', 'Log.debug("🔢 SCALING:', ', category: .shapes)'),
        ('print("   🖱️ Cursor:', 'Log.debug("   🖱️ Cursor:', ', category: .shapes)'),
        ('print("   ⚓ Anchor screen:', 'Log.debug("   ⚓ Anchor screen:', ', category: .shapes)'),
        ('print("   🎯 Adaptive thresholds:', 'Log.debug("   🎯 Adaptive thresholds:', ', category: .shapes)'),
        ('print("   📊 Preview transform:', 'Log.debug("   📊 Preview transform:', ', category: .shapes)'),
        ('print("   🎯 FINAL MARQUEE:', 'Log.debug("   🎯 FINAL MARQUEE:', ', category: .shapes)'),
        ('print("   📐 Old bounds:', 'Log.debug("   📐 Old bounds:', ', category: .shapes)'),
        ('print("   📐 New bounds:', 'Log.debug("   📐 New bounds:', ', category: .shapes)'),
        ('print("🔴 LOCKED PIN:', 'Log.debug("🔴 LOCKED PIN:', ', category: .shapes)'),
        ('print("🔢 SCALING AWAY FROM PIN:', 'Log.debug("🔢 SCALING AWAY FROM PIN:', ', category: .shapes)'),
        ('print("   📐 Original bounds:', 'Log.debug("   📐 Original bounds:', ', category: .shapes)'),
        ('print("🔄 FORCE UPDATED scale points -', 'Log.debug("🔄 FORCE UPDATED scale points -', ', category: .shapes)'),
        ('print("      Original bounds:', 'Log.debug("      Original bounds:', ', category: .shapes)'),
        ('print("      Final marquee bounds:', 'Log.debug("      Final marquee bounds:', ', category: .shapes)'),
        ('print("      Anchor point:', 'Log.debug("      Anchor point:', ', category: .shapes)'),
        ('print("      Scale factors:', 'Log.debug("      Scale factors:', ', category: .shapes)'),
        ('print("🎯 ANCHOR SELECTED:', 'Log.debug("🎯 ANCHOR SELECTED:', ', category: .shapes)'),
        ('print("🔄 ROTATING:', 'Log.debug("🔄 ROTATING:', ', category: .shapes)'),
        ('print("🔄 ROTATION START:', 'Log.debug("🔄 ROTATION START:', ', category: .shapes)'),
        ('print("   📐 Using ORIGINAL bounds:', 'Log.debug("   📐 Using ORIGINAL bounds:', ', category: .shapes)'),
        ('print("🔄 FORCE UPDATED rotation points -', 'Log.debug("🔄 FORCE UPDATED rotation points -', ', category: .shapes)'),
        ('print("🔄 ROTATION START: Corner', 'Log.debug("🔄 ROTATION START: Corner', ', category: .shapes)'),
        ('print("      Anchor point:', 'Log.debug("      Anchor point:', ', category: .shapes)'),
        ('print("      Rotation angle:', 'Log.debug("      Rotation angle:', ', category: .shapes)'),
        ('print("   📊 Rotation preview updated:', 'Log.debug("   📊 Rotation preview updated:', ', category: .shapes)'),
        ('print("   📊 Preview transform:', 'Log.debug("   📊 Preview transform:', ', category: .shapes)'),
        
        # PasteboardDiagnostics specific
        ('print("  Layer names:', 'Log.debug("  Layer names:', ', category: .general)'),
        ('print("  Lock status:', 'Log.debug("  Lock status:', ', category: .general)'),
        ('print("  Overall:', 'Log.debug("  Overall:', ', category: .general)'),
        ('print("  Pasteboard shape:', 'Log.debug("  Pasteboard shape:', ', category: .general)'),
        ('print("  Canvas shape:', 'Log.debug("  Canvas shape:', ', category: .general)'),
        ('print("  Sizing:', 'Log.debug("  Sizing:', ', category: .general)'),
        ('print("  Positioning:', 'Log.debug("  Positioning:', ', category: .general)'),
        ('print("  Pasteboard hit:', 'Log.debug("  Pasteboard hit:', ', category: .general)'),
        ('print("  Canvas priority:', 'Log.debug("  Canvas priority:', ', category: .general)'),
        ('print("  Layer iteration:', 'Log.debug("  Layer iteration:', ', category: .general)'),
        ('print("      Testing Layer', 'Log.debug("      Testing Layer', ', category: .general)'),
        ('print("      Layers tested:', 'Log.debug("      Layers tested:', ', category: .general)'),
        ('print("      Background shapes tested:', 'Log.debug("      Background shapes tested:', ', category: .general)'),
        ('print("  Pasteboard object hit:', 'Log.debug("  Pasteboard object hit:', ', category: .general)'),
        ('print("  Canvas object hit:', 'Log.debug("  Canvas object hit:', ', category: .general)'),
        ('print("  Empty pasteboard hit:', 'Log.debug("  Empty pasteboard hit:', ', category: .general)'),
        ('print("  Total time:', 'Log.debug("  Total time:', ', category: .general)'),
        ('print("  Average per hit test:', 'Log.debug("  Average per hit test:', ', category: .general)'),
        ('print("Layer Structure:', 'Log.debug("Layer Structure:', ', category: .general)'),
        ('print("Background Shapes:', 'Log.debug("Background Shapes:', ', category: .general)'),
        ('print("Hit Testing:', 'Log.debug("Hit Testing:', ', category: .general)'),
        ('print("Real-World Scenarios:', 'Log.debug("Real-World Scenarios:', ', category: .general)'),
        ('print("Performance:', 'Log.debug("Performance:', ', category: .general)'),
        ('print("OVERALL:', 'Log.debug("OVERALL:', ', category: .general)'),
        
        # Catch any remaining print statements
        ('print("', 'Log.info("', ', category: .general)'),
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
            for old_pattern, new_pattern in replacements:
                content = content.replace(old_pattern, new_pattern)
            
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
    replace_simple_prints()
    print("Simple print statement replacement completed!")
