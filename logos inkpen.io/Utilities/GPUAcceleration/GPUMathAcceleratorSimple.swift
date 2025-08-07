import Metal
import MetalKit
import Foundation

/// GPU-accelerated Core Graphics math functions - Phase 1 (Simple Implementation)
/// This version works without custom Metal shaders to start GPU acceleration incrementally
class GPUMathAcceleratorSimple {
    
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private var isMetalAvailable: Bool = false
    
    static let shared = GPUMathAcceleratorSimple()
    
    private init() {
        // Initialize Metal device safely (without custom shaders)
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        self.isMetalAvailable = (device != nil && commandQueue != nil)
        
        if isMetalAvailable {
            print("✅ GPU Math Accelerator (Simple): Ready with \(device?.name ?? "Unknown GPU")")
        } else {
            print("⚠️ GPU Math Accelerator (Simple): Using CPU-only mode")
        }
    }
    
    // MARK: - Phase 1: Optimized CPU Implementation (Metal-Ready)
    
    /// Phase 1: GPU-ready Douglas-Peucker (currently optimized CPU, will be GPU in next phase)
    func douglasPeuckerSimplifyGPUReady(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        // Track GPU readiness
        if isMetalAvailable {
            OptimizedPerformanceMonitor.shared.renderingMode = "GPU Ready"
        }
        
        // For Phase 1, use highly optimized CPU algorithm that's GPU-ready
        return douglasPeuckerOptimized(points: points, tolerance: Float(tolerance))
    }
    
    private func douglasPeuckerOptimized(points: [CGPoint], tolerance: Float) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        // Use iterative approach instead of recursive (GPU-friendly)
        var result: [CGPoint] = []
        var stack: [(startIndex: Int, endIndex: Int)] = [(0, points.count - 1)]
        var keepPoints = Set<Int>()
        
        // Always keep first and last points
        keepPoints.insert(0)
        keepPoints.insert(points.count - 1)
        
        while !stack.isEmpty {
            let segment = stack.removeLast()
            let startIndex = segment.startIndex
            let endIndex = segment.endIndex
            
            if endIndex - startIndex <= 1 {
                continue
            }
            
            // Find point with maximum distance from line segment
            let lineStart = points[startIndex]
            let lineEnd = points[endIndex]
            
            var maxDistance: Float = 0
            var maxIndex = startIndex
            
            // Optimized distance calculation (GPU-ready math)
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
            
            // If max distance exceeds tolerance, subdivide
            if maxDistance > tolerance {
                keepPoints.insert(maxIndex)
                stack.append((startIndex: startIndex, endIndex: maxIndex))
                stack.append((startIndex: maxIndex, endIndex: endIndex))
            }
        }
        
        // Build result from kept points
        result = keepPoints.sorted().map { points[$0] }
        
        print("🚀 Phase 1: Simplified \(points.count) → \(result.count) points (GPU-ready algorithm)")
        return result
    }
    
    // MARK: - GPU-Ready Math Functions
    
    private func perpendicularDistanceOptimized(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Float {
        // Optimized for eventual GPU implementation
        let A = Float(lineEnd.y - lineStart.y)
        let B = Float(lineStart.x - lineEnd.x)
        let C = Float(lineEnd.x * lineStart.y - lineStart.x * lineEnd.y)
        
        let numerator = abs(A * Float(point.x) + B * Float(point.y) + C)
        let denominator = sqrt(A * A + B * B)
        
        return numerator / denominator
    }
    
    // MARK: - Phase 1 Integration Points
    
    /// Main entry point for Phase 1 GPU acceleration
    func optimizeDrawingPath(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        if points.count > 20 { // Lower threshold for testing
            print("🚀 Phase 1: GPU-ready optimization for \(points.count) points")
            return douglasPeuckerSimplifyGPUReady(points, tolerance: tolerance)
        } else {
            return points
        }
    }
    
    // MARK: - Performance Monitoring
    
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
    
    // MARK: - Future Phase Preparation
    
    /// Prepare data structures for next GPU phase
    func prepareForGPUPhase2() {
        print("📋 Preparing for Phase 2: Metal compute shaders")
        // Future: Setup for full GPU compute shaders
    }
}

// MARK: - Phase 1 Testing

extension GPUMathAcceleratorSimple {
    
    /// Test Phase 1 optimizations
    func testPhase1Performance() {
        print("🧪 Testing Phase 1 GPU-ready optimizations...")
        
        // Create test data
        var testPoints: [CGPoint] = []
        for i in 0..<1000 {
            let x = CGFloat(i) + sin(Double(i) * 0.1) * 50
            let y = CGFloat(i) + cos(Double(i) * 0.1) * 50
            testPoints.append(CGPoint(x: x, y: y))
        }
        
        let startTime = CACurrentMediaTime()
        let simplified = optimizeDrawingPath(testPoints, tolerance: 2.0)
        let endTime = CACurrentMediaTime()
        
        let processingTime = (endTime - startTime) * 1000 // Convert to ms
        
        print("✅ Phase 1 Results:")
        print("   Input: \(testPoints.count) points")
        print("   Output: \(simplified.count) points")
        print("   Time: \(String(format: "%.2f", processingTime))ms")
        let reductionPercent = (1.0 - Double(simplified.count) / Double(testPoints.count)) * 100
        print("   Reduction: \(String(format: "%.1f", reductionPercent))%")
        print("   Mode: \(getPerformanceInfo())")
    }
}
