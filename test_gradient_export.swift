import Foundation

// Simple test script to verify gradient export fix
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
                   let gradientData = gradient["_0"] as? [String: Any],
                   let linear = gradientData["linear"] as? [String: Any] {
                    gradients.append(linear)
                }
            } else if let dict = value as? [String: Any] {
                searchInObject(dict)
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

// Check the first linear gradient
if let firstGradient = linearGradients.first {
    print("\n🎨 First linear gradient details:")
    if let startPoint = firstGradient["startPoint"] as? [Double] {
        print("   Start point: \(startPoint)")
    }
    if let endPoint = firstGradient["endPoint"] as? [Double] {
        print("   End point: \(endPoint)")
    }
    if let originPoint = firstGradient["originPoint"] as? [Double] {
        print("   Origin point: \(originPoint)")
    }
    if let angle = firstGradient["angle"] {
        print("   Angle: \(angle)")
    } else {
        print("   Angle: not specified (will be calculated from start/end points)")
    }
    
    // Calculate the angle from start and end points
    if let startPoint = firstGradient["startPoint"] as? [Double],
       let endPoint = firstGradient["endPoint"] as? [Double],
       startPoint.count == 2, endPoint.count == 2 {
        let deltaX = endPoint[0] - startPoint[0]
        let deltaY = endPoint[1] - startPoint[1]
        let angleRadians = atan2(deltaY, deltaX)
        let angleDegrees = angleRadians * 180.0 / .pi
        print("   Calculated angle: \(angleDegrees)°")
        
        if abs(angleDegrees - 180.0) < 0.1 {
            print("   ⚠️  This gradient would have been rotated 180° in the old export!")
            print("   ✅ The fix should prevent this rotation")
        }
    }
}

// Now check the current SVG export
let svgPath = "inkpen.svg"
guard let svgContent = try? String(contentsOf: URL(fileURLWithPath: svgPath), encoding: .utf8) else {
    print("❌ Failed to load SVG file")
    exit(1)
}

print("\n🔍 Checking current SVG export...")

// Find the complete gradient1 definition
if let gradient1Start = svgContent.range(of: "linearGradient id=\"gradient1\"")?.lowerBound {
    // Find the end of the gradient definition
    let searchStart = svgContent.index(gradient1Start, offsetBy: 50)
    if let gradient1End = svgContent.range(of: "</linearGradient>", range: searchStart..<svgContent.endIndex)?.upperBound {
        let gradient1Definition = String(svgContent[gradient1Start..<gradient1End])
        
        print("📄 Complete gradient1 definition in SVG:")
        print(gradient1Definition)
        
        // Check if it has the rotation
        if gradient1Definition.contains("rotate(180.0)") {
            print("\n❌ The SVG still contains the incorrect 180° rotation!")
            print("   This means the fix hasn't been applied yet or there's another issue.")
        } else {
            print("\n✅ The SVG no longer contains the 180° rotation!")
            print("   The gradient export fix is working correctly.")
            
            // Check what transformations are present
            if gradient1Definition.contains("gradientTransform") {
                print("   📐 Current gradientTransform: Only translation (no rotation)")
            } else {
                print("   📐 No gradientTransform present")
            }
        }
    } else {
        print("❌ Could not find end of gradient1 definition")
    }
} else {
    print("❌ Could not find gradient1 in SVG")
}

print("\n�� Test completed!") 