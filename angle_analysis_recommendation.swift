import Foundation

// Analysis: Should we include explicit angle data in JSON?
print("🔍 Analyzing whether explicit angle data should be included in JSON...")

// Load the JSON file to examine current gradient structure
let jsonPath = "Inkpen2.logos inkpen.io.json"

guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
    print("❌ Failed to load JSON file")
    exit(1)
}

print("✅ Loaded JSON file successfully")

// Find linear gradients and analyze their angle calculations
func findLinearGradients(in json: [String: Any]) -> [[String: Any]] {
    var gradients: [[String: Any]] = []
    
    func searchInObject(_ obj: [String: Any]) {
        for (key, value) in obj {
            if key == "gradient" {
                if let gradient = value as? [String: Any] {
                    if let nested = gradient["_0"] as? [String: Any],
                       let linear = nested["linear"] as? [String: Any] {
                        if let linearNested = linear["_0"] as? [String: Any] {
                            gradients.append(linearNested)
                        } else {
                            gradients.append(linear)
                        }
                    }
                }
            } else if let nestedObj = value as? [String: Any] {
                searchInObject(nestedObj)
            } else if let array = value as? [[String: Any]] {
                for item in array {
                    searchInObject(item)
                }
            }
        }
    }
    
    searchInObject(json)
    return gradients
}

let linearGradients = findLinearGradients(in: json)
print("📊 Found \(linearGradients.count) linear gradients to analyze")

print("\n🔍 ANGLE ANALYSIS:")

var angleCalculations: [(start: [Double], end: [Double], calculatedAngle: Double)] = []

for (index, gradient) in linearGradients.enumerated() {
    print("   Gradient \(index + 1):")
    
    if let startPoint = gradient["startPoint"] as? [Double],
       let endPoint = gradient["endPoint"] as? [Double] {
        
        // Calculate angle from coordinates
        let deltaX = endPoint[0] - startPoint[0]
        let deltaY = endPoint[1] - startPoint[1]
        let angle = atan2(deltaY, deltaX) * 180.0 / .pi
        
        angleCalculations.append((start: startPoint, end: endPoint, calculatedAngle: angle))
        
        print("     Start: (\(startPoint[0]), \(startPoint[1]))")
        print("     End: (\(endPoint[0]), \(endPoint[1]))")
        print("     Calculated angle: \(angle)°")
        
        // Check for explicit angle property
        if let explicitAngle = gradient["angle"] as? Double {
            print("     ✅ Has explicit angle: \(explicitAngle)°")
            let difference = abs(angle - explicitAngle)
            if difference > 0.1 {
                print("     ⚠️  Angle difference: \(difference)° (potential inconsistency)")
            } else {
                print("     ✅ Angles match (difference: \(difference)°)")
            }
        } else {
            print("     ❌ No explicit angle property")
        }
    }
}

print("\n📋 PROS AND CONS ANALYSIS:")

print("\n✅ PROS of including explicit angle:")
print("   1. Self-documenting: Angle is immediately visible in JSON")
print("   2. Performance: No need to calculate angle from coordinates")
print("   3. Validation: Can verify angle matches coordinate calculation")
print("   4. Debugging: Easier to spot angle-related issues")
print("   5. API clarity: Explicit intent rather than derived value")

print("\n❌ CONS of including explicit angle:")
print("   1. Redundancy: Angle can always be calculated from start/end points")
print("   2. Data consistency: Risk of angle not matching coordinates")
print("   3. File size: Slightly larger JSON files")
print("   4. Maintenance: Need to keep angle in sync with coordinates")
print("   5. Standard practice: Most gradient formats use start/end points only")

print("\n🔍 INDUSTRY STANDARDS ANALYSIS:")

print("\n📊 How other formats handle linear gradients:")
print("   - SVG: Uses x1,y1,x2,y2 coordinates (no explicit angle)")
print("   - CSS: Uses angle or direction keywords (angle is primary)")
print("   - Figma: Uses start/end points (no explicit angle)")
print("   - Sketch: Uses angle and coordinates")

print("\n🎯 RECOMMENDATION ANALYSIS:")

// Analyze the current gradients
let uniqueAngles = Set(angleCalculations.map { $0.calculatedAngle })
let hasComplexAngles = angleCalculations.contains { abs($0.calculatedAngle) > 90 }

print("\n📊 Current gradient characteristics:")
print("   - Number of gradients: \(linearGradients.count)")
print("   - Unique angles: \(uniqueAngles.count)")
print("   - Has angles > 90°: \(hasComplexAngles)")

if hasComplexAngles {
    print("   - ⚠️  Contains angles that might be confusing (180° gradients)")
}

print("\n💡 RECOMMENDATIONS:")

print("\n🎯 OPTION 1: Keep current approach (start/end points only)")
print("   ✅ Pros: Standard, consistent, no redundancy")
print("   ✅ Best for: Most use cases, when coordinates are primary")
print("   ✅ Use when: Angle is always derived from coordinates")

print("\n🎯 OPTION 2: Add explicit angle property")
print("   ✅ Pros: Self-documenting, performance, validation")
print("   ✅ Best for: Complex applications, when angle is primary")
print("   ✅ Use when: Angle might be set independently of coordinates")

print("\n🎯 OPTION 3: Hybrid approach (both angle and coordinates)")
print("   ✅ Pros: Maximum flexibility, validation possible")
print("   ✅ Cons: Most complex, largest file size")
print("   ✅ Best for: Professional design applications")

print("\n🏆 FINAL RECOMMENDATION:")
print("   For Inkpen, I recommend OPTION 1 (start/end points only) because:")
print("   1. It's the SVG standard (which you're exporting to)")
print("   2. Eliminates data consistency issues")
print("   3. Keeps JSON clean and minimal")
print("   4. Angle is always derivable from coordinates")
print("   5. Matches current working implementation")

print("\n💡 If you want to add angle later:")
print("   - Make it optional (not required)")
print("   - Validate it matches coordinate calculation")
print("   - Use it for UI display but not for export")
print("   - Consider it a computed property rather than stored data")

print("\n📋 IMPLEMENTATION SUGGESTION:")
print("   - Keep current JSON structure (start/end points only)")
print("   - Add angle as a computed property in the app")
print("   - Use angle for UI display and user input")
print("   - Always export using start/end coordinates")
print("   - This gives you the best of both worlds") 