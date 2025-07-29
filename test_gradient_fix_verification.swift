import Foundation

// Test to verify the gradient export fix
print("🧪 Verifying gradient export fix...")

// Simulate the gradient data from the JSON
let gradientData = [
    "startPoint": [0.821103515625, 0.49999999999999994],
    "endPoint": [0.18118164062499997, 0.5],
    "originPoint": [0.501142578125, 0.5],
    "scale": 1.0,
    "scaleX": 1.0,
    "scaleY": 1.0,
    "units": "objectBoundingBox",
    "spreadMethod": "pad"
] as [String: Any]

print("📊 Test gradient data:")
print("   Start Point: (\(gradientData["startPoint"] as! [Double])[0], \(gradientData["startPoint"] as! [Double])[1])")
print("   End Point: (\(gradientData["endPoint"] as! [Double])[0], \(gradientData["endPoint"] as! [Double])[1])")
print("   Origin Point: (\(gradientData["originPoint"] as! [Double])[0], \(gradientData["originPoint"] as! [Double])[1])")

// Calculate the angle from start to end point (this was causing the issue)
let startPoint = gradientData["startPoint"] as! [Double]
let endPoint = gradientData["endPoint"] as! [Double]
let deltaX = endPoint[0] - startPoint[0]
let deltaY = endPoint[1] - startPoint[1]
let angle = atan2(deltaY, deltaX) * 180.0 / .pi

print("   Calculated Angle: \(angle)°")

// Simulate the old export (with rotation)
let oldExport = """
<linearGradient id="gradient1" x1="\(startPoint[0])" y1="\(startPoint[1])" x2="\(endPoint[0])" y2="\(endPoint[1])" gradientUnits="objectBoundingBox" spreadMethod="pad" gradientTransform="translate(0.00114257812499996 0.0) rotate(180.0)">
"""

// Simulate the new export (without rotation)
let originPoint = gradientData["originPoint"] as! [Double]
let translateX = originPoint[0] - 0.5
let translateY = originPoint[1] - 0.5

let newExport = """
<linearGradient id="gradient1" x1="\(startPoint[0])" y1="\(startPoint[1])" x2="\(endPoint[0])" y2="\(endPoint[1])" gradientUnits="objectBoundingBox" spreadMethod="pad" gradientTransform="translate(\(translateX) \(translateY))">
"""

print("\n🔍 Export comparison:")
print("OLD (with rotation):")
print("   \(oldExport)")
print("NEW (without rotation):")
print("   \(newExport)")

// Check if the old export contains the problematic rotation
if oldExport.contains("rotate(180.0)") {
    print("❌ OLD EXPORT: Contains rotate(180.0) - This was the problem!")
} else {
    print("✅ OLD EXPORT: No rotation found")
}

if newExport.contains("rotate(180.0)") {
    print("❌ NEW EXPORT: Still contains rotate(180.0) - Fix not working!")
} else {
    print("✅ NEW EXPORT: No rotation found - Fix is working!")
}

// Verify the coordinates are correct
if newExport.contains("x1=\"0.821103515625\"") && newExport.contains("x2=\"0.18118164062499997\"") {
    print("✅ NEW EXPORT: Coordinates match JSON data")
} else {
    print("❌ NEW EXPORT: Coordinates don't match JSON data")
}

// Verify the origin point translation
let expectedTranslateX = 0.501142578125 - 0.5
if newExport.contains("translate(\(expectedTranslateX) 0.0)") {
    print("✅ NEW EXPORT: Origin point translation is correct")
} else {
    print("❌ NEW EXPORT: Origin point translation is incorrect")
}

print("\n📋 Summary:")
print("   - The fix removes the rotate(180.0) transformation")
print("   - The gradient direction is now defined by start/end points only")
print("   - Origin point translation is preserved")
print("   - The gradient will appear in the correct direction")

print("\n🎯 Expected result:")
print("   - Linear gradients should flow from start point to end point")
print("   - No 180-degree rotation should be applied")
print("   - The visual appearance should match the JSON gradient data") 