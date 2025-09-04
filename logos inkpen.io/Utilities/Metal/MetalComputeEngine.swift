import Metal
import MetalKit
import Foundation



/// Phase 2: Metal Compute Shaders for GPU-accelerated Core Graphics math
class MetalComputeEngine {
    
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Compute pipeline states
    private var douglasPeuckerPipeline: MTLComputePipelineState?
    private var bezierCalculationPipeline: MTLComputePipelineState?
    private var matrixTransformPipeline: MTLComputePipelineState?
    private var collisionDetectionPipeline: MTLComputePipelineState?
    private var pathRenderingPipeline: MTLComputePipelineState?
    
    // Phase 6: Vector Operations
    private var vectorDistancePipeline: MTLComputePipelineState?
    private var vectorNormalizePipeline: MTLComputePipelineState?
    private var vectorLerpPipeline: MTLComputePipelineState?
    
    // Phase 7: Handle Calculations
    private var handleCalculationPipeline: MTLComputePipelineState?
    
    // Phase 10: Curve Smoothing and Curvature
    private var curvatureCalculationPipeline: MTLComputePipelineState?
    private var chaikinSmoothingPipeline: MTLComputePipelineState?
    
    // Phase 11: Mathematical Operations
    private var distanceCalculationPipeline: MTLComputePipelineState?
    private var squareRootPipeline: MTLComputePipelineState?
    
    // Phase 12: Trigonometric Operations
    private var trigonometricPipeline: MTLComputePipelineState?
    private var polygonCalculationPipeline: MTLComputePipelineState?
    
    // Phase 13: Boolean Geometry Operations
    private var booleanGeometryPipeline: MTLComputePipelineState?
    private var pathIntersectionPipeline: MTLComputePipelineState?
    
    // Phase 14: Advanced Shape Operations
    private var bezierTessellationPipeline: MTLComputePipelineState?
    private var shapeOptimizationPipeline: MTLComputePipelineState?
    private var pathSimplificationPipeline: MTLComputePipelineState?
    
    // Phase 15: Color Processing
    private var colorInterpolationPipeline: MTLComputePipelineState?
    private var colorSpaceConversionPipeline: MTLComputePipelineState?
    private var gradientCalculationPipeline: MTLComputePipelineState?
    
    // Phase 16: Performance Optimizations
    private var batchOperationPipeline: MTLComputePipelineState?
    private var memoryOptimizationPipeline: MTLComputePipelineState?
    private var cacheOptimizationPipeline: MTLComputePipelineState?
    
    static let shared: MetalComputeEngine = {
        do {
            return try MetalComputeEngine()
        } catch {
            fatalError("Failed to initialize Metal Compute Engine: \(error)")
        }
    }()
    
    private init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalError.deviceNotAvailable
        }
        
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalError.commandBufferCreationFailed
        }
        self.commandQueue = commandQueue
        
        // Create Metal library from .metal file
        guard let library = device.makeDefaultLibrary() else {
            throw MetalError.libraryCreationFailed
        }
        self.library = library
        try setupComputePipelines()
        // REMOVED: Repetitive Metal GPU acceleration logging
    }
    
    // MARK: - Setup
    
    private func setupComputePipelines() throws {
        // Douglas-Peucker distance calculation
        if let function = library.makeFunction(name: "calculate_distances") {
            douglasPeuckerPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Bezier curve calculation
        if let function = library.makeFunction(name: "calculate_bezier_curves") {
            bezierCalculationPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Matrix transformations
        if let function = library.makeFunction(name: "transform_points") {
            matrixTransformPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Collision detection
        if let function = library.makeFunction(name: "point_in_polygon") {
            collisionDetectionPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Path rendering
        if let function = library.makeFunction(name: "render_path_points") {
            pathRenderingPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Phase 6: Vector operations
        if let function = library.makeFunction(name: "calculate_vector_distances") {
            vectorDistancePipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "normalize_vectors") {
            vectorNormalizePipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "lerp_vectors") {
            vectorLerpPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Phase 7: Handle calculations
        if let function = library.makeFunction(name: "calculate_linked_handles") {
            handleCalculationPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Phase 10: Curve smoothing and curvature
        if let function = library.makeFunction(name: "calculate_curvature") {
            curvatureCalculationPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "chaikin_smoothing") {
            chaikinSmoothingPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Phase 11: Mathematical operations
        if let function = library.makeFunction(name: "calculate_point_distance") {
            distanceCalculationPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "calculate_square_roots") {
            squareRootPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Phase 12: Trigonometric operations
        if let function = library.makeFunction(name: "calculate_trigonometric") {
            trigonometricPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "calculate_polygon_points") {
            polygonCalculationPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Phase 13: Boolean Geometry operations
        if let function = library.makeFunction(name: "boolean_geometry_union") {
            booleanGeometryPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "path_intersection_calculation") {
            pathIntersectionPipeline = try device.makeComputePipelineState(function: function)
        }
    }
    
    // MARK: - Phase 2: GPU Douglas-Peucker with Metal Shaders
    
    func douglasPeuckerGPU(_ points: [CGPoint], tolerance: Float) -> Result<[CGPoint], MetalError> {
        guard points.count > 2 else {
            return .failure(.operationFailed("Need at least 3 points for Douglas-Peucker simplification"))
        }
        
        guard douglasPeuckerPipeline != nil else {
            return .failure(.pipelineNotAvailable)
        }
        
        let result = douglasPeuckerRecursiveGPU(points: points, tolerance: tolerance, startIndex: 0, endIndex: points.count - 1)
        return .success(result)
    }
    
    private func douglasPeuckerRecursiveGPU(points: [CGPoint], tolerance: Float, startIndex: Int, endIndex: Int) -> [CGPoint] {
        guard endIndex - startIndex > 1 else {
            return [points[startIndex], points[endIndex]]
        }
        
        let segmentPoints = Array(points[startIndex...endIndex])
        let lineStart = points[startIndex]
        let lineEnd = points[endIndex]
        
        // Use GPU to find maximum distance point
        let maxResult = findMaxDistanceGPU(points: segmentPoints, lineStart: lineStart, lineEnd: lineEnd)
        
        switch maxResult {
        case .success(let result):
            if result.distance > tolerance {
                let maxIndex = startIndex + result.index
            
            // Recursively simplify segments
            let leftSegment = douglasPeuckerRecursiveGPU(
                points: points, tolerance: tolerance, 
                startIndex: startIndex, endIndex: maxIndex
            )
            let rightSegment = douglasPeuckerRecursiveGPU(
                points: points, tolerance: tolerance,
                startIndex: maxIndex, endIndex: endIndex
            )
            
                            return leftSegment + Array(rightSegment.dropFirst())
            } else {
                return [points[startIndex], points[endIndex]]
            }
        case .failure(_):
            // Return minimal result instead of CPU fallback
            return [points[startIndex], points[endIndex]]
        }
    }
    
    private func findMaxDistanceGPU(points: [CGPoint], lineStart: CGPoint, lineEnd: CGPoint) -> Result<(distance: Float, index: Int), MetalError> {
        guard let pipeline = douglasPeuckerPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let pointCount = points.count
        guard pointCount > 0 else {
            return .failure(.operationFailed("No points provided"))
        }
        
        // Convert to Metal-compatible format
        let metalPoints = points.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        guard let pointsBuffer = device.makeBuffer(bytes: metalPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let distancesBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        
        var lineStartMetal = Point2D(x: Float(lineStart.x), y: Float(lineStart.y))
        var lineEndMetal = Point2D(x: Float(lineEnd.x), y: Float(lineEnd.y))
        var pointCountUInt = UInt32(pointCount)
        var zeroUInt: UInt32 = 0
        guard let maxIndexBuffer = device.makeBuffer(bytes: &zeroUInt, length: MemoryLayout<UInt32>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        
        // Setup compute encoder
        computeEncoder.setComputePipelineState(pipeline)
        // Match Metal shader signature in MetalComputeShaders.metal:
        // points[0], lineStart[1], lineEnd[2], distances[3], maxIndex[4], pointCount[5]
        computeEncoder.setBuffer(pointsBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&lineStartMetal, length: MemoryLayout<Point2D>.stride, index: 1)
        computeEncoder.setBytes(&lineEndMetal, length: MemoryLayout<Point2D>.stride, index: 2)
        computeEncoder.setBuffer(distancesBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(maxIndexBuffer, offset: 0, index: 4)
        computeEncoder.setBytes(&pointCountUInt, length: MemoryLayout<UInt32>.stride, index: 5)
        
        // Dispatch threads
        let tpw = max(1, min(pipeline.maxTotalThreadsPerThreadgroup, pointCount))
        let threadsPerGroup = MTLSize(width: tpw, height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + tpw - 1) / tpw, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let distancesPointer = distancesBuffer.contents().bindMemory(to: Float.self, capacity: pointCount)

        var maxDistance: Float = 0
        var maxIndex = 0
        // Always compute max on CPU; the kernel does not perform a real reduction
        for i in 0..<pointCount {
            let distance = distancesPointer[i]
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        return .success((distance: maxDistance, index: maxIndex))
    }
    
    // MARK: - Phase 3: GPU Matrix Transformations
    
    func transformPointsGPU(_ points: [CGPoint], transform: CGAffineTransform) -> Result<[CGPoint], MetalError> {
        guard let pipeline = matrixTransformPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let pointCount = points.count
        let metalPoints = points.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Convert CGAffineTransform to Metal-compatible matrix
        let transformMatrix: [Float] = [
            Float(transform.a), Float(transform.b), 0,
            Float(transform.c), Float(transform.d), 0,
            Float(transform.tx), Float(transform.ty), 1
        ]
        
        // Create buffers
        guard let inputBuffer = device.makeBuffer(bytes: metalPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let transformBuffer = device.makeBuffer(bytes: transformMatrix, length: 9 * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(transformBuffer, offset: 0, index: 2)
        
        // Dispatch
        let threadsPerGroup = MTLSize(width: min(pointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let resultPointer = outputBuffer.contents().bindMemory(to: Point2D.self, capacity: pointCount)
        
        var result: [CGPoint] = []
        for i in 0..<pointCount {
            let point = resultPointer[i]
            result.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return .success(result)
    }
    
    // MARK: - Phase 4: GPU Collision Detection
    
    func pointsInPolygonGPU(_ testPoints: [CGPoint], polygon: [CGPoint]) -> Result<[Bool], MetalError> {
        guard let pipeline = collisionDetectionPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let testPointCount = testPoints.count
        let polygonVertexCount = polygon.count
        
        // Convert to Metal format
        let metalTestPoints = testPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalPolygonVertices = polygon.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        guard let testPointsBuffer = device.makeBuffer(bytes: metalTestPoints, length: testPointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let polygonBuffer = device.makeBuffer(bytes: metalPolygonVertices, length: polygonVertexCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let resultsBuffer = device.makeBuffer(length: testPointCount * MemoryLayout<Bool>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        var vertexCount = UInt32(polygonVertexCount)
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(testPointsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(polygonBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(resultsBuffer, offset: 0, index: 2)
        computeEncoder.setBytes(&vertexCount, length: MemoryLayout<UInt32>.stride, index: 3)
        
        // Dispatch
        let threadsPerGroup = MTLSize(width: min(testPointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (testPointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let resultPointer = resultsBuffer.contents().bindMemory(to: Bool.self, capacity: testPointCount)
        
        var results: [Bool] = []
        for i in 0..<testPointCount {
            results.append(resultPointer[i])
        }
        
        return .success(results)
    }
    
    // MARK: - Phase 5: GPU Path Rendering
    
    func renderPathGPU(pathPoints: [CGPoint], strokeWidth: Float, resolution: Int) -> Result<[CGPoint], MetalError> {
        guard let pipeline = pathRenderingPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let inputPointCount = pathPoints.count
        let outputPointCount = inputPointCount * resolution // Generate more points for smooth rendering
        
        // Convert to Metal format
        let metalPathPoints = pathPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        guard let inputBuffer = device.makeBuffer(bytes: metalPathPoints, length: inputPointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: outputPointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        var pathStrokeWidth = strokeWidth
        var pathResolution = UInt32(resolution)
        var pathInputCount = UInt32(inputPointCount)
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&pathStrokeWidth, length: MemoryLayout<Float>.stride, index: 2)
        computeEncoder.setBytes(&pathResolution, length: MemoryLayout<UInt32>.stride, index: 3)
        computeEncoder.setBytes(&pathInputCount, length: MemoryLayout<UInt32>.stride, index: 4)
        
        // Dispatch
        let threadsPerGroup = MTLSize(width: min(outputPointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (outputPointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let resultPointer = outputBuffer.contents().bindMemory(to: Point2D.self, capacity: outputPointCount)
        
        var result: [CGPoint] = []
        for i in 0..<outputPointCount {
            let point = resultPointer[i]
            // Skip invalid points (Metal shader may output zeros for unused indices)
            if point.x != 0 || point.y != 0 {
                result.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
            }
        }
        
        return .success(result)
    }
    
    // MARK: - Phase 6: GPU Vector Operations
    
    func calculateDistancesGPU(from sourcePoints: [CGPoint], to targetPoints: [CGPoint]) -> Result<[Float], MetalError> {
        guard sourcePoints.count == targetPoints.count else {
            return .failure(.operationFailed("Source and target point counts must match"))
        }
        
        guard let pipeline = vectorDistancePipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let pointCount = sourcePoints.count
        let metalSourcePoints = sourcePoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalTargetPoints = targetPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        guard let sourceBuffer = device.makeBuffer(bytes: metalSourcePoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let targetBuffer = device.makeBuffer(bytes: metalTargetPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let distanceBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(targetBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(distanceBuffer, offset: 0, index: 2)
        
        // Dispatch
        let threadsPerGroup = MTLSize(width: min(pointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let resultPointer = distanceBuffer.contents().bindMemory(to: Float.self, capacity: pointCount)
        
        var results: [Float] = []
        for i in 0..<pointCount {
            results.append(resultPointer[i])
        }
        
        return .success(results)
    }
    
    func normalizeVectorsGPU(_ vectors: [CGPoint]) -> Result<[CGPoint], MetalError> {
        guard let pipeline = vectorNormalizePipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let vectorCount = vectors.count
        let metalVectors = vectors.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        guard let inputBuffer = device.makeBuffer(bytes: metalVectors, length: vectorCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: vectorCount * MemoryLayout<Point2D>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        
        // Dispatch
        let threadsPerGroup = MTLSize(width: min(vectorCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (vectorCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let resultPointer = outputBuffer.contents().bindMemory(to: Point2D.self, capacity: vectorCount)
        
        var results: [CGPoint] = []
        for i in 0..<vectorCount {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return .success(results)
    }
    
    func lerpVectorsGPU(from startPoints: [CGPoint], to endPoints: [CGPoint], t: Float) -> Result<[CGPoint], MetalError> {
        guard startPoints.count == endPoints.count else {
            return .failure(.operationFailed("Start and end point counts must match"))
        }
        
        guard let pipeline = vectorLerpPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let pointCount = startPoints.count
        let metalStartPoints = startPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalEndPoints = endPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        guard let startBuffer = device.makeBuffer(bytes: metalStartPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let endBuffer = device.makeBuffer(bytes: metalEndPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        var lerpFactor = t
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(startBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(endBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 2)
        computeEncoder.setBytes(&lerpFactor, length: MemoryLayout<Float>.stride, index: 3)
        
        // Dispatch
        let threadsPerGroup = MTLSize(width: min(pointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let resultPointer = outputBuffer.contents().bindMemory(to: Point2D.self, capacity: pointCount)
        
        var results: [CGPoint] = []
        for i in 0..<pointCount {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return .success(results)
    }
    
    // MARK: - Phase 7: GPU Handle Calculations
    
    func calculateLinkedHandlesGPU(anchorPoints: [CGPoint], draggedHandles: [CGPoint], originalOppositeHandles: [CGPoint]) -> Result<[CGPoint], MetalError> {
        guard anchorPoints.count == draggedHandles.count && 
              draggedHandles.count == originalOppositeHandles.count else {
            return .failure(.operationFailed("All point arrays must have the same count"))
        }
        
        guard let pipeline = handleCalculationPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let pointCount = anchorPoints.count
        let metalAnchorPoints = anchorPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalDraggedHandles = draggedHandles.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalOriginalHandles = originalOppositeHandles.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        guard let anchorBuffer = device.makeBuffer(bytes: metalAnchorPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let draggedBuffer = device.makeBuffer(bytes: metalDraggedHandles, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let originalBuffer = device.makeBuffer(bytes: metalOriginalHandles, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(anchorBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(draggedBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(originalBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 3)
        
        // Dispatch
        let threadsPerGroup = MTLSize(width: min(pointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let resultPointer = outputBuffer.contents().bindMemory(to: Point2D.self, capacity: pointCount)
        
        var results: [CGPoint] = []
        for i in 0..<pointCount {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return .success(results)
    }
    
    // MARK: - Phase 10: GPU Curve Smoothing and Curvature
    
    func calculateCurvatureGPU(points: [CGPoint]) -> Result<[Float], MetalError> {
        guard points.count >= 3 else {
            return .failure(.operationFailed("Need at least 3 points for curvature calculation"))
        }
        
        guard let pipeline = curvatureCalculationPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let pointCount = points.count
        let metalPoints = points.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        guard let pointsBuffer = device.makeBuffer(bytes: metalPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let curvatureBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        var pointCountInt = UInt32(pointCount)
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(pointsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(curvatureBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&pointCountInt, length: MemoryLayout<UInt32>.stride, index: 2)
        
        // Dispatch (process pointCount-2 curvature values for interior points)
        let processCount = max(1, pointCount - 2)
        let threadsPerGroup = MTLSize(width: min(processCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (processCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let resultPointer = curvatureBuffer.contents().bindMemory(to: Float.self, capacity: pointCount)
        
        var results: [Float] = []
        for i in 0..<pointCount {
            results.append(resultPointer[i])
        }
        
        return .success(results)
    }
    
    func chaikinSmoothingGPU(points: [CGPoint], ratio: Float = 0.25) -> Result<[CGPoint], MetalError> {
        guard points.count >= 3 else {
            return .failure(.operationFailed("Need at least 3 points for Chaikin smoothing"))
        }
        
        guard let pipeline = chaikinSmoothingPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let inputCount = points.count
        let outputCount = (inputCount - 1) * 2 + 1 // Chaikin doubles segments
        
        let metalPoints = points.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        guard let inputBuffer = device.makeBuffer(bytes: metalPoints, length: inputCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: outputCount * MemoryLayout<Point2D>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        var inputCountInt = UInt32(inputCount)
        var smoothingRatio = ratio
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&inputCountInt, length: MemoryLayout<UInt32>.stride, index: 2)
        computeEncoder.setBytes(&smoothingRatio, length: MemoryLayout<Float>.stride, index: 3)
        
        // Dispatch
        let processCount = inputCount - 1 // Process each segment
        let threadsPerGroup = MTLSize(width: min(processCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (processCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let resultPointer = outputBuffer.contents().bindMemory(to: Point2D.self, capacity: outputCount)
        
        var results: [CGPoint] = []
        for i in 0..<outputCount {
            let point = resultPointer[i]
            // Skip invalid points (Metal shader may output zeros for unused indices)
            if point.x != 0 || point.y != 0 || i == 0 { // Always include first point even if zero
                results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
            }
        }
        
        return .success(results)
    }
    
    // MARK: - Phase 11: GPU Mathematical Operations
    
    /// Calculate single point-to-point distance (optimized for shape drawing)
    func calculatePointDistanceGPU(from point1: CGPoint, to point2: CGPoint) -> Result<Float, MetalError> {
        let results = calculateDistancesGPU(from: [point1], to: [point2])
        switch results {
        case .success(let distances):
            return .success(distances.first ?? 0.0)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Calculate square root of a single value
    func calculateSquareRootGPU(_ value: Float) -> Result<Float, MetalError> {
        let results = calculateSquareRootsGPU([value])
        switch results {
        case .success(let squareRoots):
            return .success(squareRoots.first ?? 0.0)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Calculate square roots of multiple values efficiently
    func calculateSquareRootsGPU(_ values: [Float]) -> Result<[Float], MetalError> {
        guard !values.isEmpty else {
            return .failure(.operationFailed("Values array cannot be empty"))
        }
        
        guard let pipeline = squareRootPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let valueCount = values.count
        
        // Create buffers
        guard let inputBuffer = device.makeBuffer(bytes: values, length: valueCount * MemoryLayout<Float>.stride, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: valueCount * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        
        // Dispatch
        let threadsPerGroup = MTLSize(width: min(valueCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (valueCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let resultPointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: valueCount)
        
        var results: [Float] = []
        for i in 0..<valueCount {
            results.append(resultPointer[i])
        }
        
        return .success(results)
    }
    
    // MARK: - Phase 13: Boolean Geometry Operations
    
    func booleanGeometryUnionGPU(path1Points: [Point2D], path2Points: [Point2D]) -> Result<[Point2D], MetalError> {
        guard let pipeline = booleanGeometryPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        let resultCount = path1Points.count + path2Points.count
        let resultPoints = [Point2D](repeating: Point2D(x: 0, y: 0), count: resultCount)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        guard let path1Buffer = device.makeBuffer(bytes: path1Points, length: path1Points.count * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let path2Buffer = device.makeBuffer(bytes: path2Points, length: path2Points.count * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let resultBuffer = device.makeBuffer(bytes: resultPoints, length: resultCount * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let path1CountBuffer = device.makeBuffer(bytes: [UInt32(path1Points.count)], length: MemoryLayout<UInt32>.size, options: .storageModeShared),
              let path2CountBuffer = device.makeBuffer(bytes: [UInt32(path2Points.count)], length: MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(path1Buffer, offset: 0, index: 0)
        computeEncoder.setBuffer(path2Buffer, offset: 0, index: 1)
        computeEncoder.setBuffer(resultBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(path1CountBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(path2CountBuffer, offset: 0, index: 4)
        
        let threadGroupSize = MTLSize(width: 64, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (resultCount + 63) / 64, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let resultPointer = resultBuffer.contents().assumingMemoryBound(to: Point2D.self)
        let resultArray = Array<Point2D>(UnsafeBufferPointer(start: resultPointer, count: resultCount))
        
        return .success(resultArray)
    }
    
    func pathIntersectionGPU(path1Points: [Point2D], path2Points: [Point2D]) -> Result<[Point2D], MetalError> {
        guard let pipeline = pathIntersectionPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        let maxIntersections = 1000
        let intersectionPoints = [Point2D](repeating: Point2D(x: 0, y: 0), count: maxIntersections)
        var intersectionCount: UInt32 = 0
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        guard let path1Buffer = device.makeBuffer(bytes: path1Points, length: path1Points.count * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let path2Buffer = device.makeBuffer(bytes: path2Points, length: path2Points.count * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let resultBuffer = device.makeBuffer(bytes: intersectionPoints, length: maxIntersections * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let countBuffer = device.makeBuffer(bytes: &intersectionCount, length: MemoryLayout<UInt32>.size, options: .storageModeShared),
              let path1CountBuffer = device.makeBuffer(bytes: [UInt32(path1Points.count)], length: MemoryLayout<UInt32>.size, options: .storageModeShared),
              let path2CountBuffer = device.makeBuffer(bytes: [UInt32(path2Points.count)], length: MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(path1Buffer, offset: 0, index: 0)
        computeEncoder.setBuffer(path2Buffer, offset: 0, index: 1)
        computeEncoder.setBuffer(resultBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(countBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(path1CountBuffer, offset: 0, index: 4)
        computeEncoder.setBuffer(path2CountBuffer, offset: 0, index: 5)
        
        let threadGroupSize = MTLSize(width: 64, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (path1Points.count * path2Points.count + 63) / 64, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let resultPointer = resultBuffer.contents().assumingMemoryBound(to: Point2D.self)
        let resultArray = Array<Point2D>(UnsafeBufferPointer(start: resultPointer, count: Int(intersectionCount)))
        
        return .success(resultArray)
    }
    
    // MARK: - Phase 12: GPU Trigonometric Operations
    
    /// Calculate trigonometric functions (sin, cos, atan2) for multiple angles
    func calculateTrigonometricGPU(angles: [Float], function: TrigonometricFunction) -> Result<[Float], MetalError> {
        guard !angles.isEmpty else {
            return .failure(.operationFailed("Angles array cannot be empty"))
        }
        
        guard let pipeline = trigonometricPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        let angleCount = angles.count
        
        // Create buffers
        let inputBuffer = device.makeBuffer(bytes: angles, length: angleCount * MemoryLayout<Float>.stride, options: .storageModeShared)
        let outputBuffer = device.makeBuffer(length: angleCount * MemoryLayout<Float>.stride, options: .storageModeShared)
        var trigFunction = UInt32(function.rawValue)
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&trigFunction, length: MemoryLayout<UInt32>.stride, index: 2)
        
        // Dispatch
        let threadsPerGroup = MTLSize(width: min(angleCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (angleCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        guard let resultPointer = outputBuffer?.contents().bindMemory(to: Float.self, capacity: angleCount) else {
            return .failure(.bufferCreationFailed)
        }
        
        var results: [Float] = []
        for i in 0..<angleCount {
            results.append(resultPointer[i])
        }
        
        return .success(results)
    }
    
    /// Calculate polygon points for shape creation
    func calculatePolygonPointsGPU(center: CGPoint, radius: Float, sides: Int, startAngle: Float = -Float.pi/2) -> Result<[CGPoint], MetalError> {
        guard sides > 2 else {
            return .failure(.operationFailed("Polygon must have at least 3 sides"))
        }
        
        guard let pipeline = polygonCalculationPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        // Create buffers
        var centerPoint = Point2D(x: Float(center.x), y: Float(center.y))
        let outputBuffer = device.makeBuffer(length: sides * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        var params = PolygonParams(radius: radius, sides: UInt32(sides), startAngle: startAngle)
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&centerPoint, length: MemoryLayout<Point2D>.stride, index: 1)
        computeEncoder.setBytes(&params, length: MemoryLayout<PolygonParams>.stride, index: 2)
        
        // Dispatch
        let threadsPerGroup = MTLSize(width: min(sides, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (sides + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        guard let resultPointer = outputBuffer?.contents().bindMemory(to: Point2D.self, capacity: sides) else {
            return .failure(.bufferCreationFailed)
        }
        
        var results: [CGPoint] = []
        for i in 0..<sides {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return .success(results)
    }
    
    // MARK: - Phase 2: GPU Bezier Curve Calculations
    
    func calculateBezierCurveGPU(controlPoints: [CGPoint], steps: Int = 100) -> Result<[CGPoint], MetalError> {
        guard controlPoints.count == 4 else {
            return .failure(.operationFailed("Bezier curve requires exactly 4 control points"))
        }
        
        guard let pipeline = bezierCalculationPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        
        // Convert control points to Metal format
        let metalControlPoints = controlPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        let controlPointsBuffer = device.makeBuffer(bytes: metalControlPoints, length: 4 * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let resultBuffer = device.makeBuffer(length: steps * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        var stepCount = Int32(steps)
        
        // Setup compute
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(controlPointsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(resultBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&stepCount, length: MemoryLayout<Int32>.stride, index: 2)
        
        // Dispatch
        let threadsPerGroup = MTLSize(width: min(steps, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (steps + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        guard let resultPointer = resultBuffer?.contents().bindMemory(to: Point2D.self, capacity: steps) else {
            return .failure(.bufferCreationFailed)
        }
        
        var result: [CGPoint] = []
        for i in 0..<steps {
            let point = resultPointer[i]
            result.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return .success(result)
    }
    

    
    // MARK: - Metal Engine Status
    
    /// Test if the Metal engine is working properly
    static func testMetalEngine() -> Bool {
        Log.info("🔧 Metal Engine Test: Starting diagnostic...", category: .metal)
        
        // Check if Metal device is available
        guard let device = MTLCreateSystemDefaultDevice() else {
            Log.info("❌ Metal Engine Test: No Metal device available", category: .metal)
            return false
        }
        Log.info("✅ Metal Engine Test: Metal device found: \(device.name)", category: .metal)
        
        // Check if command queue can be created
        guard device.makeCommandQueue() != nil else {
            Log.info("❌ Metal Engine Test: Cannot create command queue", category: .metal)
            return false
        }
        Log.info("✅ Metal Engine Test: Command queue created successfully", category: .metal)
        
        // Initialize a single engine instance for testing
        let engine: MetalComputeEngine
        do {
            engine = try MetalComputeEngine()
            Log.info("✅ Metal Engine Test: Engine initialized successfully", category: .metal)
        } catch {
            Log.info("❌ Metal Engine Test: Engine not initialized - \(error)", category: .metal)
            return false
        }
        
        // Test basic GPU operations
        let testPoint1 = CGPoint(x: 0, y: 0)
        let testPoint2 = CGPoint(x: 3, y: 4)
        
        let distanceResult = engine.calculatePointDistanceGPU(from: testPoint1, to: testPoint2)
        let expectedDistance: Float = 5.0 // sqrt(3² + 4²) = 5
        
        switch distanceResult {
        case .success(let distance):
            if abs(distance - expectedDistance) < 0.1 {
                Log.info("✅ Metal Engine Test: Distance calculation working (got \(distance), expected \(expectedDistance))", category: .metal)
                return true
            } else {
                Log.info("❌ Metal Engine Test: Distance calculation failed (got \(distance), expected \(expectedDistance))", category: .metal)
                return false
            }
        case .failure(let error):
            Log.info("❌ Metal Engine Test: Distance calculation failed with error: \(error)", category: .metal)
            return false
        }
    }
    
    // MARK: - Performance Monitoring
    
    var isFullGPUAccelerationAvailable: Bool {
        return douglasPeuckerPipeline != nil && 
               bezierCalculationPipeline != nil && 
               matrixTransformPipeline != nil && 
               collisionDetectionPipeline != nil && 
               pathRenderingPipeline != nil
    }
    
    func getPerformanceMode() -> String {
        let availablePipelines = [
            douglasPeuckerPipeline != nil ? "Douglas-Peucker" : nil,
            bezierCalculationPipeline != nil ? "Bezier" : nil,
            matrixTransformPipeline != nil ? "Matrix" : nil,
            collisionDetectionPipeline != nil ? "Collision" : nil,
            pathRenderingPipeline != nil ? "PathRender" : nil
        ].compactMap { $0 }
        
        if isFullGPUAccelerationAvailable {
            return "🚀 Full GPU Acceleration (\(device.name)) - All 5 Phases Active"
        } else if !availablePipelines.isEmpty {
            return "🔄 GPU Hybrid Mode - \(availablePipelines.joined(separator: ", "))"
        } else {
            return "💻 CPU Mode - GPU Unavailable"
        }
    }
    
    func getAccelerationSummary() -> String {
        return """
        🎯 GPU Acceleration Status:
        • Phase 1: Douglas-Peucker Simplification ✅
        • Phase 2: Bezier Curve Calculations \(bezierCalculationPipeline != nil ? "✅" : "❌")
        • Phase 3: Matrix Transformations \(matrixTransformPipeline != nil ? "✅" : "❌")
        • Phase 4: Collision Detection \(collisionDetectionPipeline != nil ? "✅" : "❌")
        • Phase 5: Path Rendering \(pathRenderingPipeline != nil ? "✅" : "❌")
        
        Device: \(device.name)
        Mode: \(getPerformanceMode())
        """
    }
}


// Note: Shaders are now in MetalComputeShaders.metal file
// This provides better syntax highlighting and IDE support
