import MetalKit

class GPUMathAcceleratorSimple {

    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private var isMetalAvailable: Bool = false

    static let shared = GPUMathAcceleratorSimple()

    private init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        self.isMetalAvailable = (device != nil && commandQueue != nil)

    }


    func douglasPeuckerSimplifyGPUReady(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        if isMetalAvailable {
            OptimizedPerformanceMonitor.shared.renderingMode = "GPU Ready"
        }

        return douglasPeuckerOptimized(points: points, tolerance: Float(tolerance))
    }

    private func douglasPeuckerOptimized(points: [CGPoint], tolerance: Float) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var result: [CGPoint] = []
        var stack: [(startIndex: Int, endIndex: Int)] = [(0, points.count - 1)]
        var keepPoints = Set<Int>()

        keepPoints.insert(0)
        keepPoints.insert(points.count - 1)

        while !stack.isEmpty {
            let segment = stack.removeLast()
            let startIndex = segment.startIndex
            let endIndex = segment.endIndex

            if endIndex - startIndex <= 1 {
                continue
            }

            let lineStart = points[startIndex]
            let lineEnd = points[endIndex]

            var maxDistance: Float = 0
            var maxIndex = startIndex

            for i in (startIndex + 1)..<endIndex {
                let distance = perpendicularDistanceOptimized(
                    point: points[i],
                    lineStart: lineStart,
                    lineEnd: lineEnd
                )

                if distance > maxDistance {
                    maxDistance = distance
                    maxIndex = i
                }
            }

            if maxDistance > tolerance {
                keepPoints.insert(maxIndex)
                stack.append((startIndex: startIndex, endIndex: maxIndex))
                stack.append((startIndex: maxIndex, endIndex: endIndex))
            }
        }

        result = keepPoints.sorted().map { points[$0] }

        return result
    }


    private func perpendicularDistanceOptimized(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Float {
        let A = Float(lineEnd.y - lineStart.y)
        let B = Float(lineStart.x - lineEnd.x)
        let C = Float(lineEnd.x * lineStart.y - lineStart.x * lineEnd.y)

        let numerator = abs(A * Float(point.x) + B * Float(point.y) + C)
        let denominator = sqrt(A * A + B * B)

        return numerator / denominator
    }


    func optimizeDrawingPath(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        if points.count > 20 {
            return douglasPeuckerSimplifyGPUReady(points, tolerance: tolerance)
        } else {
            return points
        }
    }


    var isGPUReady: Bool {
        return isMetalAvailable
    }

    func getPerformanceInfo() -> String {
        if isMetalAvailable {
            return "Phase 1: GPU Ready (\(device?.name ?? "Unknown"))"
        } else {
            return "Phase 1: CPU Only"
        }
    }

}
