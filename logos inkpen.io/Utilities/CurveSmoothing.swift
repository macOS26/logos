//
//  CurveSmoothing.swift
//  logos inkpen.io
//
//  Advanced curve smoothing algorithms for professional drawing tools
//  Based on research from digital art applications and mathematical curve fitting
//

import Foundation
import CoreGraphics

// MARK: - Advanced Curve Smoothing Utilities

struct CurveSmoothing {
    
    // MARK: - Chaikin Smoothing Algorithm
    
    /// Applies Chaikin's corner cutting algorithm for smooth curve generation
    /// This creates smooth curves by iteratively cutting corners between line segments
    /// - Parameters:
    ///   - points: Input polyline points
    ///   - iterations: Number of smoothing iterations (1-3 recommended)
    ///   - ratio: Corner cutting ratio (0.25 = quarter points, creates smoother curves)
    /// - Returns: Smoothed points array
    static func chaikinSmooth(points: [CGPoint], iterations: Int = 1, ratio: Double = 0.25) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        
        var smoothedPoints = points
        
        for _ in 0..<iterations {
            smoothedPoints = applySingleChaikinIteration(points: smoothedPoints, ratio: ratio)
            
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
        newPoints.append(points.last!)
        
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

// MARK: - Real-time Smoothing for Apple Pencil

struct RealTimeSmoothing {
    
    /// Applies real-time smoothing to incoming points for live preview
    /// This uses a sliding window approach for minimal latency
    /// - Parameters:
    ///   - newPoint: The new point to add
    ///   - recentPoints: Array of recent points (modified in place)
    ///   - windowSize: Size of the smoothing window
    ///   - strength: Smoothing strength (0.0 = no smoothing, 1.0 = maximum)
    /// - Returns: Smoothed point for immediate display
    static func applyRealTimeSmoothing(
        newPoint: CGPoint,
        recentPoints: inout [CGPoint],
        windowSize: Int = 5,
        strength: Double = 0.3
    ) -> CGPoint {
        // Add new point to recent points
        recentPoints.append(newPoint)
        
        // Keep only the window size
        if recentPoints.count > windowSize {
            recentPoints = Array(recentPoints.suffix(windowSize))
        }
        
        // If we don't have enough points, return the original
        guard recentPoints.count >= 3 else {
            return newPoint
        }
        
        // Apply weighted average smoothing
        let smoothed = weightedAverageSmoothing(points: recentPoints, strength: strength)
        return smoothed.last ?? newPoint
    }
    
    /// Applies predictive smoothing for Apple Pencil predicted touches
    /// - Parameters:
    ///   - predictedPoints: Array of predicted points from Apple Pencil
    ///   - currentPoints: Current stroke points
    ///   - smoothingStrength: How much to smooth the predicted points
    /// - Returns: Smoothed predicted points
    static func smoothPredictedTouches(
        predictedPoints: [CGPoint],
        currentPoints: [CGPoint],
        smoothingStrength: Double = 0.4
    ) -> [CGPoint] {
        guard !predictedPoints.isEmpty, !currentPoints.isEmpty else {
            return predictedPoints
        }
        
        // Create a combined array for smoothing context
        let contextPoints = currentPoints.suffix(3) + predictedPoints
        
        // Apply light Chaikin smoothing to predicted points
        let smoothed = CurveSmoothing.chaikinSmooth(
            points: Array(contextPoints),
            iterations: 1,
            ratio: 0.2
        )
        
        // Return only the predicted portion
        let contextStart = min(3, currentPoints.count)
        return Array(smoothed.suffix(smoothed.count - contextStart))
    }
    
    private static func weightedAverageSmoothing(points: [CGPoint], strength: Double) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        
        var smoothedPoints = points
        
        // Apply weighted average to interior points
        for i in 1..<points.count - 1 {
            let prev = points[i - 1]
            let curr = points[i]
            let next = points[i + 1]
            
            // Weighted average: 25% prev, 50% current, 25% next
            let smoothX = prev.x * 0.25 + curr.x * 0.5 + next.x * 0.25
            let smoothY = prev.y * 0.25 + curr.y * 0.5 + next.y * 0.25
            
            // Blend between original and smoothed based on strength
            smoothedPoints[i] = CGPoint(
                x: curr.x * (1.0 - strength) + smoothX * strength,
                y: curr.y * (1.0 - strength) + smoothY * strength
            )
        }
        
        return smoothedPoints
    }
}

// MARK: - Stroke Smoothing Settings

struct StrokeSmoothingSettings {
    var chaikinIterations: Int = 1
    var chaikinRatio: Double = 0.25
    var douglasPeuckerTolerance: Double = 2.0
    var preserveSharpCorners: Bool = true
    var adaptiveTension: Bool = true
    var baseTension: Double = 0.3
    var enablePressureSmoothing: Bool = true
    var pressureSensitivity: Double = 0.8
    
    // Real-time smoothing settings
    var realTimeSmoothing: Bool = true
    var realTimeSmoothingStrength: Double = 0.3
    var realTimeWindowSize: Int = 5
    var predictiveSmoothingStrength: Double = 0.4
    
    static let `default` = StrokeSmoothingSettings()
}