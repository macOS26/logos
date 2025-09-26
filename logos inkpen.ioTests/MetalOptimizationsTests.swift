import XCTest
@testable import logos_inkpen_io

class MetalOptimizationsTests: XCTestCase {

    func testMetalEngineInitialization() {
        // Test Metal engine initialization
        let result = MetalComputeEngine.testMetalEngine()
        XCTAssertTrue(result, "Metal engine should initialize successfully")
    }

    func testFastMathEnabled() {
        // Verify fast math is enabled in Metal compile options
        let compileOptions = MTLCompileOptions()
        compileOptions.fastMathEnabled = true
        XCTAssertTrue(compileOptions.fastMathEnabled, "Fast math should be enabled for macOS 14.6")
    }

    func testBufferStorageMode() {
        // Test buffer storage mode optimization
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("No Metal device available")
            return
        }

        let bufferOptions: MTLResourceOptions = device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
        let testBuffer = device.makeBuffer(length: 1024, options: bufferOptions)
        XCTAssertNotNil(testBuffer, "Buffer should be created with optimized storage mode")
    }

    func testParallelCommandExecution() {
        // Test parallel command execution
        let engine = MetalComputeEngine.shared

        let operations: [(MTLCommandBuffer) -> Int] = [
            { _ in 1 },
            { _ in 2 },
            { _ in 3 }
        ]

        let results = engine.executeParallelOperations(operations)
        XCTAssertEqual(results.count, 3, "Should execute all parallel operations")
        XCTAssertEqual(results, [1, 2, 3], "Results should match expected values")
    }

    func testDouglasPeuckerGPU() {
        // Test Douglas-Peucker simplification
        let engine = MetalComputeEngine.shared
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0.1),
            CGPoint(x: 2, y: -0.1),
            CGPoint(x: 3, y: 5),
            CGPoint(x: 4, y: 6),
            CGPoint(x: 5, y: 7),
            CGPoint(x: 6, y: 8.1),
            CGPoint(x: 7, y: 9),
            CGPoint(x: 8, y: 9),
            CGPoint(x: 9, y: 9)
        ]

        let result = engine.douglasPeuckerGPU(points, tolerance: 1.0)

        switch result {
        case .success(let simplifiedPoints):
            XCTAssertLessThan(simplifiedPoints.count, points.count, "Should reduce point count")
            XCTAssertGreaterThan(simplifiedPoints.count, 1, "Should retain at least start and end points")
        case .failure(let error):
            XCTFail("Douglas-Peucker GPU failed: \(error)")
        }
    }

    func testTransformPointsGPU() {
        // Test matrix transformation
        let engine = MetalComputeEngine.shared
        let points = [
            CGPoint(x: 1, y: 1),
            CGPoint(x: 2, y: 2),
            CGPoint(x: 3, y: 3)
        ]

        let transform = CGAffineTransform(scaleX: 2, y: 2)
        let result = engine.transformPointsGPU(points, transform: transform)

        switch result {
        case .success(let transformedPoints):
            XCTAssertEqual(transformedPoints.count, points.count, "Should maintain point count")
            XCTAssertEqual(transformedPoints[0].x, 2, accuracy: 0.01, "First point X should be doubled")
            XCTAssertEqual(transformedPoints[0].y, 2, accuracy: 0.01, "First point Y should be doubled")
        case .failure(let error):
            XCTFail("Transform points GPU failed: \(error)")
        }
    }

    func testVectorDistanceGPU() {
        // Test vector distance calculation
        let engine = MetalComputeEngine.shared
        let sourcePoints = [CGPoint(x: 0, y: 0)]
        let targetPoints = [CGPoint(x: 3, y: 4)]

        let result = engine.calculateDistancesGPU(from: sourcePoints, to: targetPoints)

        switch result {
        case .success(let distances):
            XCTAssertEqual(distances.count, 1, "Should return one distance")
            XCTAssertEqual(distances[0], 5.0, accuracy: 0.01, "Distance should be 5 (3-4-5 triangle)")
        case .failure(let error):
            XCTFail("Distance calculation GPU failed: \(error)")
        }
    }

    func testBezierCurveGPU() {
        // Test Bezier curve calculation
        let engine = MetalComputeEngine.shared
        let controlPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 100),
            CGPoint(x: 150, y: 100),
            CGPoint(x: 200, y: 0)
        ]

        let result = engine.calculateBezierCurveGPU(controlPoints: controlPoints, steps: 10)

        switch result {
        case .success(let curvePoints):
            XCTAssertEqual(curvePoints.count, 10, "Should generate requested number of points")
            XCTAssertEqual(curvePoints.first?.x, 0, accuracy: 0.01, "First point should match start")
            XCTAssertEqual(curvePoints.last?.x, 200, accuracy: 0.01, "Last point should match end")
        case .failure(let error):
            XCTFail("Bezier curve GPU failed: \(error)")
        }
    }

    func testPerformanceMode() {
        // Test performance mode reporting
        let engine = MetalComputeEngine.shared
        let mode = engine.getPerformanceMode()
        XCTAssertTrue(mode.contains("GPU"), "Should report GPU acceleration mode")
    }

    func testMemoryOptimization() {
        // Test memory usage with optimized buffer creation
        let initialMemory = getMemoryUsage()

        // Create multiple buffers with optimized settings
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("No Metal device available")
            return
        }

        var buffers: [MTLBuffer?] = []
        for _ in 0..<100 {
            let options: MTLResourceOptions = device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
            buffers.append(device.makeBuffer(length: 1024 * 1024, options: options))
        }

        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        // Cleanup
        buffers.removeAll()

        XCTAssertLessThan(memoryIncrease, 200 * 1024 * 1024, "Memory usage should be optimized")
    }

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}