//
//  RealTimeSmoothing.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics

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
