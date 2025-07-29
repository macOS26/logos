import Foundation

// Test script to verify gradient export fix
print("🧪 Testing gradient export fix...")

// Load the Inkpen JSON file
let jsonPath = "Inkpen.logos inkpen.io.json"
guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
    print("❌ Failed to load JSON file")
    exit(1)
}

print("✅ Loaded JSON file successfully")

// Look for linear gradients in the JSON
func findLinearGradients(in json: [String: Any]) -> [[String: Any]] {
    var gradients: [[String: Any]] = []
    
    func searchInObject(_ obj: [String: Any]) {
        for (key, value) in obj {
            if key == "gradient" {
                if let gradient = value as? [String: Any],
                   let linear = gradient["linear"] as? [String: Any] {
                    gradients.append(linear)
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
print("📊 Found \(linearGradients.count) linear gradients in JSON")

// Check the first linear gradient (gradient1)
if let firstGradient = linearGradients.first {
    print("\n🔍 Analyzing first linear gradient:")
    
    if let startPoint = firstGradient["startPoint"] as? [Double],
       let endPoint = firstGradient["endPoint"] as? [Double],
       let originPoint = firstGradient["originPoint"] as? [Double] {
        
        print("   Start Point: (\(startPoint[0]), \(startPoint[1]))")
        print("   End Point: (\(endPoint[0]), \(endPoint[1]))")
        print("   Origin Point: (\(originPoint[0]), \(originPoint[1]))")
        
        // Calculate the angle from start to end point
        let deltaX = endPoint[0] - startPoint[0]
        let deltaY = endPoint[1] - startPoint[1]
        let angle = atan2(deltaY, deltaX) * 180.0 / .pi
        print("   Calculated Angle: \(angle)°")
        
        // Check if this would have been rotated 180° in the old export
        if abs(angle) > 90 {
            print("   ⚠️  This gradient would have been rotated 180° in the old export!")
        }
    }
}

// Now check the current SVG file
print("\n📄 Checking current SVG file...")
let svgPath = "inkpen.svg"
guard let svgData = try? Data(contentsOf: URL(fileURLWithPath: svgPath)),
      let svgContent = String(data: svgData, encoding: .utf8) else {
    print("❌ Failed to load SVG file")
    exit(1)
}

// Look for gradient1 definition
if let gradient1Range = svgContent.range(of: "linearGradient id=\"gradient1\""),
   let gradient1EndRange = svgContent[gradient1Range.upperBound...].range(of: ">") {
    
    let gradient1Start = gradient1Range.lowerBound
    let gradient1End = gradient1EndRange.upperBound
    let gradient1Definition = String(svgContent[gradient1Start..<gradient1End])
    
    print("🔍 Found gradient1 definition:")
    print("   \(gradient1Definition)")
    
    // Check if it contains the problematic rotation
    if gradient1Definition.contains("rotate(180.0)") {
        print("❌ PROBLEM: gradient1 still contains rotate(180.0) transformation!")
        print("   This means the SVG file needs to be regenerated with the fixed code.")
    } else {
        print("✅ SUCCESS: gradient1 no longer contains rotate(180.0) transformation!")
    }
    
    // Check for the correct coordinates
    if gradient1Definition.contains("x1=\"0.821103515625\"") && 
       gradient1Definition.contains("x2=\"0.18118164062499997\"") {
        print("✅ SUCCESS: gradient1 has correct start/end coordinates!")
    } else {
        print("❌ PROBLEM: gradient1 coordinates don't match JSON data!")
    }
    
    // Check for origin point translation
    if gradient1Definition.contains("translate(0.00114257812499996 0.0)") {
        print("✅ SUCCESS: gradient1 has correct origin point translation!")
    } else {
        print("⚠️  WARNING: gradient1 origin point translation may be incorrect!")
    }
} else {
    print("❌ Could not find gradient1 definition in SVG")
}

print("\n📋 Summary:")
print("   - JSON file loaded successfully")
print("   - Found \(linearGradients.count) linear gradients")
print("   - SVG file contains old version with rotate(180.0)")
print("   - Need to regenerate SVG with fixed export code")

print("\n💡 Next steps:")
print("   1. Run the app and export the Inkpen document to SVG")
print("   2. The new SVG should not contain rotate(180.0) for linear gradients")
print("   3. The gradient direction should match the JSON start/end points") 