//
//  GPUPointSelectionTests.swift
//  logos inkpen.io Tests
//
//  GPU-accelerated point selection unit tests
//  Tests the Metal compute shaders for ultra-fast direct select tool point/handle selection
//

import XCTest
@testable import logos_inkpen_io

final class GPUPointSelectionTests: XCTestCase {

    var metalEngine: MetalComputeEngine!

    override func setUp() {
        super.setUp()
        metalEngine = MetalComputeEngine.shared
    }

    override func tearDown() {
        metalEngine = nil
        super.tearDown()
    }

    // MARK: - Point Selection Tests

    func testGPUPointSelectionBasic() throws {
        // Test basic point selection with a simple grid
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 200, y: 0),
            CGPoint(x: 0, y: 100),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100)
        ]

        // Tap near point at (100, 100) - index 4
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
        // Test point selection with shape transform
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 0, y: 100)
        ]

        // Apply translation transform
        let transform = CGAffineTransform(translationX: 50, y: 50)

        // Tap at transformed location (150, 50) which is point 1 after transform
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
        // Test that tapping far from any point returns nil
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 200, y: 0)
        ]

        // Tap far away from all points
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
        // Performance test with many points (simulating complex path)
        var points: [CGPoint] = []
        for i in 0..<1000 {
            let angle = CGFloat(i) * 0.01
            let radius: CGFloat = 100.0
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            points.append(CGPoint(x: x, y: y))
        }

        // Tap near a specific point
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

        // Verify we got a point very close to the target
        if let index = result {
            let selectedPoint = points[index]
            let distance = sqrt(pow(selectedPoint.x - targetPoint.x, 2) + pow(selectedPoint.y - targetPoint.y, 2))
            XCTAssertTrue(distance < 5.0, "Selected point should be within tolerance")
        }
    }

    // MARK: - Handle Selection Tests

    func testGPUHandleSelectionBasic() throws {
        // Test basic handle selection
        let handlePoints = [
            CGPoint(x: 10, y: 10),   // Handle 0
            CGPoint(x: 110, y: 10),  // Handle 1
            CGPoint(x: 210, y: 10)   // Handle 2
        ]

        let anchorPoints = [
            CGPoint(x: 0, y: 0),     // Anchor for handle 0
            CGPoint(x: 100, y: 0),   // Anchor for handle 1
            CGPoint(x: 200, y: 0)    // Anchor for handle 2
        ]

        // Tap near handle 1
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
        // Test that collapsed handles are filtered out by GPU
        let handlePoints = [
            CGPoint(x: 10, y: 10),   // Valid handle
            CGPoint(x: 100, y: 0),   // Collapsed handle (same as anchor)
            CGPoint(x: 210, y: 10)   // Valid handle
        ]

        let anchorPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),   // Anchor same as handle - COLLAPSED
            CGPoint(x: 200, y: 0)
        ]

        // Tap near the collapsed handle location
        let tapLocation = CGPoint(x: 100, y: 0)
        let selectionRadius: CGFloat = 10.0

        let result = metalEngine.findNearestHandleGPU(
            handlePoints: handlePoints,
            anchorPoints: anchorPoints,
            tapLocation: tapLocation,
            selectionRadius: selectionRadius
        )

        // Should not select the collapsed handle
        // Might select handle 0 or 2 if they're within range, or nil
        if let index = result {
            XCTAssertNotEqual(index, 1, "Should not select collapsed handle at index 1")
        }
    }

    // MARK: - Multi-Point Selection Tests

    func testGPUFindPointsInRadius() throws {
        // Test finding multiple points within a radius
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 5, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 100, y: 0)  // Far away
        ]

        // Tap at origin with radius that should catch first 3 points
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

    // MARK: - Performance Benchmarks

    func testGPUPointSelectionPerformance() throws {
        // Measure GPU performance vs expected baseline
        let pointCounts = [100, 500, 1000, 5000]

        for count in pointCounts {
            // Create points in a circle
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

            // GPU should handle even 5000 points in under 20ms
            XCTAssertTrue(elapsedTime < 0.02, "\(count) points should complete in < 20ms (was \(elapsedTime * 1000)ms)")

            print("✓ GPU processed \(count) points in \(String(format: "%.2f", elapsedTime * 1000))ms")
        }
    }
}
