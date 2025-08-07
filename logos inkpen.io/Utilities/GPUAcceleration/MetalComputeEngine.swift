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
    
    static let shared: MetalComputeEngine? = MetalComputeEngine()
    
    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            print("⚠️ Metal Compute Engine: GPU not available")
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Create Metal library from source
        let shaderSource = Self.createMetalShaderSource()
        
        do {
            self.library = try device.makeLibrary(source: shaderSource, options: nil)
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
    
    func transformPointsGPU(_ points: [CGPoint], transform: CGAffineTransform) -> [CGPoint] {
        guard let pipeline = matrixTransformPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return transformPointsCPU(points, transform: transform)
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
        let inputBuffer = device.makeBuffer(bytes: metalPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let outputBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let transformBuffer = device.makeBuffer(bytes: transformMatrix, length: 9 * MemoryLayout<Float>.stride, options: .storageModeShared)
        
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
        guard let resultPointer = outputBuffer?.contents().bindMemory(to: Point2D.self, capacity: pointCount) else {
            return transformPointsCPU(points, transform: transform)
        }
        
        var result: [CGPoint] = []
        for i in 0..<pointCount {
            let point = resultPointer[i]
            result.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return result
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
    
    func calculateDistancesGPU(from sourcePoints: [CGPoint], to targetPoints: [CGPoint]) -> [Float] {
        guard sourcePoints.count == targetPoints.count,
              let pipeline = vectorDistancePipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return calculateDistancesCPU(from: sourcePoints, to: targetPoints)
        }
        
        let pointCount = sourcePoints.count
        let metalSourcePoints = sourcePoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalTargetPoints = targetPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        let sourceBuffer = device.makeBuffer(bytes: metalSourcePoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let targetBuffer = device.makeBuffer(bytes: metalTargetPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let distanceBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Float>.stride, options: .storageModeShared)
        
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
        guard let resultPointer = distanceBuffer?.contents().bindMemory(to: Float.self, capacity: pointCount) else {
            return calculateDistancesCPU(from: sourcePoints, to: targetPoints)
        }
        
        var results: [Float] = []
        for i in 0..<pointCount {
            results.append(resultPointer[i])
        }
        
        return results
    }
    
    func normalizeVectorsGPU(_ vectors: [CGPoint]) -> [CGPoint] {
        guard let pipeline = vectorNormalizePipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return normalizeVectorsCPU(vectors)
        }
        
        let vectorCount = vectors.count
        let metalVectors = vectors.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        let inputBuffer = device.makeBuffer(bytes: metalVectors, length: vectorCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let outputBuffer = device.makeBuffer(length: vectorCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        
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
        guard let resultPointer = outputBuffer?.contents().bindMemory(to: Point2D.self, capacity: vectorCount) else {
            return normalizeVectorsCPU(vectors)
        }
        
        var results: [CGPoint] = []
        for i in 0..<vectorCount {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return results
    }
    
    func lerpVectorsGPU(from startPoints: [CGPoint], to endPoints: [CGPoint], t: Float) -> [CGPoint] {
        guard startPoints.count == endPoints.count,
              let pipeline = vectorLerpPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return lerpVectorsCPU(from: startPoints, to: endPoints, t: t)
        }
        
        let pointCount = startPoints.count
        let metalStartPoints = startPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalEndPoints = endPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        let startBuffer = device.makeBuffer(bytes: metalStartPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let endBuffer = device.makeBuffer(bytes: metalEndPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let outputBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
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
        guard let resultPointer = outputBuffer?.contents().bindMemory(to: Point2D.self, capacity: pointCount) else {
            return lerpVectorsCPU(from: startPoints, to: endPoints, t: t)
        }
        
        var results: [CGPoint] = []
        for i in 0..<pointCount {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return results
    }
    
    // MARK: - Phase 7: GPU Handle Calculations
    
    func calculateLinkedHandlesGPU(anchorPoints: [CGPoint], draggedHandles: [CGPoint], originalOppositeHandles: [CGPoint]) -> [CGPoint] {
        guard anchorPoints.count == draggedHandles.count && 
              draggedHandles.count == originalOppositeHandles.count,
              let pipeline = handleCalculationPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return calculateLinkedHandlesCPU(anchorPoints: anchorPoints, draggedHandles: draggedHandles, originalOppositeHandles: originalOppositeHandles)
        }
        
        let pointCount = anchorPoints.count
        let metalAnchorPoints = anchorPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalDraggedHandles = draggedHandles.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalOriginalHandles = originalOppositeHandles.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        let anchorBuffer = device.makeBuffer(bytes: metalAnchorPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let draggedBuffer = device.makeBuffer(bytes: metalDraggedHandles, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let originalBuffer = device.makeBuffer(bytes: metalOriginalHandles, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let outputBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        
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
        guard let resultPointer = outputBuffer?.contents().bindMemory(to: Point2D.self, capacity: pointCount) else {
            return calculateLinkedHandlesCPU(anchorPoints: anchorPoints, draggedHandles: draggedHandles, originalOppositeHandles: originalOppositeHandles)
        }
        
        var results: [CGPoint] = []
        for i in 0..<pointCount {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        return results
    }
    
    // MARK: - Phase 10: GPU Curve Smoothing and Curvature
    
    func calculateCurvatureGPU(points: [CGPoint]) -> [Float] {
        guard points.count >= 3,
              let pipeline = curvatureCalculationPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return calculateCurvatureCPU(points: points)
        }
        
        let pointCount = points.count
        let metalPoints = points.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        
        // Create buffers
        let pointsBuffer = device.makeBuffer(bytes: metalPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let curvatureBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Float>.stride, options: .storageModeShared)
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
        guard let resultPointer = curvatureBuffer?.contents().bindMemory(to: Float.self, capacity: pointCount) else {
            return calculateCurvatureCPU(points: points)
        }
        
        var results: [Float] = []
        for i in 0..<pointCount {
            results.append(resultPointer[i])
        }
        
        return results
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
    func calculatePointDistanceGPU(from point1: CGPoint, to point2: CGPoint) -> Float {
        let results = calculateDistancesGPU(from: [point1], to: [point2])
        return results.first ?? 0.0
    }
    
    /// Calculate square root of a single value
    func calculateSquareRootGPU(_ value: Float) -> Float {
        let results = calculateSquareRootsGPU([value])
        return results.first ?? 0.0
    }
    
    /// Calculate square roots of multiple values efficiently
    func calculateSquareRootsGPU(_ values: [Float]) -> [Float] {
        guard !values.isEmpty,
              let pipeline = squareRootPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return values.map { sqrt($0) }
        }
        
        let valueCount = values.count
        
        // Create buffers
        let inputBuffer = device.makeBuffer(bytes: values, length: valueCount * MemoryLayout<Float>.stride, options: .storageModeShared)
        let outputBuffer = device.makeBuffer(length: valueCount * MemoryLayout<Float>.stride, options: .storageModeShared)
        
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
        guard let resultPointer = outputBuffer?.contents().bindMemory(to: Float.self, capacity: valueCount) else {
            return values.map { sqrt($0) }
        }
        
        var results: [Float] = []
        for i in 0..<valueCount {
            results.append(resultPointer[i])
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
        
        // Last point stays the same
        smoothedPoints.append(points.last!)
        
        return smoothedPoints
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

// MARK: - Metal Shader Source (Phase 2)

extension MetalComputeEngine {
    
    static func createMetalShaderSource() -> String {
        return """
        #include <metal_stdlib>
        using namespace metal;
        
        struct Point2D {
            float x;
            float y;
        };
        
        // Phase 2: Douglas-Peucker distance calculation
        kernel void calculate_distances(
            device const Point2D* points [[buffer(0)]],
            device float* distances [[buffer(1)]],
            constant Point2D& lineStart [[buffer(2)]],
            constant Point2D& lineEnd [[buffer(3)]],
            uint index [[thread_position_in_grid]]
        ) {
            Point2D point = points[index];
            
            float A = lineEnd.y - lineStart.y;
            float B = lineStart.x - lineEnd.x;
            float C = lineEnd.x * lineStart.y - lineStart.x * lineEnd.y;
            
            float numerator = abs(A * point.x + B * point.y + C);
            float denominator = sqrt(A * A + B * B);
            
            distances[index] = numerator / denominator;
        }
        
        // Phase 2: Bezier curve calculation
        kernel void calculate_bezier_curves(
            device const Point2D* controlPoints [[buffer(0)]],
            device Point2D* results [[buffer(1)]],
            constant int& steps [[buffer(2)]],
            uint index [[thread_position_in_grid]]
        ) {
            if (index >= uint(steps)) return;
            
            float t = float(index) / float(steps - 1);
            float u = 1.0 - t;
            float tt = t * t;
            float uu = u * u;
            float uuu = uu * u;
            float ttt = tt * t;
            
            Point2D p0 = controlPoints[0];
            Point2D p1 = controlPoints[1];
            Point2D p2 = controlPoints[2];
            Point2D p3 = controlPoints[3];
            
            Point2D result;
            result.x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x;
            result.y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y;
            
            results[index] = result;
        }
        
        // Phase 3: Matrix transformations
        kernel void transform_points(
            device const Point2D* inputPoints [[buffer(0)]],
            device Point2D* outputPoints [[buffer(1)]],
            constant float* transform [[buffer(2)]],
            uint index [[thread_position_in_grid]]
        ) {
            Point2D input = inputPoints[index];
            
            // Apply 2D transformation matrix (3x3 in column-major order)
            float x = transform[0] * input.x + transform[3] * input.y + transform[6];
            float y = transform[1] * input.x + transform[4] * input.y + transform[7];
            
            outputPoints[index] = {x, y};
        }
        
        // Phase 4: Point-in-polygon collision detection
        kernel void point_in_polygon(
            device const Point2D* testPoints [[buffer(0)]],
            device const Point2D* polygonVertices [[buffer(1)]],
            device bool* results [[buffer(2)]],
            constant uint& vertexCount [[buffer(3)]],
            uint index [[thread_position_in_grid]]
        ) {
            Point2D testPoint = testPoints[index];
            bool inside = false;
            
            // Ray casting algorithm optimized for GPU
            for (uint i = 0, j = vertexCount - 1; i < vertexCount; j = i++) {
                Point2D vi = polygonVertices[i];
                Point2D vj = polygonVertices[j];
                
                if (((vi.y > testPoint.y) != (vj.y > testPoint.y)) &&
                    (testPoint.x < (vj.x - vi.x) * (testPoint.y - vi.y) / (vj.y - vi.y) + vi.x)) {
                    inside = !inside;
                }
            }
            
            results[index] = inside;
        }
        
        // Phase 5: GPU Path Rendering with interpolation
        kernel void render_path_points(
            device const Point2D* inputPoints [[buffer(0)]],
            device Point2D* outputPoints [[buffer(1)]],
            constant float& strokeWidth [[buffer(2)]],
            constant uint& resolution [[buffer(3)]],
            constant uint& inputCount [[buffer(4)]],
            uint index [[thread_position_in_grid]]
        ) {
            uint totalOutputPoints = (inputCount - 1) * resolution + 1;
            if (index >= totalOutputPoints) return;
            
            // Find which segment this output point belongs to
            uint segmentIndex = index / resolution;
            uint localIndex = index % resolution;
            
            if (segmentIndex >= inputCount - 1) {
                // Last point case
                outputPoints[index] = inputPoints[inputCount - 1];
                return;
            }
            
            Point2D startPoint = inputPoints[segmentIndex];
            Point2D endPoint = inputPoints[segmentIndex + 1];
            
            // Interpolate between start and end points
            float t = float(localIndex) / float(resolution);
            
            Point2D result;
            result.x = startPoint.x + t * (endPoint.x - startPoint.x);
            result.y = startPoint.y + t * (endPoint.y - startPoint.y);
            
            // Apply stroke width offset (simple perpendicular offset)
            if (strokeWidth > 0.0) {
                Point2D direction = {endPoint.x - startPoint.x, endPoint.y - startPoint.y};
                float length = sqrt(direction.x * direction.x + direction.y * direction.y);
                
                if (length > 0.0) {
                    Point2D normal = {-direction.y / length, direction.x / length};
                    float offset = strokeWidth * 0.5;
                    
                    // Alternate between positive and negative offset for stroke outline
                    if (index % 2 == 0) {
                        result.x += normal.x * offset;
                        result.y += normal.y * offset;
                    } else {
                        result.x -= normal.x * offset;
                        result.y -= normal.y * offset;
                    }
                }
            }
            
            outputPoints[index] = result;
        }
        
        // Phase 6: Vector Operations
        kernel void calculate_vector_distances(
            device const Point2D* sourcePoints [[buffer(0)]],
            device const Point2D* targetPoints [[buffer(1)]],
            device float* distances [[buffer(2)]],
            uint index [[thread_position_in_grid]]
        ) {
            Point2D source = sourcePoints[index];
            Point2D target = targetPoints[index];
            
            float dx = source.x - target.x;
            float dy = source.y - target.y;
            
            distances[index] = sqrt(dx * dx + dy * dy);
        }
        
        kernel void normalize_vectors(
            device const Point2D* inputVectors [[buffer(0)]],
            device Point2D* outputVectors [[buffer(1)]],
            uint index [[thread_position_in_grid]]
        ) {
            Point2D vector = inputVectors[index];
            
            float length = sqrt(vector.x * vector.x + vector.y * vector.y);
            
            if (length > 1e-10) {
                outputVectors[index] = {vector.x / length, vector.y / length};
            } else {
                outputVectors[index] = {0.0, 0.0};
            }
        }
        
        kernel void lerp_vectors(
            device const Point2D* startPoints [[buffer(0)]],
            device const Point2D* endPoints [[buffer(1)]],
            device Point2D* outputPoints [[buffer(2)]],
            constant float& t [[buffer(3)]],
            uint index [[thread_position_in_grid]]
        ) {
            Point2D start = startPoints[index];
            Point2D end = endPoints[index];
            
            Point2D result;
            result.x = start.x + t * (end.x - start.x);
            result.y = start.y + t * (end.y - start.y);
            
            outputPoints[index] = result;
        }
        
        // Phase 7: Handle Calculations for Bezier curve editing
        kernel void calculate_linked_handles(
            device const Point2D* anchorPoints [[buffer(0)]],
            device const Point2D* draggedHandles [[buffer(1)]],
            device const Point2D* originalOppositeHandles [[buffer(2)]],
            device Point2D* linkedHandles [[buffer(3)]],
            uint index [[thread_position_in_grid]]
        ) {
            Point2D anchor = anchorPoints[index];
            Point2D dragged = draggedHandles[index];
            Point2D originalOpposite = originalOppositeHandles[index];
            
            // Vector from anchor to dragged handle
            Point2D draggedVector = {dragged.x - anchor.x, dragged.y - anchor.y};
            
            // Keep the original opposite handle length
            Point2D originalVector = {originalOpposite.x - anchor.x, originalOpposite.y - anchor.y};
            float originalLength = sqrt(originalVector.x * originalVector.x + originalVector.y * originalVector.y);
            
            // Create opposite vector (180° from dragged handle) with original length
            float draggedLength = sqrt(draggedVector.x * draggedVector.x + draggedVector.y * draggedVector.y);
            
            if (draggedLength <= 0.1) {
                // Avoid division by zero - return original handle
                linkedHandles[index] = originalOpposite;
                return;
            }
            
            Point2D normalizedDragged = {draggedVector.x / draggedLength, draggedVector.y / draggedLength};
            
            // Opposite direction with original length
            Point2D linkedHandle;
            linkedHandle.x = anchor.x - normalizedDragged.x * originalLength;
            linkedHandle.y = anchor.y - normalizedDragged.y * originalLength;
            
            linkedHandles[index] = linkedHandle;
        }
        
        // Phase 10: Curve Smoothing and Curvature Analysis
        kernel void calculate_curvature(
            device const Point2D* points [[buffer(0)]],
            device float* curvatures [[buffer(1)]],
            constant uint& pointCount [[buffer(2)]],
            uint index [[thread_position_in_grid]]
        ) {
            // Calculate curvature for interior points only (index + 1 to avoid boundary issues)
            uint actualIndex = index + 1;
            if (actualIndex >= pointCount - 1) return;
            
            Point2D p0 = points[actualIndex - 1];
            Point2D p1 = points[actualIndex];
            Point2D p2 = points[actualIndex + 1];
            
            // Calculate vectors
            Point2D v1 = {p1.x - p0.x, p1.y - p0.y};
            Point2D v2 = {p2.x - p1.x, p2.y - p1.y};
            
            // Calculate lengths
            float len1 = sqrt(v1.x * v1.x + v1.y * v1.y);
            float len2 = sqrt(v2.x * v2.x + v2.y * v2.y);
            
            if (len1 == 0.0 || len2 == 0.0) {
                curvatures[actualIndex] = 0.0;
                return;
            }
            
            // Normalize vectors
            Point2D n1 = {v1.x / len1, v1.y / len1};
            Point2D n2 = {v2.x / len2, v2.y / len2};
            
            // Calculate dot product (cosine of angle)
            float dotProduct = n1.x * n2.x + n1.y * n2.y;
            
            // Convert to curvature measure (0 = straight line, 1 = sharp corner)
            curvatures[actualIndex] = 1.0 - abs(dotProduct);
        }
        
        kernel void chaikin_smoothing(
            device const Point2D* inputPoints [[buffer(0)]],
            device Point2D* outputPoints [[buffer(1)]],
            constant uint& inputCount [[buffer(2)]],
            constant float& ratio [[buffer(3)]],
            uint index [[thread_position_in_grid]]
        ) {
            if (index >= inputCount - 1) return;
            
            Point2D p1 = inputPoints[index];
            Point2D p2 = inputPoints[index + 1];
            
            // Create two new points on the segment using Chaikin's algorithm
            Point2D q1, q2;
            q1.x = p1.x + ratio * (p2.x - p1.x);
            q1.y = p1.y + ratio * (p2.y - p1.y);
            
            q2.x = p1.x + (1.0 - ratio) * (p2.x - p1.x);
            q2.y = p1.y + (1.0 - ratio) * (p2.y - p1.y);
            
            // Store the results (each segment produces 2 points)
            uint outputBase = index * 2 + 1; // +1 to skip first point
            if (outputBase < (inputCount - 1) * 2 + 1) {
                outputPoints[outputBase] = q1;
                if (outputBase + 1 < (inputCount - 1) * 2 + 1) {
                    outputPoints[outputBase + 1] = q2;
                }
            }
            
            // First and last points are handled separately in CPU
            if (index == 0) {
                outputPoints[0] = inputPoints[0]; // First point stays the same
            }
            if (index == inputCount - 2) {
                outputPoints[(inputCount - 1) * 2] = inputPoints[inputCount - 1]; // Last point
            }
        }
        
        // Phase 11: Mathematical Operations for Shape Drawing
        kernel void calculate_point_distance(
            device const Point2D* point1 [[buffer(0)]],
            device const Point2D* point2 [[buffer(1)]],
            device float* distances [[buffer(2)]],
            uint index [[thread_position_in_grid]]
        ) {
            Point2D p1 = point1[index];
            Point2D p2 = point2[index];
            
            float dx = p1.x - p2.x;
            float dy = p1.y - p2.y;
            
            distances[index] = sqrt(dx * dx + dy * dy);
        }
        
        kernel void calculate_square_roots(
            device const float* inputValues [[buffer(0)]],
            device float* outputValues [[buffer(1)]],
            uint index [[thread_position_in_grid]]
        ) {
            float value = inputValues[index];
            outputValues[index] = sqrt(max(0.0, value)); // Ensure non-negative input
        }
        """
    }
}
