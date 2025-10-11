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
        let path = VectorPath(elements: [
            .move(to: VectorPoint(CGPoint(x: 100, y: 100))),
            .line(to: VectorPoint(CGPoint(x: 200, y: 100))),
            .line(to: VectorPoint(CGPoint(x: 200, y: 200))),
            .line(to: VectorPoint(CGPoint(x: 100, y: 200))),
            .close
        ], isClosed: true)

        var shape = VectorShape(path: path)
        shape.name = "Test Rectangle"

        let transform = CGAffineTransform(rotationAngle: .pi / 4)
            .concatenating(CGAffineTransform(translationX: 50, y: 50))
        shape.transform = transform
        shape.updateBounds()

        document.appendShapeToLayer(layerIndex: 0, shape: shape)

        let shearHandles = ShearHandles(
            document: document,
            shape: shape,
            zoomLevel: 1.0,
            canvasOffset: .zero,
            isShiftPressed: false
        )

        let calculatedBounds = shearHandles.calculatedBounds
        let calculatedCenter = shearHandles.calculatedCenter

        XCTAssertNotEqual(calculatedBounds, shape.bounds, "Calculated bounds should account for transform")

        XCTAssertEqual(calculatedCenter.x, calculatedBounds.midX, accuracy: 0.01)
        XCTAssertEqual(calculatedCenter.y, calculatedBounds.midY, accuracy: 0.01)

        print("✅ Test passed: Center point correctly calculated for transformed shape")
        print("   Original bounds: \(shape.bounds)")
        print("   Calculated bounds: \(calculatedBounds)")
        print("   Calculated center: \(calculatedCenter)")
    }

    func testShearHandlesInitialCenterPointWithoutTransform() {
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

        document.appendShapeToLayer(layerIndex: 0, shape: shape)

        let shearHandles = ShearHandles(
            document: document,
            shape: shape,
            zoomLevel: 1.0,
            canvasOffset: .zero,
            isShiftPressed: false
        )

        let calculatedBounds = shearHandles.calculatedBounds
        let calculatedCenter = shearHandles.calculatedCenter

        XCTAssertEqual(calculatedBounds, shape.bounds, "Calculated bounds should match shape bounds when no transform")

        XCTAssertEqual(calculatedCenter.x, shape.bounds.midX, accuracy: 0.01)
        XCTAssertEqual(calculatedCenter.y, shape.bounds.midY, accuracy: 0.01)

        print("✅ Test passed: Center point correctly calculated for non-transformed shape")
        print("   Shape bounds: \(shape.bounds)")
        print("   Calculated center: \(calculatedCenter)")
    }
}
