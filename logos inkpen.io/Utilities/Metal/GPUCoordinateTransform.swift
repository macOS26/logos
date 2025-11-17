import MetalKit
import simd

/// GPU-accelerated coordinate transformations using Metal compute shaders
class GPUCoordinateTransform {

    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let computePipeline: MTLComputePipelineState?
    private var isMetalAvailable: Bool = false

    static let shared = GPUCoordinateTransform()

    private init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()

        // Create compute pipeline for coordinate transforms
        if let device = device {
            let library = device.makeDefaultLibrary()
            if let kernelFunction = library?.makeFunction(name: "coordinate_transform") {
                self.computePipeline = try? device.makeComputePipelineState(function: kernelFunction)
                self.isMetalAvailable = (computePipeline != nil)
            } else {
                // Fallback: Metal not available, will use CPU SIMD
                self.computePipeline = nil
                self.isMetalAvailable = false
            }
        } else {
            self.computePipeline = nil
            self.isMetalAvailable = false
        }
    }

    /// Transform parameters for GPU compute shader
    /// Must match Metal shader struct CoordinateTransformParams
    struct CoordinateTransformParams {
        var offset: SIMD2<Float>
        var zoom: Float
        var isScreenToCanvas: Bool  // true = screen->canvas, false = canvas->screen

        init(offset: SIMD2<Float>, zoom: Float, isScreenToCanvas: Bool) {
            self.offset = offset
            self.zoom = zoom
            self.isScreenToCanvas = isScreenToCanvas
        }
    }

    /// Batch transform points using GPU (if available) or CPU SIMD fallback
    func transformPoints(_ points: [CGPoint], offset: CGPoint, zoom: CGFloat, screenToCanvas: Bool) -> [CGPoint] {
        // For small batches, CPU SIMD is faster (no GPU transfer overhead)
        guard points.count > 100, isMetalAvailable else {
            return transformPointsCPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
        }

        // Use GPU for large batches
        return transformPointsGPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
    }

    /// CPU SIMD fallback (fast for small batches)
    private func transformPointsCPU(_ points: [CGPoint], offset: CGPoint, zoom: CGFloat, screenToCanvas: Bool) -> [CGPoint] {
        let offsetVec = SIMD2<Float>(Float(offset.x), Float(offset.y))
        let zoomFloat = Float(zoom)

        return points.map { point in
            let pointVec = SIMD2<Float>(Float(point.x), Float(point.y))
            let transformed: SIMD2<Float>

            if screenToCanvas {
                // Screen to Canvas: (point - offset) / zoom
                transformed = (pointVec - offsetVec) / zoomFloat
            } else {
                // Canvas to Screen: point * zoom + offset
                transformed = pointVec * zoomFloat + offsetVec
            }

            return CGPoint(x: CGFloat(transformed.x), y: CGFloat(transformed.y))
        }
    }

    /// GPU Metal compute shader (fast for large batches)
    private func transformPointsGPU(_ points: [CGPoint], offset: CGPoint, zoom: CGFloat, screenToCanvas: Bool) -> [CGPoint] {
        guard let device = device,
              let commandQueue = commandQueue,
              let pipeline = computePipeline else {
            return transformPointsCPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
        }

        // Convert CGPoint to SIMD2<Float> for GPU
        let inputData = points.map { SIMD2<Float>(Float($0.x), Float($0.y)) }
        let dataSize = inputData.count * MemoryLayout<SIMD2<Float>>.stride

        // Create Metal buffers
        guard let inputBuffer = device.makeBuffer(bytes: inputData, length: dataSize, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: dataSize, options: .storageModeShared) else {
            return transformPointsCPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
        }

        // Transform parameters
        var params = CoordinateTransformParams(
            offset: SIMD2<Float>(Float(offset.x), Float(offset.y)),
            zoom: Float(zoom),
            isScreenToCanvas: screenToCanvas
        )

        guard let paramsBuffer = device.makeBuffer(bytes: &params, length: MemoryLayout<CoordinateTransformParams>.stride, options: .storageModeShared) else {
            return transformPointsCPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
        }

        // Create command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return transformPointsCPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(paramsBuffer, offset: 0, index: 2)

        // Calculate thread groups
        let threadGroupSize = MTLSize(width: min(pipeline.maxTotalThreadsPerThreadgroup, points.count), height: 1, depth: 1)
        let threadGroups = MTLSize(
            width: (points.count + threadGroupSize.width - 1) / threadGroupSize.width,
            height: 1,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        // Execute and wait
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read results
        let resultPointer = outputBuffer.contents().bindMemory(to: SIMD2<Float>.self, capacity: points.count)
        return (0..<points.count).map { i in
            let result = resultPointer[i]
            return CGPoint(x: CGFloat(result.x), y: CGFloat(result.y))
        }
    }

    var isGPUAvailable: Bool {
        return isMetalAvailable
    }

    func getDeviceInfo() -> String {
        if isMetalAvailable {
            return "GPU Transform: \(device?.name ?? "Unknown")"
        } else {
            return "GPU Transform: CPU SIMD Fallback"
        }
    }
}
