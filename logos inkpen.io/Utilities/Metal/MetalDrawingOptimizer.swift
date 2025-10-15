import MetalKit

class MetalDrawingOptimizer {

    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private var isMetalAvailable: Bool = false

    static let shared = MetalDrawingOptimizer()

    private init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        self.isMetalAvailable = (device != nil && commandQueue != nil)

    }

    func optimizePathSimplification(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        if isMetalAvailable && points.count > 100 {
            return metalAcceleratedSimplification(points, tolerance: tolerance)
        } else {
            return cpuOptimizedSimplification(points, tolerance: tolerance)
        }
    }

    func optimizeRealTimeDrawing(enabled: Bool) {
        if enabled && isMetalAvailable {
            OptimizedPerformanceMonitor.shared.renderingMode = "Metal GPU Optimized"
        } else {
            OptimizedPerformanceMonitor.shared.renderingMode = "CPU Optimized"
        }
    }

    private func metalAcceleratedSimplification(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        return cpuOptimizedSimplification(points, tolerance: tolerance)
    }

    private func cpuOptimizedSimplification(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }

        return douglasPeuckerOptimized(points: points, tolerance: tolerance)
    }

    private func douglasPeuckerOptimized(points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }

        guard let startPoint = points.first,
              let endPoint = points.last else { return points }

        var maxDistance: CGFloat = 0
        var maxIndex = 0

        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(point: points[i], lineStart: startPoint, lineEnd: endPoint)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        if maxDistance > tolerance {
            let leftPoints = Array(points[0...maxIndex])
            let rightPoints = Array(points[maxIndex..<points.count])

            let leftSimplified = douglasPeuckerOptimized(points: leftPoints, tolerance: tolerance)
            let rightSimplified = douglasPeuckerOptimized(points: rightPoints, tolerance: tolerance)

            return leftSimplified + Array(rightSimplified.dropFirst())
        } else {
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

    func trackDrawingStart() {
        OptimizedPerformanceMonitor.shared.metalCommandStart()
    }

    func optimizePointCollection(_ points: inout [CGPoint], maxPoints: Int = 500) {
        if points.count > maxPoints {
            let step = max(2, points.count / (maxPoints / 2))
            let simplified = Swift.stride(from: 0, to: points.count, by: step).map { points[$0] }
            if let lastPoint = points.last {
                points = simplified + [lastPoint]
            } else {
                points = simplified
            }
        }
    }
}

extension MetalDrawingOptimizer {

    func optimizeFreehandDrawing(points: [CGPoint], tolerance: CGFloat = 2.0) -> [CGPoint] {
        trackDrawingStart()

        if points.count > 20 {
            let metalEngine = MetalComputeEngine.shared
            let result = metalEngine.douglasPeuckerGPU(points, tolerance: Float(tolerance))
            switch result {
            case .success(let simplifiedPoints):
                return simplifiedPoints
            case .failure(_):
                return GPUMathAcceleratorSimple.shared.optimizeDrawingPath(points, tolerance: tolerance)
            }
        }
        return points
    }

    func adaptiveOptimization(cpuUsage: Double) {
        if cpuUsage > 70 {
            optimizeRealTimeDrawing(enabled: true)
        } else if cpuUsage < 30 {
            optimizeRealTimeDrawing(enabled: false)
        }
    }
}
