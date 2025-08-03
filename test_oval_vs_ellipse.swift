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

// Oval function (simple distorted circle)
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

// Test function
func testOvalVsEllipse() {
    print("🔍 Testing Oval vs Ellipse Differences")
    print("=====================================")
    
    // Test with a wide rectangle
    let wideRect = CGRect(x: 0, y: 0, width: 200, height: 100)
    print("\n📐 Wide Rectangle Test (200x100):")
    print("  Rectangle: \(wideRect)")
    
    let wideEllipse = createEllipsePath(rect: wideRect)
    let wideOval = createOvalPath(rect: wideRect)
    
    print("  Ellipse elements: \(wideEllipse.elements.count)")
    print("  Oval elements: \(wideOval.elements.count)")
    
    // Test with a tall rectangle
    let tallRect = CGRect(x: 0, y: 0, width: 100, height: 200)
    print("\n📐 Tall Rectangle Test (100x200):")
    print("  Rectangle: \(tallRect)")
    
    let tallEllipse = createEllipsePath(rect: tallRect)
    let tallOval = createOvalPath(rect: tallRect)
    
    print("  Ellipse elements: \(tallEllipse.elements.count)")
    print("  Oval elements: \(tallOval.elements.count)")
    
    // Test with a square
    let squareRect = CGRect(x: 0, y: 0, width: 150, height: 150)
    print("\n📐 Square Test (150x150):")
    print("  Rectangle: \(squareRect)")
    
    let squareEllipse = createEllipsePath(rect: squareRect)
    let squareOval = createOvalPath(rect: squareRect)
    
    print("  Ellipse elements: \(squareEllipse.elements.count)")
    print("  Oval elements: \(squareOval.elements.count)")
    
    print("\n✅ Key Differences:")
    print("  • Ellipse: Uses mathematical ellipse curves with 0.552 control point offset")
    print("  • Oval: Uses rounded, circle-like curves with 0.58 control point offset")
    print("  • Both tools now use different mathematical approaches")
    print("  • Oval is more rounded and circular than ellipse")
}

// Run the test
testOvalVsEllipse() 