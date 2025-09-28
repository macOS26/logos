import MetalKit

/// Metal-based drawing optimization to reduce CPU usage during drawing
class MetalDrawingOptimizer {
    
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private var isMetalAvailable: Bool = false
    
    static let shared = MetalDrawingOptimizer()
    
    private init() {
        // Initialize Metal safely (bypassing RenderBox issues)
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        self.isMetalAvailable = (device != nil && commandQueue != nil)
        
        if isMetalAvailable {
            Log.info("✅ Metal Drawing Optimizer: Initialized with \(device?.name ?? "Unknown GPU")", category: .general)
        } else {
            Log.fileOperation("⚠️ Metal Drawing Optimizer: Falling back to CPU-based optimizations", level: .info)
        }
    }
    
    // MARK: - Drawing Optimization
    
    /// Optimize path simplification using Metal compute shaders (when available)
    func optimizePathSimplification(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        if isMetalAvailable && points.count > 100 {
            // Use Metal for large point sets
            return metalAcceleratedSimplification(points, tolerance: tolerance)
        } else {
            // Use optimized CPU algorithm for smaller sets
            return cpuOptimizedSimplification(points, tolerance: tolerance)
        }
    }
    
    /// Reduce CPU load during real-time drawing
    func optimizeRealTimeDrawing(enabled: Bool) {
        if enabled && isMetalAvailable {
            // Enable Metal optimizations
            OptimizedPerformanceMonitor.shared.renderingMode = "Metal GPU Optimized"
        } else {
            // Use CPU optimizations
            OptimizedPerformanceMonitor.shared.renderingMode = "CPU Optimized"
        }
    }
    
    // MARK: - Metal Acceleration
    
    private func metalAcceleratedSimplification(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        // For now, fall back to optimized CPU version
        // TODO: Implement Metal compute shader for Douglas-Peucker algorithm
        return cpuOptimizedSimplification(points, tolerance: tolerance)
    }
    
    // MARK: - CPU Optimizations
    
    private func cpuOptimizedSimplification(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        // Fast Douglas-Peucker with early termination
        return douglasPeuckerOptimized(points: points, tolerance: tolerance)
    }
    
    private func douglasPeuckerOptimized(points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        guard let startPoint = points.first,
              let endPoint = points.last else { return points }
        
        var maxDistance: CGFloat = 0
        var maxIndex = 0
        
        // Find the point with maximum distance from the line
        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(point: points[i], lineStart: startPoint, lineEnd: endPoint)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        // If max distance is greater than tolerance, recursively simplify
        if maxDistance > tolerance {
            let leftPoints = Array(points[0...maxIndex])
            let rightPoints = Array(points[maxIndex..<points.count])
            
            let leftSimplified = douglasPeuckerOptimized(points: leftPoints, tolerance: tolerance)
            let rightSimplified = douglasPeuckerOptimized(points: rightPoints, tolerance: tolerance)
            
            // Combine results (remove duplicate middle point)
            return leftSimplified + Array(rightSimplified.dropFirst())
        } else {
            // Return only start and end points
            return [startPoint, endPoint]
        }
    }
    
    private func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let A = point.x - lineStart.x
        let B = point.y - lineStart.y
        let C = lineEnd.x - lineStart.x
        let D = lineEnd.y - lineStart.y
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        guard lenSq != 0 else { return sqrt(A * A + B * B) }
        
        let param = dot / lenSq
        
        let closestPoint: CGPoint
        if param < 0 {
            closestPoint = lineStart
        } else if param > 1 {
            closestPoint = lineEnd
        } else {
            closestPoint = CGPoint(x: lineStart.x + param * C, y: lineStart.y + param * D)
        }
        
        let dx = point.x - closestPoint.x
        let dy = point.y - closestPoint.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // MARK: - Drawing Event Optimization
    
    /// Track drawing events efficiently
    func trackDrawingStart() {
        OptimizedPerformanceMonitor.shared.metalCommandStart()
    }
    
    /// Optimize point collection during drawing
    func optimizePointCollection(_ points: inout [CGPoint], maxPoints: Int = 500) {
        // Prevent memory bloat during long strokes
        if points.count > maxPoints {
            // Keep every other point to maintain shape while reducing memory
            let step = max(2, points.count / (maxPoints / 2))
            let simplified = Swift.stride(from: 0, to: points.count, by: step).map { points[$0] }
            if let lastPoint = points.last {
                points = simplified + [lastPoint] // Always keep the last point
            } else {
                points = simplified
            }
        }
    }
}

// MARK: - Integration with Existing Drawing Tools

extension MetalDrawingOptimizer {
    
    /// Optimize freehand drawing performance (Phase 2: Full GPU acceleration)
    func optimizeFreehandDrawing(points: [CGPoint], tolerance: CGFloat = 2.0) -> [CGPoint] {
        trackDrawingStart()
        
        // Phase 2: Try Metal compute shaders first, fallback to Phase 1
        if points.count > 20 {
            let metalEngine = MetalComputeEngine.shared
            let result = metalEngine.douglasPeuckerGPU(points, tolerance: Float(tolerance))
            switch result {
            case .success(let simplifiedPoints):
                return simplifiedPoints
            case .failure(_):
                // Fallback to CPU calculation
                return GPUMathAcceleratorSimple.shared.optimizeDrawingPath(points, tolerance: tolerance)
            }
        }
        return points
    }
    
    /// Enable/disable optimizations based on system performance
    func adaptiveOptimization(cpuUsage: Double) {
        if cpuUsage > 70 {
            // High CPU usage - enable aggressive optimizations
            optimizeRealTimeDrawing(enabled: true)
        } else if cpuUsage < 30 {
            // Low CPU usage - can use higher quality
            optimizeRealTimeDrawing(enabled: false)
        }
    }
}
