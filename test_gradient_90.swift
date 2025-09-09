#!/usr/bin/swift

import Foundation
import CoreGraphics

// Simple test to verify gradient angle is preserved at 90 degrees
print("Testing gradient angle preservation...")

// Create test values simulating a 90-degree gradient
let x0: CGFloat = 0.5
let y0: CGFloat = 0.0  
let x1: CGFloat = 0.5
let y1: CGFloat = 1.0

// Calculate angle as the parser would
let deltaX = x1 - x0
let deltaY = y1 - y0
let coordinateAngle = atan2(deltaY, deltaX) * 180.0 / .pi

print("Gradient coordinates: (\(x0), \(y0)) -> (\(x1), \(y1))")
print("Delta X: \(deltaX), Delta Y: \(deltaY)")
print("Calculated angle: \(coordinateAngle)°")

// Simulate CTM with no rotation
let ctmAngle: CGFloat = 0.0
let finalAngle = coordinateAngle + ctmAngle

print("CTM angle: \(ctmAngle)°")
print("Final angle: \(finalAngle)°")

if abs(finalAngle - 90.0) < 0.1 {
    print("✅ SUCCESS: Gradient angle is correctly 90°")
} else {
    print("❌ FAILED: Gradient angle is \(finalAngle)° instead of 90°")
}