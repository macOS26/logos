import Foundation

// Test script to import Firefox SVG and verify coordinate conversion
// This simulates what happens when the Firefox SVG is imported

let firefoxSVGPath = "logos inkpen.io/firefox.svg"

print("🔥 TESTING FIREFOX SVG COORDINATE CONVERSION")
print("=============================================")

// Test the coordinate conversion logic directly
func testCoordinateConversion() {
    let viewBoxWidth = 1024.0
    let viewBoxHeight = 1024.0
    
    // Test coordinates from Firefox SVG
    let testCoordinates = [
        ("radial-gradient cx", -7159.91),
        ("radial-gradient cy", -2133.76),
        ("radial-gradient r", 823.26),
        ("radial-gradient-2 cx", -7465.58),
        ("radial-gradient-2 cy", -2469.99),
        ("radial-gradient-2 r", 823.26),
        ("radial-gradient-3 cx", -7363.69),
        ("radial-gradient-3 cy", -1950.36),
        ("radial-gradient-3 r", 596.36)
    ]
    
    print("\n📊 COORDINATE CONVERSION RESULTS:")
    print("=================================")
    
    for (name, value) in testCoordinates {
        let isRadius = name.contains(" r")
        let isXCoordinate = name.contains(" cx")
        
        let boundingBoxOrigin = 0.0
        let boundingBoxDimension = isXCoordinate ? viewBoxWidth : viewBoxHeight
        
        let normalizedValue = (value - boundingBoxOrigin) / boundingBoxDimension
        
        let finalValue: Double
        if normalizedValue < -1.0 || normalizedValue > 2.0 {
            finalValue = 0.5
        } else if normalizedValue < 0.0 {
            finalValue = 0.5 + (normalizedValue * 0.5)
        } else if normalizedValue > 1.0 {
            finalValue = 0.5 + ((normalizedValue - 1.0) * 0.5)
        } else {
            finalValue = normalizedValue
        }
        
        let clampedValue = max(0.0, min(1.0, finalValue))
        
        print("\(name): \(value) → \(String(format: "%.3f", normalizedValue)) → \(String(format: "%.3f", finalValue)) → \(String(format: "%.3f", clampedValue))")
    }
}

testCoordinateConversion()

print("\n✅ COORDINATE CONVERSION TEST COMPLETE")
print("Import the Firefox SVG file in the running application to see the actual results!") 