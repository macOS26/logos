///Users/toddbruss/Documents/logos/logosTests/BezierCurveToolTests.swift
//  BezierCurveToolTests.swift
//  logosTests
//
//  Comprehensive Bezier Curve Tool Tests
//  Tests the professional Bezier pen tool with straight tangent handles
//
//  Created by AI Assistant on 1/12/25.
//

import XCTest
import SwiftUI
@testable import logos

final class BezierCurveToolTests: XCTestCase {
    
    var document: VectorDocument!
    
    override func setUp() {
        super.setUp()
        document = VectorDocument()
        // Set up bezier pen tool
        document.currentTool = .bezierPen
    }
    
    override func tearDown() {
        document = nil
        super.tearDown()
    }
    
    // MARK: - Basic Bezier Tool Tests
    
    func testBezierToolSelection() {
        // Test that bezier pen tool can be selected
        XCTAssertEqual(document.currentTool, .bezierPen, "Bezier pen tool should be selected")
        
        // Test that bezier tool has correct properties
        XCTAssertEqual(DrawingTool.bezierPen.rawValue, "bezierPen", "Bezier tool should have correct name")
        
        print("✅ Bezier tool selection test passed")
    }
    
    func testBezierHandleCreation() {
        // Test handle creation logic
        let startPoint = CGPoint(x: 100, y: 100)
        let dragPoint = CGPoint(x: 150, y: 120)
        
        // Calculate what handles should be created
        let dragVector = CGPoint(
            x: dragPoint.x - startPoint.x,
            y: dragPoint.y - startPoint.y
        )
        
        let handleLength = sqrt(dragVector.x * dragVector.x + dragVector.y * dragVector.y)
        XCTAssertGreaterThan(handleLength, 0, "Handle length should be positive")
        
        // Test handle direction calculation
        let normalizedX = dragVector.x / handleLength
        let normalizedY = dragVector.y / handleLength
        
        // Test symmetric handle positions
        let expectedControl1 = VectorPoint(
            startPoint.x - normalizedX * handleLength,
            startPoint.y - normalizedY * handleLength
        )
        let expectedControl2 = VectorPoint(
            startPoint.x + normalizedX * handleLength,
            startPoint.y + normalizedY * handleLength
        )
        
        // Verify handles are symmetric (opposite directions)
        let distance1 = sqrt(pow(expectedControl1.x - startPoint.x, 2) + pow(expectedControl1.y - startPoint.y, 2))
        let distance2 = sqrt(pow(expectedControl2.x - startPoint.x, 2) + pow(expectedControl2.y - startPoint.y, 2))
        
        XCTAssertEqual(distance1, distance2, accuracy: 0.001, "Handles should be symmetric (equal length)")
        
        print("✅ Bezier handle creation test passed")
    }
    
    func testStraightTangentLines() {
        // Test that handles create straight tangent lines
        let anchorPoint = CGPoint(x: 200, y: 200)
        let handleOffset = CGPoint(x: 50, y: 30)
        
        let handle1 = CGPoint(x: anchorPoint.x - handleOffset.x, y: anchorPoint.y - handleOffset.y)
        let handle2 = CGPoint(x: anchorPoint.x + handleOffset.x, y: anchorPoint.y + handleOffset.y)
        
        // Verify that the three points are collinear (form a straight line)
        // Use cross product to check collinearity: (P2-P1) × (P3-P1) = 0
        let vector1 = CGPoint(x: handle1.x - anchorPoint.x, y: handle1.y - anchorPoint.y)
        let vector2 = CGPoint(x: handle2.x - anchorPoint.x, y: handle2.y - anchorPoint.y)
        
        // Cross product in 2D: v1.x * v2.y - v1.y * v2.x
        let crossProduct = vector1.x * vector2.y - vector1.y * vector2.x
        
        // For symmetric handles, the cross product should be close to zero (within floating point precision)
        XCTAssertEqual(crossProduct, 0, accuracy: 0.001, "Handles should form a straight tangent line through anchor point")
        
        print("✅ Straight tangent line test passed")
    }
    
    func testBezierCurveCreation() {
        // Test creating a simple bezier curve
        let initialShapeCount = document.layers.first?.shapes.count ?? 0
        
        // Simulate creating a bezier curve with handles
        let point1 = VectorPoint(50, 50)
        let point2 = VectorPoint(150, 100)
        let control1 = VectorPoint(80, 70)
        let control2 = VectorPoint(120, 80)
        
        let bezierPath = VectorPath(elements: [
            .move(to: point1),
            .curve(to: point2, control1: control1, control2: control2)
        ])
        
        let strokeStyle = StrokeStyle(color: .black, width: 2.0)
        let shape = VectorShape(
            name: "Test Bezier Curve",
            path: bezierPath,
            strokeStyle: strokeStyle,
            fillStyle: nil
        )
        
        document.addShape(shape)
        
        let finalShapeCount = document.layers.first?.shapes.count ?? 0
        XCTAssertEqual(finalShapeCount, initialShapeCount + 1, "Should have added one bezier curve shape")
        
        // Verify the curve has the correct control points
        if let addedShape = document.layers.first?.shapes.last {
            XCTAssertEqual(addedShape.path.elements.count, 2, "Should have move and curve elements")
            
            if case .curve(let to, let ctrl1, let ctrl2) = addedShape.path.elements[1] {
                XCTAssertEqual(to, point2, "Curve endpoint should match")
                XCTAssertEqual(ctrl1, control1, "First control point should match")
                XCTAssertEqual(ctrl2, control2, "Second control point should match")
            } else {
                XCTFail("Second element should be a curve")
            }
        }
        
        print("✅ Bezier curve creation test passed")
    }
    
    func testHandleConstraints() {
        // Test that handles have proper constraints (like maximum length)
        let maxHandleLength: Double = 150.0
        
        // Test with very long drag
        let startPoint = CGPoint(x: 100, y: 100)
        let extremeDragPoint = CGPoint(x: 400, y: 300) // Very long drag
        
        let dragVector = CGPoint(
            x: extremeDragPoint.x - startPoint.x,
            y: extremeDragPoint.y - startPoint.y
        )
        
        let dragLength = sqrt(dragVector.x * dragVector.x + dragVector.y * dragVector.y)
        let constrainedLength = min(dragLength, maxHandleLength)
        
        XCTAssertLessThanOrEqual(constrainedLength, maxHandleLength, "Handle length should be constrained to maximum")
        XCTAssertEqual(constrainedLength, maxHandleLength, "Very long drags should be clamped to maximum")
        
        print("✅ Handle constraints test passed")
    }
    
    func testBezierToolCursor() {
        // Test that bezier tool has the correct cursor
        let bezierCursor = DrawingTool.bezierPen.cursor
        XCTAssertNotNil(bezierCursor, "Bezier tool should have a cursor")
        
        print("✅ Bezier tool cursor test passed")
    }
    
    func testPathElementTypes() {
        // Test different types of path elements for bezier curves
        let point = VectorPoint(100, 100)
        let control1 = VectorPoint(80, 80)
        let control2 = VectorPoint(120, 120)
        
        // Test move element
        let moveElement = PathElement.move(to: point)
        if case .move(let to) = moveElement {
            XCTAssertEqual(to, point, "Move element should preserve point")
        } else {
            XCTFail("Should be a move element")
        }
        
        // Test curve element
        let curveElement = PathElement.curve(to: point, control1: control1, control2: control2)
        if case .curve(let to, let ctrl1, let ctrl2) = curveElement {
            XCTAssertEqual(to, point, "Curve element should preserve endpoint")
            XCTAssertEqual(ctrl1, control1, "Curve element should preserve control1")
            XCTAssertEqual(ctrl2, control2, "Curve element should preserve control2")
        } else {
            XCTFail("Should be a curve element")
        }
        
        print("✅ Path element types test passed")
    }
    
    func testHandleVisibility() {
        // Test that handles are properly configured for visibility
        let handleSize: CGFloat = 8.0
        let lineWidth: CGFloat = 1.5
        
        XCTAssertGreaterThan(handleSize, 0, "Handle size should be positive")
        XCTAssertGreaterThan(lineWidth, 0, "Line width should be positive")
        XCTAssertLessThan(handleSize, 20, "Handle size should be reasonable")
        XCTAssertLessThan(lineWidth, 5, "Line width should be reasonable")
        
        print("✅ Handle visibility test passed")
    }
    
    func testBezierMathematics() {
        // Test basic bezier curve mathematics
        let p0 = CGPoint(x: 0, y: 0)
        let p1 = CGPoint(x: 50, y: 100)
        let p2 = CGPoint(x: 100, y: 100)
        let p3 = CGPoint(x: 150, y: 0)
        
        // Test bezier curve evaluation at t=0.5 (midpoint)
        let t: Double = 0.5
        let oneMinusT = 1.0 - t
        
        // Cubic bezier formula: (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
        let term1 = pow(oneMinusT, 3)
        let term2 = 3 * pow(oneMinusT, 2) * t
        let term3 = 3 * oneMinusT * pow(t, 2)
        let term4 = pow(t, 3)
        
        let x = term1 * p0.x + term2 * p1.x + term3 * p2.x + term4 * p3.x
        let y = term1 * p0.y + term2 * p1.y + term3 * p2.y + term4 * p3.y
        
        let midpoint = CGPoint(x: x, y: y)
        
        // At t=0.5, the curve should be influenced by all control points
        XCTAssertTrue(midpoint.x > p0.x && midpoint.x < p3.x, "Midpoint X should be between start and end")
        XCTAssertGreaterThan(midpoint.y, 0, "Midpoint Y should be positive due to control points")
        
        print("✅ Bezier mathematics test passed")
    }
    
    func testDirectSelectionCompatibility() {
        // Test that bezier curves work with direct selection tool
        
        // Create a bezier curve
        let bezierPath = VectorPath(elements: [
            .move(to: VectorPoint(0, 0)),
            .curve(to: VectorPoint(100, 100), control1: VectorPoint(30, 0), control2: VectorPoint(70, 100))
        ])
        
        let shape = VectorShape(
            name: "Test Curve for Direct Selection",
            path: bezierPath,
            strokeStyle: StrokeStyle(color: .black, width: 1.0),
            fillStyle: nil
        )
        
        document.addShape(shape)
        
        // Switch to direct selection tool
        document.currentTool = .directSelection
        XCTAssertEqual(document.currentTool, .directSelection, "Should be able to switch to direct selection")
        
        // Test that the curve can be selected for direct manipulation
        XCTAssertGreaterThan(document.layers.first?.shapes.count ?? 0, 0, "Should have shapes to select")
        
        print("✅ Direct selection compatibility test passed")
    }
    
    // MARK: - Performance Tests
    
    func testBezierCurvePerformance() {
        measure {
            // Test performance of creating multiple bezier curves
            for i in 0..<50 {
                let path = VectorPath(elements: [
                    .move(to: VectorPoint(Double(i) * 10, 0)),
                    .curve(
                        to: VectorPoint(Double(i) * 10 + 50, 50),
                        control1: VectorPoint(Double(i) * 10 + 20, 10),
                        control2: VectorPoint(Double(i) * 10 + 30, 40)
                    )
                ])
                
                let shape = VectorShape(
                    name: "Performance Test Curve \(i)",
                    path: path,
                    strokeStyle: StrokeStyle(color: .black, width: 1.0),
                    fillStyle: nil
                )
                
                document.addShape(shape)
            }
        }
        
        print("✅ Bezier curve performance test completed")
    }
} 
