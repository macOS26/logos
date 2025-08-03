#!/usr/bin/env swift

import Foundation
import CoreGraphics

// Simplified versions of the shape creation functions for testing
struct VectorPoint {
    let x: Double
    let y: Double
    
    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

enum PathElement {
    case move(to: VectorPoint)
    case curve(to: VectorPoint, control1: VectorPoint, control2: VectorPoint)
    case close
}

struct VectorPath {
    let elements: [PathElement]
    let isClosed: Bool
    
    init(elements: [PathElement], isClosed: Bool) {
        self.elements = elements
        self.isClosed = isClosed
    }
}

// Ellipse function (mathematical ellipse)
func createEllipsePath(rect: CGRect) -> VectorPath {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radiusX = rect.width / 2
    let radiusY = rect.height / 2
    let controlPointOffsetX = radiusX * 0.552
    let controlPointOffsetY = radiusY * 0.552
    
    return VectorPath(elements: [
        .move(to: VectorPoint(center.x + radiusX, center.y)),
        .curve(to: VectorPoint(center.x, center.y + radiusY),
               control1: VectorPoint(center.x + radiusX, center.y + controlPointOffsetY),
               control2: VectorPoint(center.x + controlPointOffsetX, center.y + radiusY)),
        .curve(to: VectorPoint(center.x - radiusX, center.y),
               control1: VectorPoint(center.x - controlPointOffsetX, center.y + radiusY),
               control2: VectorPoint(center.x - radiusX, center.y + controlPointOffsetY)),
        .curve(to: VectorPoint(center.x, center.y - radiusY),
               control1: VectorPoint(center.x - radiusX, center.y - controlPointOffsetY),
               control2: VectorPoint(center.x - controlPointOffsetX, center.y - radiusY)),
        .curve(to: VectorPoint(center.x + radiusX, center.y),
               control1: VectorPoint(center.x + controlPointOffsetX, center.y - radiusY),
               control2: VectorPoint(center.x + radiusX, center.y - controlPointOffsetY)),
        .close
    ], isClosed: true)
}

// Oval function (rounded circle-like)
func createOvalPath(rect: CGRect) -> VectorPath {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radiusX = rect.width / 2
    let radiusY = rect.height / 2
    
    // Use control points that create a more rounded, circle-like appearance
    let controlPointOffsetX = radiusX * 0.58  // More rounded than ellipse's 0.552
    let controlPointOffsetY = radiusY * 0.58
    
    return VectorPath(elements: [
        .move(to: VectorPoint(center.x + radiusX, center.y)),
        .curve(to: VectorPoint(center.x, center.y + radiusY),
               control1: VectorPoint(center.x + radiusX, center.y + controlPointOffsetY),
               control2: VectorPoint(center.x + controlPointOffsetX, center.y + radiusY)),
        .curve(to: VectorPoint(center.x - radiusX, center.y),
               control1: VectorPoint(center.x - controlPointOffsetX, center.y + radiusY),
               control2: VectorPoint(center.x - radiusX, center.y + controlPointOffsetY)),
        .curve(to: VectorPoint(center.x, center.y - radiusY),
               control1: VectorPoint(center.x - radiusX, center.y - controlPointOffsetY),
               control2: VectorPoint(center.x - controlPointOffsetX, center.y - radiusY)),
        .curve(to: VectorPoint(center.x + radiusX, center.y),
               control1: VectorPoint(center.x + controlPointOffsetX, center.y - radiusY),
               control2: VectorPoint(center.x + radiusX, center.y - controlPointOffsetY)),
        .close
    ], isClosed: true)
}

// Egg function (asymmetric egg shape)
func createEggPath(rect: CGRect) -> VectorPath {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radiusX = rect.width / 2
    let radiusY = rect.height / 2
    
    // Egg shape parameters: wider at bottom, narrower at top
    let eggFactor = 0.3  // Controls the egg asymmetry
    let topRadiusX = radiusX * (1.0 - eggFactor)
    let topRadiusY = radiusY * (1.0 - eggFactor)
    let bottomRadiusX = radiusX * (1.0 + eggFactor * 0.5)
    let bottomRadiusY = radiusY * (1.0 + eggFactor * 0.5)
    
    // Create egg shape using modified ellipse curves
    // Top half (narrower)
    let topControlOffsetX = topRadiusX * 0.552
    let topControlOffsetY = topRadiusY * 0.552
    
    // Bottom half (wider)
    let bottomControlOffsetX = bottomRadiusX * 0.552
    let bottomControlOffsetY = bottomRadiusY * 0.552
    
    return VectorPath(elements: [
        // Start at top point
        .move(to: VectorPoint(center.x, center.y - topRadiusY)),
        
        // Top right curve (narrower)
        .curve(to: VectorPoint(center.x + topRadiusX, center.y),
               control1: VectorPoint(center.x + topControlOffsetX, center.y - topRadiusY),
               control2: VectorPoint(center.x + topRadiusX, center.y - topControlOffsetY)),
        
        // Bottom right curve (wider)
        .curve(to: VectorPoint(center.x, center.y + bottomRadiusY),
               control1: VectorPoint(center.x + bottomRadiusX, center.y + bottomControlOffsetY),
               control2: VectorPoint(center.x + bottomControlOffsetX, center.y + bottomRadiusY)),
        
        // Bottom left curve (wider)
        .curve(to: VectorPoint(center.x - bottomRadiusX, center.y),
               control1: VectorPoint(center.x - bottomControlOffsetX, center.y + bottomRadiusY),
               control2: VectorPoint(center.x - bottomRadiusX, center.y + bottomControlOffsetY)),
        
        // Top left curve (narrower)
        .curve(to: VectorPoint(center.x, center.y - topRadiusY),
               control1: VectorPoint(center.x - topRadiusX, center.y - topControlOffsetY),
               control2: VectorPoint(center.x - topControlOffsetX, center.y - topRadiusY)),
        
        .close
    ], isClosed: true)
}

// Test function
func testEggShape() {
    print("🥚 Testing Egg Shape Implementation")
    print("==================================")
    
    // Test with a tall rectangle (good for egg shape)
    let tallRect = CGRect(x: 0, y: 0, width: 100, height: 150)
    print("\n📐 Tall Rectangle Test (100x150) - Good for egg shape:")
    print("  Rectangle: \(tallRect)")
    
    let tallEllipse = createEllipsePath(rect: tallRect)
    let tallOval = createOvalPath(rect: tallRect)
    let tallEgg = createEggPath(rect: tallRect)
    
    print("  Ellipse elements: \(tallEllipse.elements.count)")
    print("  Oval elements: \(tallOval.elements.count)")
    print("  Egg elements: \(tallEgg.elements.count)")
    
    // Test with a wide rectangle
    let wideRect = CGRect(x: 0, y: 0, width: 150, height: 100)
    print("\n📐 Wide Rectangle Test (150x100):")
    print("  Rectangle: \(wideRect)")
    
    let wideEllipse = createEllipsePath(rect: wideRect)
    let wideOval = createOvalPath(rect: wideRect)
    let wideEgg = createEggPath(rect: wideRect)
    
    print("  Ellipse elements: \(wideEllipse.elements.count)")
    print("  Oval elements: \(wideOval.elements.count)")
    print("  Egg elements: \(wideEgg.elements.count)")
    
    // Test with a square
    let squareRect = CGRect(x: 0, y: 0, width: 120, height: 120)
    print("\n📐 Square Test (120x120):")
    print("  Rectangle: \(squareRect)")
    
    let squareEllipse = createEllipsePath(rect: squareRect)
    let squareOval = createOvalPath(rect: squareRect)
    let squareEgg = createEggPath(rect: squareRect)
    
    print("  Ellipse elements: \(squareEllipse.elements.count)")
    print("  Oval elements: \(squareOval.elements.count)")
    print("  Egg elements: \(squareEgg.elements.count)")
    
    print("\n✅ Key Differences:")
    print("  • Ellipse: Mathematical precision with 0.552 control points")
    print("  • Oval: Rounded appearance with 0.58 control points")
    print("  • Egg: Asymmetric shape with narrower top and wider bottom")
    print("  • Egg uses different radii for top (70%) and bottom (115%)")
    print("  • All shapes use the same 4-curve Bézier structure")
}

// Run the test
testEggShape() 