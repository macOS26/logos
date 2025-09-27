//
//  CurveSmoothing.swift
//  logos inkpen.io
//
//  Advanced curve smoothing algorithms for professional drawing tools
//  Based on research from digital art applications and mathematical curve fitting
//

import SwiftUI

// MARK: - Advanced Curve Smoothing Utilities

struct CurveSmoothing {
    
    // MARK: - Chaikin Smoothing Algorithm
    
    /// Applies Chaikin's corner cutting algorithm for smooth curve generation
    /// This creates smooth curves by iteratively cutting corners between line segments
    /// 🚀 GPU-ACCELERATED: Uses Metal compute shaders for large point sets
    /// - Parameters:
    ///   - points: Input polyline points
    ///   - iterations: Number of smoothing iterations (1-3 recommended)
    ///   - ratio: Corner cutting ratio (0.25 = quarter points, creates smoother curves)
    /// - Returns: Smoothed points array
    static func chaikinSmooth(points: [CGPoint], iterations: Int = 1, ratio: Double = 0.25) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        
        var smoothedPoints = points
        
        for _ in 0..<iterations {
            // 🚀 PHASE 10: Use GPU for large point sets
            if smoothedPoints.count >= 50 {
                let metalEngine = MetalComputeEngine.shared
                let smoothingResult = metalEngine.chaikinSmoothingGPU(points: smoothedPoints, ratio: Float(ratio))
                switch smoothingResult {
                case .success(let smoothed):
                    smoothedPoints = smoothed
                case .failure(_):
                    // Fallback to CPU calculation
                    smoothedPoints = applySingleChaikinIteration(points: smoothedPoints, ratio: ratio)
                }
            } else {
                smoothedPoints = applySingleChaikinIteration(points: smoothedPoints, ratio: ratio)
            }
            
            // Prevent over-smoothing by limiting point reduction
            if smoothedPoints.count < 3 {
                break
            }
        }
        
        return smoothedPoints
    }
    
    private static func applySingleChaikinIteration(points: [CGPoint], ratio: Double) -> [CGPoint] {
        guard points.count >= 2 else { return points }
        
        var newPoints: [CGPoint] = []
        
        // Keep first point
        newPoints.append(points[0])
        
        // Generate new points between each pair
        for i in 0..<points.count-1 {
            let p0 = points[i]
            let p1 = points[i + 1]
            
            // Create two new points at ratio positions along the line segment
            let q = CGPoint(
                x: p0.x + (p1.x - p0.x) * ratio,
                y: p0.y + (p1.y - p0.y) * ratio
            )
            
            let r = CGPoint(
                x: p0.x + (p1.x - p0.x) * (1.0 - ratio),
                y: p0.y + (p1.y - p0.y) * (1.0 - ratio)
            )
            
            newPoints.append(q)
            newPoints.append(r)
        }
        
        // Keep last point
        if let lastPoint = points.last {
            newPoints.append(lastPoint)
        }
        
        return newPoints
    }
    
    // MARK: - Improved Douglas-Peucker with Better Distance Calculation
    
    /// Enhanced Douglas-Peucker algorithm with improved distance calculation
    /// - Parameters:
    ///   - points: Input points to simplify
    ///   - tolerance: Distance tolerance for point removal
    ///   - preserveSharpCorners: If true, preserves points with high curvature
    /// - Returns: Simplified point array
    static func improvedDouglassPeucker(points: [CGPoint], tolerance: Double, preserveSharpCorners: Bool = true) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        return improvedDPRecursive(points: points, tolerance: tolerance, startIndex: 0, endIndex: points.count - 1, preserveSharpCorners: preserveSharpCorners)
    }
    
    private static func improvedDPRecursive(points: [CGPoint], tolerance: Double, startIndex: Int, endIndex: Int, preserveSharpCorners: Bool) -> [CGPoint] {
        var maxDistance: Double = 0
        var maxIndex = 0
        var maxCurvature: Double = 0
        
        // Find the point with maximum distance from line segment
        for i in startIndex + 1..<endIndex {
            let distance = perpendicularDistance(point: points[i], lineStart: points[startIndex], lineEnd: points[endIndex])
            
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
            
            // Calculate curvature for sharp corner preservation
            if preserveSharpCorners && i > startIndex && i < endIndex - 1 {
                let curvature = calculateCurvature(p0: points[i-1], p1: points[i], p2: points[i+1])
                maxCurvature = max(maxCurvature, curvature)
            }
        }
        
        // If max distance is greater than tolerance OR we have a sharp corner, recurse
        let isSharpCorner = preserveSharpCorners && maxCurvature > 0.7 // Threshold for sharp corners
        
        if maxDistance > tolerance || isSharpCorner {
            // Recursive calls on both sides of the farthest point
            let leftPoints = improvedDPRecursive(points: points, tolerance: tolerance, startIndex: startIndex, endIndex: maxIndex, preserveSharpCorners: preserveSharpCorners)
            let rightPoints = improvedDPRecursive(points: points, tolerance: tolerance, startIndex: maxIndex, endIndex: endIndex, preserveSharpCorners: preserveSharpCorners)
            
            // Combine results (remove duplicate middle point)
            return leftPoints + Array(rightPoints.dropFirst())
        } else {
            // All points between start and end can be removed
            return [points[startIndex], points[endIndex]]
        }
    }
    
    // MARK: - Adaptive Curve Fitting with Centripetal Catmull-Rom
    
    /// Creates smooth bezier curves using adaptive tension based on point spacing and curvature
    /// - Parameters:
    ///   - points: Input control points
    ///   - adaptiveTension: Use adaptive tension based on curvature (recommended)
    ///   - baseTension: Base tension value (0.1-0.5 range)
    /// - Returns: Array of PathElement for smooth curves
    static func adaptiveCurveFitting(points: [CGPoint], adaptiveTension: Bool = true, baseTension: Double = 0.3) -> [PathElement] {
        guard points.count >= 2 else { return [] }
        
        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(points[0])))
        
        if points.count == 2 {
            elements.append(.line(to: VectorPoint(points[1])))
            return elements
        }
        
        // Create smooth curves through all points
        for i in 1..<points.count {
            let p0 = points[max(0, i - 2)]           // Previous control point
            let p1 = points[i - 1]                   // Start point
            let p2 = points[i]                       // End point  
            let p3 = points[min(points.count - 1, i + 1)] // Next control point
            
            // Calculate adaptive tension based on curvature and distance
            var tension = baseTension
            if adaptiveTension {
                let curvature = calculateCurvature(p0: p0, p1: p1, p2: p2)
                let distance = sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
                
                // Adaptive tension: higher curvature = lower tension (tighter curves)
                // Longer distances = higher tension (smoother curves)
                tension = baseTension * (1.0 - curvature * 0.5) * min(2.0, distance / 50.0)
                tension = max(0.1, min(0.8, tension)) // Clamp to reasonable range
            }
            
            // Calculate centripetal Catmull-Rom control points
            let (control1, control2) = calculateCentripetalControls(p0: p0, p1: p1, p2: p2, p3: p3, tension: tension)
            
            elements.append(.curve(
                to: VectorPoint(p2),
                control1: VectorPoint(control1),
                control2: VectorPoint(control2)
            ))
        }
        
        return elements
    }
    
    // MARK: - Utility Functions
    
    /// Calculate perpendicular distance from point to line segment
    private static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let A = point.x - lineStart.x
        let B = point.y - lineStart.y
        let C = lineEnd.x - lineStart.x
        let D = lineEnd.y - lineStart.y
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        if lenSq == 0 {
            // Line start and end are the same point
            return sqrt(A * A + B * B)
        }
        
        let param = dot / lenSq
        
        let xx, yy: Double
        if param < 0 {
            xx = lineStart.x
            yy = lineStart.y
        } else if param > 1 {
            xx = lineEnd.x
            yy = lineEnd.y
        } else {
            xx = lineStart.x + param * C
            yy = lineStart.y + param * D
        }
        
        let dx = point.x - xx
        let dy = point.y - yy
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Calculate curvature at a point given three consecutive points
    /// 🚀 GPU-ACCELERATED: Can use batch GPU calculations for large point sets
    private static func calculateCurvature(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> Double {
        // Calculate vectors
        let v1 = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
        let v2 = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
        
        // Calculate lengths
        let len1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let len2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        
        if len1 == 0 || len2 == 0 {
            return 0
        }
        
        // Normalize vectors
        let n1 = CGPoint(x: v1.x / len1, y: v1.y / len1)
        let n2 = CGPoint(x: v2.x / len2, y: v2.y / len2)
        
        // Calculate dot product (cosine of angle)
        let dotProduct = n1.x * n2.x + n1.y * n2.y
        
        // Convert to curvature measure (0 = straight line, 1 = sharp corner)
        return 1.0 - abs(dotProduct)
    }
    
    /// Calculate curvature for multiple points efficiently
    /// 🚀 PHASE 10: GPU-accelerated batch curvature calculations
    static func calculateCurvatureBatch(points: [CGPoint]) -> [Double] {
        guard points.count >= 3 else { return [] }
        
        // 🚀 Use GPU for large point sets
        if points.count >= 100 {
            let metalEngine = MetalComputeEngine.shared
            let results = metalEngine.calculateCurvatureGPU(points: points)
            switch results {
            case .success(let curvatures):
                return curvatures.map { Double($0) }
            case .failure(_):
                // Fallback to CPU calculation
                break
            }
        }
        
        // CPU fallback for small point sets
        var curvatures: [Double] = []
        
        // First point has no curvature
        curvatures.append(0.0)
        
        // Calculate curvature for interior points
        for i in 1..<(points.count - 1) {
            let curvature = calculateCurvature(p0: points[i-1], p1: points[i], p2: points[i+1])
            curvatures.append(curvature)
        }
        
        // Last point has no curvature
        curvatures.append(0.0)
        
        return curvatures
    }
    
    /// Calculate centripetal Catmull-Rom control points for smooth curves
    private static func calculateCentripetalControls(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, tension: Double) -> (CGPoint, CGPoint) {
        // Calculate parametric distances using centripetal parameterization
        let d1 = sqrt(pow(p1.x - p0.x, 2) + pow(p1.y - p0.y, 2))
        let d2 = sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
        let d3 = sqrt(pow(p3.x - p2.x, 2) + pow(p3.y - p2.y, 2))
        
        // Avoid division by zero
        let d1Safe = max(d1, 0.001)
        let d2Safe = max(d2, 0.001)
        let d3Safe = max(d3, 0.001)
        
        // Calculate tangent vectors
        let t1 = CGPoint(
            x: (p2.x - p0.x) / (d1Safe + d2Safe),
            y: (p2.y - p0.y) / (d1Safe + d2Safe)
        )
        
        let t2 = CGPoint(
            x: (p3.x - p1.x) / (d2Safe + d3Safe),
            y: (p3.y - p1.y) / (d2Safe + d3Safe)
        )
        
        // Calculate control points
        let control1 = CGPoint(
            x: p1.x + t1.x * d2Safe * tension,
            y: p1.y + t1.y * d2Safe * tension
        )
        
        let control2 = CGPoint(
            x: p2.x - t2.x * d2Safe * tension,
            y: p2.y - t2.y * d2Safe * tension
        )
        
        return (control1, control2)
    }
}

