//
//  ShearHandlesTests.swift
//  logos inkpen.io Tests
//
//  Created by Test Suite
//

import XCTest
@testable import logos_inkpen_io
import SwiftUI

class ShearHandlesTests: XCTestCase {

    var document: VectorDocument!

    override func setUp() {
        super.setUp()
        document = VectorDocument()
        document.addLayerAt(index: 0)
    }

    override func tearDown() {
        document = nil
        super.tearDown()
    }

    func testShearHandlesInitialCenterPointWithTransform() {
        // Create a shape with a transform
        let path = VectorPath(elements: [
            .move(to: VectorPoint(CGPoint(x: 100, y: 100))),
            .line(to: VectorPoint(CGPoint(x: 200, y: 100))),
            .line(to: VectorPoint(CGPoint(x: 200, y: 200))),
            .line(to: VectorPoint(CGPoint(x: 100, y: 200))),
            .close
        ], isClosed: true)

        var shape = VectorShape(path: path)
        shape.name = "Test Rectangle"

        // Apply a transform to the shape (rotation + translation)
        let transform = CGAffineTransform(rotationAngle: .pi / 4)
            .concatenating(CGAffineTransform(translationX: 50, y: 50))
        shape.transform = transform
        shape.updateBounds()

        // Add shape to document
        document.appendShapeToLayer(layerIndex: 0, shape: shape)

        // Create the ShearHandles view
        let shearHandles = ShearHandles(
            document: document,
            shape: shape,
            zoomLevel: 1.0,
            canvasOffset: .zero,
            isShiftPressed: false
        )

        // Verify that calculated bounds accounts for transform
        let calculatedBounds = shearHandles.calculatedBounds
        let calculatedCenter = shearHandles.calculatedCenter

        // For a transformed shape, the bounds should be different from the original
        XCTAssertNotEqual(calculatedBounds, shape.bounds, "Calculated bounds should account for transform")

        // The center point should be at the center of the transformed bounds
        XCTAssertEqual(calculatedCenter.x, calculatedBounds.midX, accuracy: 0.01)
        XCTAssertEqual(calculatedCenter.y, calculatedBounds.midY, accuracy: 0.01)

        print("✅ Test passed: Center point correctly calculated for transformed shape")
        print("   Original bounds: \(shape.bounds)")
        print("   Calculated bounds: \(calculatedBounds)")
        print("   Calculated center: \(calculatedCenter)")
    }

    func testShearHandlesInitialCenterPointWithoutTransform() {
        // Create a shape without transform
        let path = VectorPath(elements: [
            .move(to: VectorPoint(CGPoint(x: 100, y: 100))),
            .line(to: VectorPoint(CGPoint(x: 200, y: 100))),
            .line(to: VectorPoint(CGPoint(x: 200, y: 200))),
            .line(to: VectorPoint(CGPoint(x: 100, y: 200))),
            .close
        ], isClosed: true)

        var shape = VectorShape(path: path)
        shape.name = "Test Rectangle No Transform"
        shape.updateBounds()

        // Add shape to document
        document.appendShapeToLayer(layerIndex: 0, shape: shape)

        // Create the ShearHandles view
        let shearHandles = ShearHandles(
            document: document,
            shape: shape,
            zoomLevel: 1.0,
            canvasOffset: .zero,
            isShiftPressed: false
        )

        // Verify that calculated bounds matches shape bounds when no transform
        let calculatedBounds = shearHandles.calculatedBounds
        let calculatedCenter = shearHandles.calculatedCenter

        // Without transform, calculated bounds should equal shape bounds
        XCTAssertEqual(calculatedBounds, shape.bounds, "Calculated bounds should match shape bounds when no transform")

        // The center point should be at the center of the bounds
        XCTAssertEqual(calculatedCenter.x, shape.bounds.midX, accuracy: 0.01)
        XCTAssertEqual(calculatedCenter.y, shape.bounds.midY, accuracy: 0.01)

        print("✅ Test passed: Center point correctly calculated for non-transformed shape")
        print("   Shape bounds: \(shape.bounds)")
        print("   Calculated center: \(calculatedCenter)")
    }
}