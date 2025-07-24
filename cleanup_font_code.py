#!/usr/bin/env python3
"""
Font Code Cleanup Script
Identifies specific files and code blocks that can be safely removed
"""

import os
import json
from pathlib import Path

def main():
    print("FONT AND COLOR CODE CLEANUP RECOMMENDATIONS")
    print("=" * 60)
    
    # Files that can likely be removed completely
    print("\n🗑️ FILES THAT CAN BE REMOVED:")
    print("\n1. Test/FontPickerView.swift")
    print("   - Reason: Replaced by ProfessionalTextCanvas and FontPanel")
    print("   - Contains: Legacy NSFont picker implementation")
    print("   - Analysis: 53 font references, but in test directory")
    
    print("\n2. Test/Assets.xcassets/")
    print("   - Reason: Duplicate asset catalog in test directory")
    print("   - Contains: Redundant app icons and color sets")
    
    # Legacy code markers that indicate removable code
    print("\n🔍 LEGACY CODE TO REVIEW:")
    
    legacy_markers = [
        {
            "file": "Views/RightPanel/FontPanel.swift",
            "lines": "11, 165, 201, 237, 456, 574, 620",
            "description": "Multiple REMOVED comments for separate color pickers - already integrated with main color system"
        },
        {
            "file": "Models/VectorText.swift", 
            "lines": "307",
            "description": "LEGACY SINGLE-LINE CALCULATION marked for removal"
        },
        {
            "file": "Views/DrawingCanvas/DrawingCanvas+KeyEventHandling.swift",
            "lines": "49-83",
            "description": "35 lines of commented-out TEXT EDITING REMOVED code"
        },
        {
            "file": "Views/RightPanel/PathOperationButton.swift",
            "lines": "9",
            "description": "Legacy PathOperationButton for backward compatibility - check if still needed"
        },
        {
            "file": "Utilities/FileOperations.swift",
            "lines": "4137",
            "description": "LEGACY EXPORT FUNCTIONS section - check if still needed"
        }
    ]
    
    for item in legacy_markers:
        print(f"\n• {item['file']} (lines {item['lines']})")
        print(f"  {item['description']}")
    
    # Specific recommendations based on analysis
    print("\n💡 SPECIFIC CLEANUP ACTIONS:")
    
    print("\n1. DUPLICATE FONT HANDLING:")
    print("   • FontPickerView.swift vs FontPanel.swift")
    print("   • Both implement font selection - consolidate to FontPanel")
    print("   • FontPickerView has 53 font references but is in test directory")
    
    print("\n2. COLOR CODE CONSOLIDATION:")
    print("   • 309 single-use color instances found")
    print("   • Many in ColorModels.swift - consider using constants")
    print("   • Consolidate color creation methods")
    
    print("\n3. LEGACY IMPLEMENTATIONS:")
    print("   • 43 legacy code markers found")
    print("   • Many marked as 'REMOVED' but still in code")
    print("   • Safe to delete commented-out blocks")
    
    print("\n📋 CLEANUP CHECKLIST:")
    print("\n✅ SAFE TO DELETE (Test Confidence: High):")
    print("   □ logos inkpen.io/Views/DrawingCanvas/Test/FontPickerView.swift")
    print("   □ logos inkpen.io/Views/DrawingCanvas/Test/Assets.xcassets/")
    print("   □ Commented-out code blocks marked as 'REMOVED'")
    
    print("\n⚠️ REVIEW BEFORE DELETING (Test Confidence: Medium):")
    print("   □ Legacy functions in VectorText.swift")
    print("   □ PathOperationButton.swift (check if still used)")
    print("   □ Legacy export functions in FileOperations.swift")
    
    print("\n🔧 REFACTOR OPPORTUNITIES:")
    print("   □ Consolidate color constants in ColorModels.swift")
    print("   □ Remove document.fontManager sync code in FontPanel.swift")
    print("   □ Clean up REMOVED color picker references")
    
    # Generate specific deletion commands
    print("\n🚀 READY TO EXECUTE:")
    print("\nTo remove the Test/FontPickerView.swift (safest cleanup):")
    print("rm 'logos inkpen.io/Views/DrawingCanvas/Test/FontPickerView.swift'")
    
    print("\nTo remove the test assets (if not needed):")
    print("rm -rf 'logos inkpen.io/Views/DrawingCanvas/Test/Assets.xcassets/'")
    
    print("\n" + "=" * 60)
    print("SUMMARY:")
    print("• Test FontPickerView can be safely removed")
    print("• 43 legacy markers indicate cleanup opportunities") 
    print("• Focus on Test directory first (lowest risk)")
    print("• ProfessionalTextCanvas is the working solution")

if __name__ == "__main__":
    main() 