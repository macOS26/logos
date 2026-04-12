import XCTest
@testable import logos_inkpen_io

final class GPUPointSelectionTests: XCTestCase {

    var metalEngine = MetalComputeEngine.shared

    override func setUp() {
        super.setUp()
        metalEngine = MetalComputeEngine.shared
    }

    override func tearDown() {
        super.tearDown()
    }

    func testGPUPointSelectionBasic() throws {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 200, y: 0),
            CGPoint(x: 0, y: 100),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100)
        ]

        let tapLocation = CGPoint(x: 105, y: 105)
        let selectionRadius: CGFloat = 10.0
        let result = metalEngine.findNearestPointGPU(
            points: points,
            tapLocation: tapLocation,
            selectionRadius: selectionRadius
        )

        XCTAssertNotNil(result, "GPU point selection should find a point")
        XCTAssertEqual(result, 4, "Should select point at index 4 (100, 100)")
    }

    func testGPUPointSelectionWithTransform() throws {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 0, y: 100)
        ]

        let transform = CGAffineTransform(translationX: 50, y: 50)
        let tapLocation = CGPoint(x: 150, y: 50)
        let selectionRadius: CGFloat = 10.0
        let result = metalEngine.findNearestPointGPU(
            points: points,
            tapLocation: tapLocation,
            selectionRadius: selectionRadius,
            transform: transform
        )

        XCTAssertNotNil(result, "GPU point selection should find a point with transform")
        XCTAssertEqual(result, 1, "Should select point at index 1 after transform")
    }

    func testGPUPointSelectionOutOfRange() throws {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 200, y: 0)
        ]

        let tapLocation = CGPoint(x: 1000, y: 1000)
        let selectionRadius: CGFloat = 10.0
        let result = metalEngine.findNearestPointGPU(
            points: points,
            tapLocation: tapLocation,
            selectionRadius: selectionRadius
        )

        XCTAssertNil(result, "GPU point selection should return nil when tap is out of range")
    }

    func testGPUPointSelectionWithManyPoints() throws {
        var points: [CGPoint] = []
        for i in 0..<1000 {
            let angle = CGFloat(i) * 0.01
            let radius: CGFloat = 100.0
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            points.append(CGPoint(x: x, y: y))
        }

        let targetIndex = 500
        let targetPoint = points[targetIndex]
        let tapLocation = CGPoint(x: targetPoint.x + 0.5, y: targetPoint.y + 0.5)
        let selectionRadius: CGFloat = 5.0
        let startTime = CFAbsoluteTimeGetCurrent()

        let result = metalEngine.findNearestPointGPU(
            points: points,
            tapLocation: tapLocation,
            selectionRadius: selectionRadius
        )

        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertNotNil(result, "GPU point selection should find a point in large dataset")
        XCTAssertTrue(elapsedTime < 0.01, "GPU point selection should complete in < 10ms for 1000 points (was \(elapsedTime * 1000)ms)")

        if let index = result {
            let selectedPoint = points[index]
            let distance = sqrt(pow(selectedPoint.x - targetPoint.x, 2) + pow(selectedPoint.y - targetPoint.y, 2))
            XCTAssertTrue(distance < 5.0, "Selected point should be within tolerance")
        }
    }

    func testGPUHandleSelectionBasic() throws {
        let handlePoints = [
            CGPoint(x: 10, y: 10),
            CGPoint(x: 110, y: 10),
            CGPoint(x: 210, y: 10)
        ]

        let anchorPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 200, y: 0)
        ]

        let tapLocation = CGPoint(x: 112, y: 12)
        let selectionRadius: CGFloat = 10.0
        let result = metalEngine.findNearestHandleGPU(
            handlePoints: handlePoints,
            anchorPoints: anchorPoints,
            tapLocation: tapLocation,
            selectionRadius: selectionRadius
        )

        XCTAssertNotNil(result, "GPU handle selection should find a handle")
        XCTAssertEqual(result, 1, "Should select handle at index 1")
    }

    func testGPUHandleSelectionCollapsedHandle() throws {
        let handlePoints = [
            CGPoint(x: 10, y: 10),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 210, y: 10)
        ]

        let anchorPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 200, y: 0)
        ]

        let tapLocation = CGPoint(x: 100, y: 0)
        let selectionRadius: CGFloat = 10.0
        let result = metalEngine.findNearestHandleGPU(
            handlePoints: handlePoints,
            anchorPoints: anchorPoints,
            tapLocation: tapLocation,
            selectionRadius: selectionRadius
        )

        if let index = result {
            XCTAssertNotEqual(index, 1, "Should not select collapsed handle at index 1")
        }
    }

    func testGPUFindPointsInRadius() throws {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 5, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 100, y: 0)
        ]

        let tapLocation = CGPoint(x: 0, y: 0)
        let selectionRadius: CGFloat = 15.0
        let results = metalEngine.findPointsInRadiusGPU(
            points: points,
            tapLocation: tapLocation,
            selectionRadius: selectionRadius
        )

        XCTAssertEqual(results.count, 3, "Should find 3 points within radius")
        XCTAssertTrue(results.contains(0), "Should include point 0")
        XCTAssertTrue(results.contains(1), "Should include point 1")
        XCTAssertTrue(results.contains(2), "Should include point 2")
        XCTAssertFalse(results.contains(3), "Should not include distant point 3")
    }

    func testGPUPointSelectionPerformance() throws {
        let pointCounts = [100, 500, 1000, 5000]

        for count in pointCounts {
            var points: [CGPoint] = []
            for i in 0..<count {
                let angle = CGFloat(i) * .pi * 2.0 / CGFloat(count)
                points.append(CGPoint(x: cos(angle) * 100, y: sin(angle) * 100))
            }

            let tapLocation = CGPoint(x: 100, y: 0)
            let selectionRadius: CGFloat = 10.0
            let startTime = CFAbsoluteTimeGetCurrent()

            _ = metalEngine.findNearestPointGPU(
                points: points,
                tapLocation: tapLocation,
                selectionRadius: selectionRadius
            )

            let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

            XCTAssertTrue(elapsedTime < 0.02, "\(count) points should complete in < 20ms (was \(elapsedTime * 1000)ms)")

            print("✓ GPU processed \(count) points in \(String(format: "%.2f", elapsedTime * 1000))ms")
        }
    }
}
