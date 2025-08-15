#!/usr/bin/env python3
"""
Script to replace remaining print statements with Swift logging calls in the logos project.
This script handles the more complex cases and specific categories.
"""

import os
import re
import glob

def replace_remaining_prints():
    """Replace remaining print statements with appropriate logging calls."""
    
    # Define replacement patterns for remaining print statements
    replacements = [
        # Debug/Info patterns for specific categories
        (r'print\("🎯 ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("🔄 ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("🔧 ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("📊 ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("📐 ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("🖱️ ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("⚓ ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("🎨 ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("🖊️ ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("✋ ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("🔀 ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("🔢 ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("🔴 ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("📝 ([^"]+)"\)', r'Log.debug("\1", category: .general)'),
        (r'print\("✅ ([^"]+)"\)', r'Log.info("\1", category: .general)'),
        
        # Performance and GPU related
        (r'print\("✅ GPU Math Accelerator \(Simple\): Ready with ([^"]+)"\)', r'Log.metal("✅ GPU Math Accelerator (Simple): Ready with \1", level: .info)'),
        (r'print\("   Time: ([^"]+)"\)', r'Log.performance("   Time: \1", level: .debug)'),
        (r'print\("   Reduction: ([^"]+)"\)', r'Log.performance("   Reduction: \1", level: .debug)'),
        (r'print\("✅ Metal Drawing Optimizer: Initialized with ([^"]+)"\)', r'Log.metal("✅ Metal Drawing Optimizer: Initialized with \1", level: .info)'),
        
        # Font panel specific
        (r'print\("🎯 FONT PANEL: ([^"]+)"\)', r'Log.info("🎯 FONT PANEL: \1", category: .general)'),
        
        # Gradient panel specific
        (r'print\("✅ OFFSET PATH: ([^"]+)"\)', r'Log.info("✅ OFFSET PATH: \1", category: .shapes)'),
        
        # Marker tool specific
        (r'print\("🎨 MARKER PRESSURE: ([^"]+)"\)', r'Log.debug("🎨 MARKER PRESSURE: \1", category: .pressure)'),
        (r'print\("🖊️ DOUGLAS-PEUCKER: ([^"]+)"\)', r'Log.debug("🖊️ DOUGLAS-PEUCKER: \1", category: .pressure)'),
        
        # Stroke fill panel specific
        (r'print\("🎨 Set default stroke miter limit: ([^"]+)"\)', r'Log.info("🎨 Set default stroke miter limit: \1", category: .general)'),
        
        # Corner radius toolbar specific
        (r'print\("🔄 Updated corner ([^"]+)"\)', r'Log.debug("🔄 Updated corner \1", category: .shapes)'),
        
        # Drawing canvas specific patterns
        (r'print\("🎯 Testing INCOMING handle at ([^"]+)"\)', r'Log.debug("🎯 Testing INCOMING handle at \1", category: .general)'),
        (r'print\("🎯 Testing OUTGOING handle at ([^"]+)"\)', r'Log.debug("🎯 Testing OUTGOING handle at \1", category: .general)'),
        (r'print\("   Reference canvas offset: ([^"]+)"\)', r'Log.debug("   Reference canvas offset: \1", category: .general)'),
        (r'print\("   Reference cursor location: ([^"]+)"\)', r'Log.debug("   Reference cursor location: \1", category: .general)'),
        (r'print\("✋ HAND TOOL: Perfect sync maintained - delta: ([^"]+)"\)', r'Log.debug("✋ HAND TOOL: Perfect sync maintained - delta: \1", category: .general)'),
        (r'print\("🔧 GPU CALC: ([^"]+)"\)', r'Log.debug("🔧 GPU CALC: \1", category: .performance)'),
        (r'print\("🔧 CPU CALC: ([^"]+)"\)', r'Log.debug("🔧 CPU CALC: \1", category: .performance)'),
        (r'print\("📝 TEXT BOX CREATED: User-drawn size ([^"]+)"\)', r'Log.debug("📝 TEXT BOX CREATED: User-drawn size \1", category: .shapes)'),
        (r'print\("✅ RESIZE HANDLE HIT: ([^"]+)"\)', r'Log.debug("✅ RESIZE HANDLE HIT: \1", category: .shapes)'),
        (r'print\("🎯 UNIFIED: Drag ended - handling as completed drag operation ([^"]+)"\)', r'Log.debug("🎯 UNIFIED: Drag ended - handling as completed drag operation \1", category: .general)'),
        (r'print\("🎯 UNIFIED SELECTION DRAG: Started at cursor position ([^"]+)"\)', r'Log.debug("🎯 UNIFIED SELECTION DRAG: Started at cursor position \1", category: .general)'),
        (r'print\("✋ UNIFIED: Hand tool completed - final position: ([^"]+)"\)', r'Log.debug("✋ UNIFIED: Hand tool completed - final position: \1", category: .general)'),
        
        # Coordinate system specific
        (r'print\("   Document Aspect Ratio: ([^"]+)"\)', r'Log.debug("   Document Aspect Ratio: \1", category: .general)'),
        (r'print\("   View Size: ([^"]+)"\)', r'Log.debug("   View Size: \1", category: .general)'),
        (r'print\("   View Aspect Ratio: ([^"]+)"\)', r'Log.debug("   View Aspect Ratio: \1", category: .general)'),
        (r'print\("   Available Space: ([^"]+)"\)', r'Log.debug("   Available Space: \1", category: .general)'),
        (r'print\("   Scale X: ([^"]+)"\)', r'Log.debug("   Scale X: \1", category: .general)'),
        (r'print\("   Scale Y: ([^"]+)"\)', r'Log.debug("   Scale Y: \1", category: .general)'),
        (r'print\("   Uniform Scale: ([^"]+)"\)', r'Log.debug("   Uniform Scale: \1", category: .general)'),
        (r'print\("   Final Zoom: ([^"]+)"\)', r'Log.debug("   Final Zoom: \1", category: .general)'),
        (r'print\("   Visible Center: ([^"]+)"\)', r'Log.debug("   Visible Center: \1", category: .general)'),
        (r'print\("   Canvas Offset: ([^"]+)"\)', r'Log.debug("   Canvas Offset: \1", category: .general)'),
        (r'print\("   Fit Zoom: ([^"]+)"\)', r'Log.debug("   Fit Zoom: \1", category: .general)'),
        (r'print\("   Available space: ([^"]+)"\)', r'Log.debug("   Available space: \1", category: .general)'),
        (r'print\("   Visible center \(ruler-aware\): ([^"]+)"\)', r'Log.debug("   Visible center (ruler-aware): \1", category: .general)'),
        
        # Layer view specific patterns
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
        (r'print\("   📐 Using ORIGINAL bounds: ([^"]+)"\)', r'Log.debug("   📐 Using ORIGINAL bounds: \1", category: .shapes)'),
        (r'print\("      Anchor point: ([^"]+)"\)', r'Log.debug("      Anchor point: \1", category: .shapes)'),
        (r'print\("      Rotation angle: ([^"]+)"\)', r'Log.debug("      Rotation angle: \1", category: .shapes)'),
        (r'print\("   📊 Rotation preview updated: ([^"]+)"\)', r'Log.debug("   📊 Rotation preview updated: \1", category: .shapes)'),
        (r'print\("   📊 Preview transform: ([^"]+)"\)', r'Log.debug("   📊 Preview transform: \1", category: .shapes)'),
        
        # VectorDocument specific
        (r'print\("🔄 Unit changed to ([^"]+)"\)', r'Log.info("🔄 Unit changed to \1", category: .general)'),
        (r'print\("=" \+ String\(repeating: "=", count: 50\)\)', r'Log.debug("=" + String(repeating: "=", count: 50), category: .general)'),
        
        # FileOperations specific
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
        (r'print\("🎯 AUTO-CENTERED RADIAL: ([^"]+)"\)', r'Log.debug("🎯 AUTO-CENTERED RADIAL: \1", category: .fileOperations)'),
        (r'print\("   Original: ([^"]+)"\)', r'Log.debug("   Original: \1", category: .fileOperations)'),
        (r'print\("   - Center: ([^"]+)"\)', r'Log.debug("   - Center: \1", category: .fileOperations)'),
        (r'print\("   Document size: ([^"]+)"\)', r'Log.debug("   Document size: \1", category: .fileOperations)'),
        (r'print\("   Focal: ([^"]+)"\)', r'Log.debug("   Focal: \1", category: .fileOperations)'),
        
        # PathOperations specific
        (r'print\("=" \+ String\(repeating: "=", count: 40\)\)', r'Log.debug("=" + String(repeating: "=", count: 40), category: .general)'),
        
        # PasteboardDiagnostics specific (these are debug/test outputs, keep as debug)
        (r'print\("=" \* 50\)', r'Log.debug("=" * 50, category: .general)'),
        (r'print\("=" \* 40\)', r'Log.debug("=" * 40, category: .general)'),
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
    replace_remaining_prints()
    print("Remaining print statement replacement completed!")
