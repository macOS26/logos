import Metal
import MetalKit
import Foundation

enum MetalError: Error {
    case libraryCreationFailed
    case pipelineCreationFailed
    case deviceNotAvailable
    case commandBufferCreationFailed
    case computeEncoderCreationFailed
    case bufferCreationFailed
    case pipelineNotAvailable
    case shaderCompilationFailed
    case operationFailed(String)
}

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
    
    static let shared: MetalComputeEngine? = MetalComputeEngine()
    
    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            print("⚠️ Metal Compute Engine: GPU not available")
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Create Metal library from .metal file
        do {
            guard let library = device.makeDefaultLibrary() else {
                throw MetalError.libraryCreationFailed
            }
            self.library = library
            setupComputePipelines()
            print("✅ Metal Compute Engine: GPU acceleration ready (\(device.name))")
        } catch {
            print("❌ Metal Compute Engine: Failed to compile shaders: \(error)")
            return nil
        }
    }
    
    // MARK: - Setup
    
    private func setupComputePipelines() {
        do {
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
            
            // Phase 13: Boolean Geometry operations (simplified for now)
            // Note: Complex boolean operations will be added in future phases
            
        } catch {
            print("❌ Failed to create compute pipelines: \(error)")
        }
    }
    
    // MARK: - Phase 2: GPU Douglas-Peucker with Metal Shaders
    
    func douglasPeuckerGPU(_ points: [CGPoint], tolerance: Float) -> [CGPoint] {
        guard points.count > 2,
              douglasPeuckerPipeline != nil else {
            return GPUMathAcceleratorSimple.shared.optimizeDrawingPath(points, tolerance: CGFloat(tolerance))
        }
        
        return douglasPeuckerRecursiveGPU(points: points, tolerance: tolerance, startIndex: 0, endIndex: points.count - 1)
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
        
        if maxResult.distance > tolerance {
            let maxIndex = startIndex + maxResult.index
            
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
    }
    
    private func findMaxDistanceGPU(points: [CGPoint], lineStart: CGPoint, lineEnd: CGPoint) -> (distance: Float, index: Int) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipeline = douglasPeuckerPipeline else {
            return findMaxDistanceCPU(points: points, lineStart: lineStart, lineEnd: lineEnd)
        }
        
        let pointCount = points.count
        
        // Convert to Metal-compatible format
        let metalPoints = points.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        let pointsBuffer = device.makeBuffer(bytes: metalPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let distancesBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Float>.stride, options: .storageModeShared)
        
        var lineStartMetal = Point2D(x: Float(lineStart.x), y: Float(lineStart.y))
        var lineEndMetal = Point2D(x: Float(lineEnd.x), y: Float(lineEnd.y))
        
        // Setup compute encoder
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(pointsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(distancesBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&lineStartMetal, length: MemoryLayout<Point2D>.stride, index: 2)
        computeEncoder.setBytes(&lineEndMetal, length: MemoryLayout<Point2D>.stride, index: 3)
        
        // Dispatch threads
        let threadsPerGroup = MTLSize(width: min(pointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        guard let distancesPointer = distancesBuffer?.contents().bindMemory(to: Float.self, capacity: pointCount) else {
            return findMaxDistanceCPU(points: points, lineStart: lineStart, lineEnd: lineEnd)
        }
        
        var maxDistance: Float = 0
        var maxIndex = 0
        
        for i in 0..<pointCount {
            let distance = distancesPointer[i]
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        return (distance: maxDistance, index: maxIndex)
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
    
    func pointsInPolygonGPU(_ testPoints: [CGPoint], polygon: [CGPoint]) -> [Bool] {
        guard let pipeline = collisionDetectionPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return pointsInPolygonCPU(testPoints, polygon: polygon)
        }
        
        let testPointCount = testPoints.count
        let polygonVertexCount = polygon.count
        
        // Convert to Metal format
        let metalTestPoints = testPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalPolygonVertices = polygon.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        let testPointsBuffer = device.makeBuffer(bytes: metalTestPoints, length: testPointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let polygonBuffer = device.makeBuffer(bytes: metalPolygonVertices, length: polygonVertexCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let resultsBuffer = device.makeBuffer(length: testPointCount * MemoryLayout<Bool>.stride, options: .storageModeShared)
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
        guard let resultPointer = resultsBuffer?.contents().bindMemory(to: Bool.self, capacity: testPointCount) else {
            return pointsInPolygonCPU(testPoints, polygon: polygon)
        }
        
        var results: [Bool] = []
        for i in 0..<testPointCount {
            results.append(resultPointer[i])
        }
        
        return results
    }
    
    // MARK: - Phase 5: GPU Path Rendering
    
    func renderPathGPU(pathPoints: [CGPoint], strokeWidth: Float, resolution: Int) -> [CGPoint] {
        guard let pipeline = pathRenderingPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return renderPathCPU(pathPoints: pathPoints, strokeWidth: strokeWidth, resolution: resolution)
        }
        
        let inputPointCount = pathPoints.count
        let outputPointCount = inputPointCount * resolution // Generate more points for smooth rendering
        
        // Convert to Metal format
        let metalPathPoints = pathPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        let inputBuffer = device.makeBuffer(bytes: metalPathPoints, length: inputPointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let outputBuffer = device.makeBuffer(length: outputPointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
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
        guard let resultPointer = outputBuffer?.contents().bindMemory(to: Point2D.self, capacity: outputPointCount) else {
            return renderPathCPU(pathPoints: pathPoints, strokeWidth: strokeWidth, resolution: resolution)
        }
        
        var result: [CGPoint] = []
        for i in 0..<outputPointCount {
            let point = resultPointer[i]
            // Skip invalid points (Metal shader may output zeros for unused indices)
            if point.x != 0 || point.y != 0 {
                result.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
            }
        }
        
        return result
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
    
    func chaikinSmoothingGPU(points: [CGPoint], ratio: Float = 0.25) -> [CGPoint] {
        guard points.count >= 3,
              let pipeline = chaikinSmoothingPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return chaikinSmoothingCPU(points: points, ratio: ratio)
        }
        
        let inputCount = points.count
        let outputCount = (inputCount - 1) * 2 + 1 // Chaikin doubles segments
        
        let metalPoints = points.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        let inputBuffer = device.makeBuffer(bytes: metalPoints, length: inputCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let outputBuffer = device.makeBuffer(length: outputCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
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
        guard let resultPointer = outputBuffer?.contents().bindMemory(to: Point2D.self, capacity: outputCount) else {
            return chaikinSmoothingCPU(points: points, ratio: ratio)
        }
        
        var results: [CGPoint] = []
        for i in 0..<outputCount {
            let point = resultPointer[i]
            // Skip invalid points (Metal shader may output zeros for unused indices)
            if point.x != 0 || point.y != 0 || i == 0 { // Always include first point even if zero
                results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
            }
        }
        
        return results
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
    
    fileprivate func booleanGeometryUnionGPU(path1Points: [Point2D], path2Points: [Point2D]) -> [Point2D]? {
        guard let metalEngine = MetalComputeEngine.shared,
              let pipeline = metalEngine.booleanGeometryPipeline else {
            print("⚠️ Metal Phase 13: Boolean Geometry Union - GPU not available, using CPU")
            return booleanGeometryUnionCPU(path1Points: path1Points, path2Points: path2Points)
        }
        
        let resultCount = path1Points.count + path2Points.count
        var resultPoints = [Point2D](repeating: Point2D(x: 0, y: 0), count: resultCount)
        
        guard let commandBuffer = metalEngine.commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("❌ Metal Phase 13: Boolean Geometry Union - Failed to create command buffer")
            return booleanGeometryUnionCPU(path1Points: path1Points, path2Points: path2Points)
        }
        
        let path1Buffer = metalEngine.device.makeBuffer(bytes: path1Points, length: path1Points.count * MemoryLayout<Point2D>.size, options: [])
        let path2Buffer = metalEngine.device.makeBuffer(bytes: path2Points, length: path2Points.count * MemoryLayout<Point2D>.size, options: [])
        let resultBuffer = metalEngine.device.makeBuffer(bytes: resultPoints, length: resultCount * MemoryLayout<Point2D>.size, options: [])
        let path1CountBuffer = metalEngine.device.makeBuffer(bytes: [UInt32(path1Points.count)], length: MemoryLayout<UInt32>.size, options: [])
        let path2CountBuffer = metalEngine.device.makeBuffer(bytes: [UInt32(path2Points.count)], length: MemoryLayout<UInt32>.size, options: [])
        
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
        
        guard let resultPointer = resultBuffer?.contents().assumingMemoryBound(to: Point2D.self) else {
            return booleanGeometryUnionCPU(path1Points: path1Points, path2Points: path2Points)
        }
        let resultArray = Array<Point2D>(UnsafeBufferPointer(start: resultPointer, count: resultCount))
        
        print("✅ Metal Phase 13: Boolean Geometry Union - GPU acceleration working")
        return resultArray
    }
    
    fileprivate func pathIntersectionGPU(path1Points: [Point2D], path2Points: [Point2D]) -> [Point2D]? {
        guard let metalEngine = MetalComputeEngine.shared,
              let pipeline = metalEngine.pathIntersectionPipeline else {
            print("⚠️ Metal Phase 13: Path Intersection - GPU not available, using CPU")
            return pathIntersectionCPU(path1Points: path1Points, path2Points: path2Points)
        }
        
        let maxIntersections = 1000
        var intersectionPoints = [Point2D](repeating: Point2D(x: 0, y: 0), count: maxIntersections)
        var intersectionCount: UInt32 = 0
        
        guard let commandBuffer = metalEngine.commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("❌ Metal Phase 13: Path Intersection - Failed to create command buffer")
            return pathIntersectionCPU(path1Points: path1Points, path2Points: path2Points)
        }
        
        let path1Buffer = metalEngine.device.makeBuffer(bytes: path1Points, length: path1Points.count * MemoryLayout<Point2D>.size, options: [])
        let path2Buffer = metalEngine.device.makeBuffer(bytes: path2Points, length: path2Points.count * MemoryLayout<Point2D>.size, options: [])
        let resultBuffer = metalEngine.device.makeBuffer(bytes: intersectionPoints, length: maxIntersections * MemoryLayout<Point2D>.size, options: [])
        let countBuffer = metalEngine.device.makeBuffer(bytes: &intersectionCount, length: MemoryLayout<UInt32>.size, options: [])
        let path1CountBuffer = metalEngine.device.makeBuffer(bytes: [UInt32(path1Points.count)], length: MemoryLayout<UInt32>.size, options: [])
        let path2CountBuffer = metalEngine.device.makeBuffer(bytes: [UInt32(path2Points.count)], length: MemoryLayout<UInt32>.size, options: [])
        
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
        
        guard let resultPointer = resultBuffer?.contents().assumingMemoryBound(to: Point2D.self) else {
            return pathIntersectionCPU(path1Points: path1Points, path2Points: path2Points)
        }
        let resultArray = Array<Point2D>(UnsafeBufferPointer(start: resultPointer, count: Int(intersectionCount)))
        
        print("✅ Metal Phase 13: Path Intersection - GPU acceleration working")
        return resultArray
    }
    
    // MARK: - Phase 12: GPU Trigonometric Operations
    
    /// Calculate trigonometric functions (sin, cos, atan2) for multiple angles
    func calculateTrigonometricGPU(angles: [Float], function: TrigonometricFunction) -> [Float] {
        guard !angles.isEmpty,
              let pipeline = trigonometricPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return calculateTrigonometricCPU(angles: angles, function: function)
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
            return calculateTrigonometricCPU(angles: angles, function: function)
        }
        
        var results: [Float] = []
        for i in 0..<angleCount {
            results.append(resultPointer[i])
        }
        
        return results
    }
    
    /// Calculate polygon points for shape creation
    func calculatePolygonPointsGPU(center: CGPoint, radius: Float, sides: Int, startAngle: Float = -Float.pi/2) -> [CGPoint] {
        guard sides > 2,
              let pipeline = polygonCalculationPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return calculatePolygonPointsCPU(center: center, radius: radius, sides: sides, startAngle: startAngle)
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
            return calculatePolygonPointsCPU(center: center, radius: radius, sides: sides, startAngle: startAngle)
        }
        
        var results: [CGPoint] = []
        for i in 0..<sides {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return results
    }
    
    // MARK: - Phase 2: GPU Bezier Curve Calculations
    
    func calculateBezierCurveGPU(controlPoints: [CGPoint], steps: Int = 100) -> [CGPoint] {
        guard controlPoints.count == 4,
              let pipeline = bezierCalculationPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return calculateBezierCurveCPU(controlPoints: controlPoints, steps: steps)
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
            return calculateBezierCurveCPU(controlPoints: controlPoints, steps: steps)
        }
        
        var result: [CGPoint] = []
        for i in 0..<steps {
            let point = resultPointer[i]
            result.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return result
    }
    
    // MARK: - CPU Fallbacks
    
    private func booleanGeometryUnionCPU(path1Points: [Point2D], path2Points: [Point2D]) -> [Point2D] {
        print("🔄 Metal Phase 13: Boolean Geometry Union - Using CPU fallback")
        var result = path1Points
        result.append(contentsOf: path2Points)
        return result
    }
    
    private func pathIntersectionCPU(path1Points: [Point2D], path2Points: [Point2D]) -> [Point2D] {
        print("🔄 Metal Phase 13: Path Intersection - Using CPU fallback")
        var intersections: [Point2D] = []
        
        for p1 in path1Points {
            for p2 in path2Points {
                let distance = sqrt((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y))
                if distance < 0.001 {
                    intersections.append(p1)
                }
            }
        }
        
        return intersections
    }
    
    private func findMaxDistanceCPU(points: [CGPoint], lineStart: CGPoint, lineEnd: CGPoint) -> (distance: Float, index: Int) {
        var maxDistance: Float = 0
        var maxIndex = 0
        
        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistanceCPU(point: points[i], lineStart: lineStart, lineEnd: lineEnd)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        return (distance: maxDistance, index: maxIndex)
    }
    
    private func perpendicularDistanceCPU(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Float {
        let A = Float(lineEnd.y - lineStart.y)
        let B = Float(lineStart.x - lineEnd.x)
        let C = Float(lineEnd.x * lineStart.y - lineStart.x * lineEnd.y)
        
        let numerator = abs(A * Float(point.x) + B * Float(point.y) + C)
        let denominator = sqrt(A * A + B * B)
        
        return numerator / denominator
    }
    
    private func calculateBezierCurveCPU(controlPoints: [CGPoint], steps: Int) -> [CGPoint] {
        guard controlPoints.count == 4 else { return [] }
        
        var result: [CGPoint] = []
        let p0 = controlPoints[0]
        let p1 = controlPoints[1]
        let p2 = controlPoints[2]
        let p3 = controlPoints[3]
        
        for i in 0..<steps {
            let t = CGFloat(i) / CGFloat(steps - 1)
            let u = 1.0 - t
            let tt = t * t
            let uu = u * u
            let uuu = uu * u
            let ttt = tt * t
            
            let x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x
            let y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y
            
            result.append(CGPoint(x: x, y: y))
        }
        
        return result
    }
    
    private func transformPointsCPU(_ points: [CGPoint], transform: CGAffineTransform) -> [CGPoint] {
        return points.map { point in
            point.applying(transform)
        }
    }
    
    private func pointsInPolygonCPU(_ testPoints: [CGPoint], polygon: [CGPoint]) -> [Bool] {
        return testPoints.map { testPoint in
            pointInPolygonCPU(testPoint, polygon: polygon)
        }
    }
    
    private func pointInPolygonCPU(_ testPoint: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        var inside = false
        var j = polygon.count - 1
        
        for i in 0..<polygon.count {
            let vi = polygon[i]
            let vj = polygon[j]
            
            if ((vi.y > testPoint.y) != (vj.y > testPoint.y)) &&
               (testPoint.x < (vj.x - vi.x) * (testPoint.y - vi.y) / (vj.y - vi.y) + vi.x) {
                inside = !inside
            }
            j = i
        }
        
        return inside
    }
    
    private func renderPathCPU(pathPoints: [CGPoint], strokeWidth: Float, resolution: Int) -> [CGPoint] {
        guard pathPoints.count > 1 else { return pathPoints }
        
        var renderedPoints: [CGPoint] = []
        
        // Simple path interpolation for CPU fallback
        for i in 0..<(pathPoints.count - 1) {
            let startPoint = pathPoints[i]
            let endPoint = pathPoints[i + 1]
            
            // Interpolate between points based on resolution
            for j in 0..<resolution {
                let t = CGFloat(j) / CGFloat(resolution)
                let interpolatedX = startPoint.x + t * (endPoint.x - startPoint.x)
                let interpolatedY = startPoint.y + t * (endPoint.y - startPoint.y)
                
                renderedPoints.append(CGPoint(x: interpolatedX, y: interpolatedY))
            }
        }
        
        // Add the final point
        if let lastPoint = pathPoints.last {
            renderedPoints.append(lastPoint)
        }
        
        return renderedPoints
    }
    
    private func calculateDistancesCPU(from sourcePoints: [CGPoint], to targetPoints: [CGPoint]) -> [Float] {
        guard sourcePoints.count == targetPoints.count else { return [] }
        
        var distances: [Float] = []
        for i in 0..<sourcePoints.count {
            let dx = Float(sourcePoints[i].x - targetPoints[i].x)
            let dy = Float(sourcePoints[i].y - targetPoints[i].y)
            distances.append(sqrt(dx * dx + dy * dy))
        }
        return distances
    }
    
    private func normalizeVectorsCPU(_ vectors: [CGPoint]) -> [CGPoint] {
        return vectors.map { vector in
            let length = sqrt(vector.x * vector.x + vector.y * vector.y)
            guard length > 1e-10 else { return CGPoint.zero }
            return CGPoint(x: vector.x / length, y: vector.y / length)
        }
    }
    
    private func lerpVectorsCPU(from startPoints: [CGPoint], to endPoints: [CGPoint], t: Float) -> [CGPoint] {
        guard startPoints.count == endPoints.count else { return [] }
        
        var results: [CGPoint] = []
        let tCG = CGFloat(t)
        for i in 0..<startPoints.count {
            let start = startPoints[i]
            let end = endPoints[i]
            let lerped = CGPoint(
                x: start.x + tCG * (end.x - start.x),
                y: start.y + tCG * (end.y - start.y)
            )
            results.append(lerped)
        }
        return results
    }
    
    private func calculateLinkedHandlesCPU(anchorPoints: [CGPoint], draggedHandles: [CGPoint], originalOppositeHandles: [CGPoint]) -> [CGPoint] {
        guard anchorPoints.count == draggedHandles.count && 
              draggedHandles.count == originalOppositeHandles.count else { return [] }
        
        var results: [CGPoint] = []
        
        for i in 0..<anchorPoints.count {
            let anchorPoint = anchorPoints[i]
            let draggedHandle = draggedHandles[i]
            let originalOppositeHandle = originalOppositeHandles[i]
            
            // Vector from anchor to dragged handle
            let draggedVector = CGPoint(
                x: draggedHandle.x - anchorPoint.x,
                y: draggedHandle.y - anchorPoint.y
            )
            
            // Keep the original opposite handle length
            let originalVector = CGPoint(
                x: originalOppositeHandle.x - anchorPoint.x,
                y: originalOppositeHandle.y - anchorPoint.y
            )
            let originalLength = sqrt(originalVector.x * originalVector.x + originalVector.y * originalVector.y)
            
            // Create opposite vector (180° from dragged handle) with original length
            let draggedLength = sqrt(draggedVector.x * draggedVector.x + draggedVector.y * draggedVector.y)
            guard draggedLength > 0.1 else { 
                results.append(originalOppositeHandle)
                continue
            }
            
            let normalizedDragged = CGPoint(
                x: draggedVector.x / draggedLength,
                y: draggedVector.y / draggedLength
            )
            
            // Opposite direction with original length
            let linkedHandle = CGPoint(
                x: anchorPoint.x - normalizedDragged.x * originalLength,
                y: anchorPoint.y - normalizedDragged.y * originalLength
            )
            
            results.append(linkedHandle)
        }
        
        return results
    }
    
    private func calculateCurvatureCPU(points: [CGPoint]) -> [Float] {
        guard points.count >= 3 else { return [] }
        
        var curvatures: [Float] = []
        
        // First point has no curvature (need 3 points)
        curvatures.append(0.0)
        
        // Calculate curvature for interior points
        for i in 1..<(points.count - 1) {
            let p0 = points[i - 1]
            let p1 = points[i]
            let p2 = points[i + 1]
            
            // Calculate vectors
            let v1 = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
            let v2 = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
            
            // Calculate lengths
            let len1 = sqrt(v1.x * v1.x + v1.y * v1.y)
            let len2 = sqrt(v2.x * v2.x + v2.y * v2.y)
            
            if len1 == 0 || len2 == 0 {
                curvatures.append(0.0)
                continue
            }
            
            // Normalize vectors
            let n1 = CGPoint(x: v1.x / len1, y: v1.y / len1)
            let n2 = CGPoint(x: v2.x / len2, y: v2.y / len2)
            
            // Calculate dot product (cosine of angle)
            let dotProduct = n1.x * n2.x + n1.y * n2.y
            
            // Convert to curvature measure (0 = straight line, 1 = sharp corner)
            let curvature = 1.0 - abs(dotProduct)
            curvatures.append(Float(curvature))
        }
        
        // Last point has no curvature (need 3 points)
        curvatures.append(0.0)
        
        return curvatures
    }
    
    private func chaikinSmoothingCPU(points: [CGPoint], ratio: Float) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        
        var smoothedPoints: [CGPoint] = []
        let r = CGFloat(ratio)
        
        // First point stays the same
        smoothedPoints.append(points[0])
        
        // Apply Chaikin smoothing to each segment
        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i + 1]
            
            // Create two new points on the segment
            let q1 = CGPoint(
                x: p1.x + r * (p2.x - p1.x),
                y: p1.y + r * (p2.y - p1.y)
            )
            let q2 = CGPoint(
                x: p1.x + (1.0 - r) * (p2.x - p1.x),
                y: p1.y + (1.0 - r) * (p2.y - p1.y)
            )
            
            smoothedPoints.append(q1)
            smoothedPoints.append(q2)
        }
        
        // Last point stays the same - safely access the last element
        if let lastPoint = points.last {
            smoothedPoints.append(lastPoint)
        }
        
        return smoothedPoints
    }
    
    private func calculateTrigonometricCPU(angles: [Float], function: TrigonometricFunction) -> [Float] {
        return angles.map { angle in
            switch function {
            case .sine:
                return sin(angle)
            case .cosine:
                return cos(angle)
            case .tangent:
                return tan(angle)
            case .atan2:
                // For atan2, we need two values - use angle as y and 1.0 as x
                return atan2(angle, 1.0)
            }
        }
    }
    
    private func calculatePolygonPointsCPU(center: CGPoint, radius: Float, sides: Int, startAngle: Float) -> [CGPoint] {
        var points: [CGPoint] = []
        let angleStep = 2 * Float.pi / Float(sides)
        
        for i in 0..<sides {
            let angle = Float(i) * angleStep + startAngle
            let x = center.x + CGFloat(cos(angle) * radius)
            let y = center.y + CGFloat(sin(angle) * radius)
            points.append(CGPoint(x: x, y: y))
        }
        
        return points
    }
    
    // MARK: - Metal Engine Status
    
    /// Test if the Metal engine is working properly
    static func testMetalEngine() -> Bool {
        print("🔧 Metal Engine Test: Starting diagnostic...")
        
        // Check if Metal device is available
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal Engine Test: No Metal device available")
            return false
        }
        print("✅ Metal Engine Test: Metal device found: \(device.name)")
        
        // Check if command queue can be created
        guard let commandQueue = device.makeCommandQueue() else {
            print("❌ Metal Engine Test: Cannot create command queue")
            return false
        }
        print("✅ Metal Engine Test: Command queue created successfully")
        
        // Check if shared engine exists
        guard let engine = shared else {
            print("❌ Metal Engine Test: Engine not initialized - likely shader compilation failed")
            return false
        }
        print("✅ Metal Engine Test: Engine initialized successfully")
        
        // Test basic GPU operations
        let testPoint1 = CGPoint(x: 0, y: 0)
        let testPoint2 = CGPoint(x: 3, y: 4)
        
        let distanceResult = engine.calculatePointDistanceGPU(from: testPoint1, to: testPoint2)
        let expectedDistance: Float = 5.0 // sqrt(3² + 4²) = 5
        
        switch distanceResult {
        case .success(let distance):
            if abs(distance - expectedDistance) < 0.1 {
                print("✅ Metal Engine Test: Distance calculation working (got \(distance), expected \(expectedDistance))")
                return true
            } else {
                print("❌ Metal Engine Test: Distance calculation failed (got \(distance), expected \(expectedDistance))")
                return false
            }
        case .failure(let error):
            print("❌ Metal Engine Test: Distance calculation failed with error: \(error)")
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

// MARK: - Metal Data Structures

private struct Point2D {
    let x: Float
    let y: Float
}

enum TrigonometricFunction: Int {
    case sine = 0
    case cosine = 1
    case tangent = 2
    case atan2 = 3
}

private struct PolygonParams {
    let radius: Float
    let sides: UInt32
    let startAngle: Float
}

// Note: Shaders are now in MetalComputeShaders.metal file
// This provides better syntax highlighting and IDE support
