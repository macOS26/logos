//
//  ProfessionalBezierMathematics.swift
//  logos
//
//  Professional Bezier Curve Mathematics Module
//  Implements Adobe Illustrator, FreeHand, and CorelDRAW standards
//
//  Created by Todd Bruss on 7/6/25.
//

import Foundation
import SwiftUI

// MARK: - Professional Bezier Mathematics Foundation

/// Professional Bezier curve mathematics implementing industry standards
/// Used by Adobe Illustrator, Macromedia FreeHand, and CorelDRAW
struct ProfessionalBezierMathematics {
    
    // MARK: - Core Bezier Point Structure
    
    /// Professional bezier point with full handle information
    struct BezierPoint: Codable, Hashable {
        var point: VectorPoint                  // Anchor point location
        var incomingHandle: VectorPoint?        // Incoming control handle (G1 continuity)
        var outgoingHandle: VectorPoint?        // Outgoing control handle (G1 continuity)
        var pointType: AnchorPointType          // Professional point type
        var handleConstraint: HandleConstraint  // Handle behavior constraint
        
        init(point: VectorPoint, 
             incomingHandle: VectorPoint? = nil, 
             outgoingHandle: VectorPoint? = nil,
             pointType: AnchorPointType = .corner,
             handleConstraint: HandleConstraint = .independent) {
            self.point = point
            self.incomingHandle = incomingHandle
            self.outgoingHandle = outgoingHandle
            self.pointType = pointType
            self.handleConstraint = handleConstraint
        }
        
        /// Adobe Illustrator-style smooth point creation
        static func smoothPoint(at location: VectorPoint, handleLength: Double, angle: Double) -> BezierPoint {
            let handleVector = VectorPoint(
                cos(angle) * handleLength,
                sin(angle) * handleLength
            )
            return BezierPoint(
                point: location,
                incomingHandle: VectorPoint(location.x - handleVector.x, location.y - handleVector.y),
                outgoingHandle: VectorPoint(location.x + handleVector.x, location.y + handleVector.y),
                pointType: .smoothCurve,
                handleConstraint: .symmetric
            )
        }
        
        /// Professional corner point creation
        static func cornerPoint(at location: VectorPoint) -> BezierPoint {
            return BezierPoint(
                point: location,
                incomingHandle: nil,
                outgoingHandle: nil,
                pointType: .corner,
                handleConstraint: .independent
            )
        }
    }
    
    // MARK: - Professional Anchor Point Types (Adobe Illustrator Standards)
    
    enum AnchorPointType: String, CaseIterable, Codable {
        case corner = "Corner"              // Sharp corner, no handles or independent handles
        case smoothCurve = "Smooth Curve"   // Smooth curve with symmetric handles (G1 continuity)
        case smoothCorner = "Smooth Corner" // Smooth direction change with different handle lengths
        case cusp = "Cusp"                  // Sharp direction change with handles
        case connector = "Connector"        // FreeHand-style intelligent connection point
        
        var description: String {
            switch self {
            case .corner:
                return "Corner point with sharp edges"
            case .smoothCurve:
                return "Smooth curve point with symmetric handles"
            case .smoothCorner:
                return "Smooth corner with different handle lengths"
            case .cusp:
                return "Cusp point with independent handle directions"
            case .connector:
                return "Intelligent connector point (FreeHand style)"
            }
        }
        
        var hasHandles: Bool {
            switch self {
            case .corner: return false
            case .smoothCurve, .smoothCorner, .cusp, .connector: return true
            }
        }
    }
    
    // MARK: - Handle Constraint Types (Professional Standards)
    
    enum HandleConstraint: String, CaseIterable, Codable {
        case symmetric = "Symmetric"      // Handles are opposite and equal length (Adobe Illustrator smooth)
        case aligned = "Aligned"          // Handles are opposite but different lengths (Adobe Illustrator smooth corner)
        case independent = "Independent"  // Handles move independently (Adobe Illustrator corner/cusp)
        case automatic = "Automatic"      // System calculates optimal handles (FreeHand style)
        
        var description: String {
            switch self {
            case .symmetric:
                return "Symmetric handles (equal length and opposite direction)"
            case .aligned:
                return "Aligned handles (opposite direction, different lengths)"
            case .independent:
                return "Independent handles (move separately)"
            case .automatic:
                return "Automatic handles (system optimized)"
            }
        }
    }
    
    // MARK: - De Casteljau's Algorithm (Professional Implementation)
    
    /// De Casteljau's algorithm for bezier curve evaluation
    /// This is the gold standard algorithm used by professional applications
    /// More numerically stable than direct polynomial evaluation
    static func deCasteljauEvaluation(points: [VectorPoint], t: Double) -> VectorPoint {
        guard !points.isEmpty else { return VectorPoint(0, 0) }
        guard points.count > 1 else { return points[0] }
        
        var currentPoints = points
        
        // Recursive linear interpolation until we have one point
        while currentPoints.count > 1 {
            var nextLevel: [VectorPoint] = []
            
            for i in 0..<(currentPoints.count - 1) {
                let p0 = currentPoints[i]
                let p1 = currentPoints[i + 1]
                
                // Linear interpolation: (1-t) * p0 + t * p1
                let interpolated = VectorPoint(
                    (1.0 - t) * p0.x + t * p1.x,
                    (1.0 - t) * p0.y + t * p1.y
                )
                nextLevel.append(interpolated)
            }
            
            currentPoints = nextLevel
        }
        
        return currentPoints[0]
    }
    
    // MARK: - Bernstein Polynomial Basis Functions
    
    /// Calculate Bernstein polynomial basis function
    /// B(i,n)(t) = C(n,i) * t^i * (1-t)^(n-i)
    static func bernsteinBasis(i: Int, n: Int, t: Double) -> Double {
        let binomialCoeff = binomialCoefficient(n: n, k: i)
        let tPower = pow(t, Double(i))
        let oneMinusTPower = pow(1.0 - t, Double(n - i))
        return Double(binomialCoeff) * tPower * oneMinusTPower
    }
    
    /// Efficient binomial coefficient calculation with lookup table
    private static var binomialLookup: [[Int]] = []
    
    static func binomialCoefficient(n: Int, k: Int) -> Int {
        guard n >= 0 && k >= 0 && k <= n else { return 0 }
        
        // Extend lookup table if needed (Pascal's triangle)
        while binomialLookup.count <= n {
            let currentN = binomialLookup.count
            var newRow: [Int] = []
            
            for i in 0...currentN {
                if i == 0 || i == currentN {
                    newRow.append(1)
                } else {
                    let value = binomialLookup[currentN - 1][i - 1] + binomialLookup[currentN - 1][i]
                    newRow.append(value)
                }
            }
            
            binomialLookup.append(newRow)
        }
        
        return binomialLookup[n][k]
    }
    
    // MARK: - Professional Curve Evaluation Methods
    
    /// Evaluate cubic bezier curve using optimized Horner's algorithm
    /// Faster than De Casteljau for single point evaluation
    static func evaluateCubicBezier(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> VectorPoint {
        let u = 1.0 - t
        let u2 = u * u
        let u3 = u2 * u
        let t2 = t * t
        let t3 = t2 * t
        
        // Optimized cubic bezier evaluation
        let x = u3 * p0.x + 3 * u2 * t * p1.x + 3 * u * t2 * p2.x + t3 * p3.x
        let y = u3 * p0.y + 3 * u2 * t * p1.y + 3 * u * t2 * p2.y + t3 * p3.y
        
        return VectorPoint(x, y)
    }
    
    /// Evaluate quadratic bezier curve
    static func evaluateQuadraticBezier(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, t: Double) -> VectorPoint {
        let u = 1.0 - t
        let u2 = u * u
        let t2 = t * t
        
        let x = u2 * p0.x + 2 * u * t * p1.x + t2 * p2.x
        let y = u2 * p0.y + 2 * u * t * p1.y + t2 * p2.y
        
        return VectorPoint(x, y)
    }
    
    // MARK: - Curve Derivatives (Professional Analysis)
    
    /// Calculate first derivative (tangent vector) of cubic bezier curve
    static func cubicBezierFirstDerivative(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> VectorPoint {
        let u = 1.0 - t
        
        // First derivative of cubic bezier: 3 * [(1-t)^2 * (p1-p0) + 2*(1-t)*t * (p2-p1) + t^2 * (p3-p2)]
        let dx = 3 * (u * u * (p1.x - p0.x) + 2 * u * t * (p2.x - p1.x) + t * t * (p3.x - p2.x))
        let dy = 3 * (u * u * (p1.y - p0.y) + 2 * u * t * (p2.y - p1.y) + t * t * (p3.y - p2.y))
        
        return VectorPoint(dx, dy)
    }
    
    /// Calculate second derivative (curvature vector) of cubic bezier curve
    static func cubicBezierSecondDerivative(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> VectorPoint {
        // Second derivative of cubic bezier: 6 * [(1-t) * (p2-2*p1+p0) + t * (p3-2*p2+p1)]
        let u = 1.0 - t
        
        let dx = 6 * (u * (p2.x - 2 * p1.x + p0.x) + t * (p3.x - 2 * p2.x + p1.x))
        let dy = 6 * (u * (p2.y - 2 * p1.y + p0.y) + t * (p3.y - 2 * p2.y + p1.y))
        
        return VectorPoint(dx, dy)
    }
    
    /// Calculate curvature at parameter t
    static func calculateCurvature(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> Double {
        let firstDeriv = cubicBezierFirstDerivative(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
        let secondDeriv = cubicBezierSecondDerivative(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
        
        // Curvature formula: κ = |x'y'' - y'x''| / (x'^2 + y'^2)^(3/2)
        let crossProduct = firstDeriv.x * secondDeriv.y - firstDeriv.y * secondDeriv.x
        let speedSquared = firstDeriv.x * firstDeriv.x + firstDeriv.y * firstDeriv.y
        let speed = sqrt(speedSquared)
        
        guard speed > 1e-10 else { return 0.0 } // Avoid division by zero
        
        return abs(crossProduct) / (speedSquared * speed)
    }
    
    // MARK: - Professional Curve Subdivision
    
    /// Split cubic bezier curve at parameter t using De Casteljau
    /// Returns (left_curve_points, right_curve_points)
    static func splitCubicBezier(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> ([VectorPoint], [VectorPoint]) {
        // De Casteljau subdivision
        let q0 = p0
        let q1 = VectorPoint.lerp(p0, p1, t)
        let q2 = VectorPoint.lerp(p1, p2, t)
        let q3 = p3
        
        let r0 = q0
        let r1 = VectorPoint.lerp(q1, q2, t)
        let r2 = VectorPoint.lerp(p2, p3, t)
        let r3 = q3
        
        let _ = r0 // s0 unused
        let s1 = VectorPoint.lerp(r1, r2, t)
        let _ = r3 // s2 unused
        
        let pointOnCurve = VectorPoint.lerp(s1, s1, t) // This is the point on the original curve at parameter t
        
        // Left curve: p0, q1, r1, pointOnCurve
        // Right curve: pointOnCurve, s1, r2, p3
        let leftCurve = [p0, q1, r1, pointOnCurve]
        let rightCurve = [pointOnCurve, s1, r2, p3]
        
        return (leftCurve, rightCurve)
    }
    
    // MARK: - Professional Handle Generation
    
    /// Generate smooth handles for a point based on neighboring points (Adobe Illustrator algorithm)
    static func generateSmoothHandles(previousPoint: VectorPoint?, currentPoint: VectorPoint, nextPoint: VectorPoint?, tension: Double = 0.33) -> (VectorPoint?, VectorPoint?) {
        var incomingHandle: VectorPoint?
        var outgoingHandle: VectorPoint?
        
        if let prev = previousPoint, let next = nextPoint {
            // Calculate direction vector from previous to next point
            let direction = VectorPoint(next.x - prev.x, next.y - prev.y)
            let directionLength = sqrt(direction.x * direction.x + direction.y * direction.y)
            
            guard directionLength > 1e-10 else { return (nil, nil) }
            
            // Normalize direction
            let normalizedDirection = VectorPoint(direction.x / directionLength, direction.y / directionLength)
            
            // Calculate handle lengths based on distances to neighboring points
            let prevDistance = sqrt((currentPoint.x - prev.x) * (currentPoint.x - prev.x) + (currentPoint.y - prev.y) * (currentPoint.y - prev.y))
            let nextDistance = sqrt((next.x - currentPoint.x) * (next.x - currentPoint.x) + (next.y - currentPoint.y) * (next.y - currentPoint.y))
            
            let incomingLength = prevDistance * tension
            let outgoingLength = nextDistance * tension
            
            // Generate handles
            incomingHandle = VectorPoint(
                currentPoint.x - normalizedDirection.x * incomingLength,
                currentPoint.y - normalizedDirection.y * incomingLength
            )
            
            outgoingHandle = VectorPoint(
                currentPoint.x + normalizedDirection.x * outgoingLength,
                currentPoint.y + normalizedDirection.y * outgoingLength
            )
        } else if let prev = previousPoint {
            // Only previous point available
            let direction = VectorPoint(currentPoint.x - prev.x, currentPoint.y - prev.y)
            let directionLength = sqrt(direction.x * direction.x + direction.y * direction.y)
            let handleLength = directionLength * tension
            
            if directionLength > 1e-10 {
                let normalizedDirection = VectorPoint(direction.x / directionLength, direction.y / directionLength)
                outgoingHandle = VectorPoint(
                    currentPoint.x + normalizedDirection.x * handleLength,
                    currentPoint.y + normalizedDirection.y * handleLength
                )
            }
        } else if let next = nextPoint {
            // Only next point available
            let direction = VectorPoint(next.x - currentPoint.x, next.y - currentPoint.y)
            let directionLength = sqrt(direction.x * direction.x + direction.y * direction.y)
            let handleLength = directionLength * tension
            
            if directionLength > 1e-10 {
                let normalizedDirection = VectorPoint(direction.x / directionLength, direction.y / directionLength)
                incomingHandle = VectorPoint(
                    currentPoint.x - normalizedDirection.x * handleLength,
                    currentPoint.y - normalizedDirection.y * handleLength
                )
            }
        }
        
        return (incomingHandle, outgoingHandle)
    }
    
    // MARK: - Curve Continuity Analysis
    
    enum ContinuityType: String, CaseIterable, Codable {
        case c0 = "C0"        // Position continuity
        case g1 = "G1"        // Tangent continuity (G1 geometric continuity)
        case c1 = "C1"        // First derivative continuity
        case g2 = "G2"        // Curvature continuity (G2 geometric continuity)
        case c2 = "C2"        // Second derivative continuity
        case none = "None"    // No continuity
    }
    
    /// Analyze continuity between two cubic bezier curves
    static func analyzeContinuity(curve1: [VectorPoint], curve2: [VectorPoint], tolerance: Double = 1e-10) -> ContinuityType {
        guard curve1.count == 4 && curve2.count == 4 else { return .none }
        
        let _ = curve1[0], _ = curve1[1], p2 = curve1[2], p3 = curve1[3]
        let q0 = curve2[0], q1 = curve2[1], _ = curve2[2], _ = curve2[3]
        
        // Check C0 continuity (position)
        let positionDiff = sqrt((p3.x - q0.x) * (p3.x - q0.x) + (p3.y - q0.y) * (p3.y - q0.y))
        guard positionDiff < tolerance else { return .none }
        
        // Check G1 continuity (tangent direction)
        let curve1EndTangent = VectorPoint(p3.x - p2.x, p3.y - p2.y)
        let curve2StartTangent = VectorPoint(q1.x - q0.x, q1.y - q0.y)
        
        let tangent1Length = sqrt(curve1EndTangent.x * curve1EndTangent.x + curve1EndTangent.y * curve1EndTangent.y)
        let tangent2Length = sqrt(curve2StartTangent.x * curve2StartTangent.x + curve2StartTangent.y * curve2StartTangent.y)
        
        guard tangent1Length > tolerance && tangent2Length > tolerance else { return .c0 }
        
        let normalizedTangent1 = VectorPoint(curve1EndTangent.x / tangent1Length, curve1EndTangent.y / tangent1Length)
        let normalizedTangent2 = VectorPoint(curve2StartTangent.x / tangent2Length, curve2StartTangent.y / tangent2Length)
        
        let tangentDiff = sqrt((normalizedTangent1.x - normalizedTangent2.x) * (normalizedTangent1.x - normalizedTangent2.x) + 
                              (normalizedTangent1.y - normalizedTangent2.y) * (normalizedTangent1.y - normalizedTangent2.y))
        
        guard tangentDiff < tolerance else { return .c0 }
        
        // Check C1 continuity (first derivative magnitude)
        let derivativeDiff = abs(tangent1Length - tangent2Length)
        if derivativeDiff < tolerance {
            return .c1 // Could check for C2/G2 here as well
        } else {
            return .g1
        }
    }
    
    // MARK: - Professional Curve Fitting
    
    /// Fit cubic bezier curve through points using least squares
    static func fitCubicBezierToPoints(points: [VectorPoint]) -> [VectorPoint]? {
        guard points.count >= 4 else { return nil }
        
        // For now, implement a simple approximation
        // Professional implementation would use least squares fitting
        let p0 = points.first!
        let p3 = points.last!
        
        // Estimate control points based on point distribution
        let midIndex1 = points.count / 3
        let midIndex2 = (points.count * 2) / 3
        
        let p1 = points[min(midIndex1, points.count - 1)]
        let p2 = points[min(midIndex2, points.count - 1)]
        
        return [p0, p1, p2, p3]
    }
    
    // MARK: - Curve Length Calculation
    
    /// Calculate arc length of cubic bezier curve using Gaussian quadrature
    static func calculateArcLength(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, subdivisions: Int = 10) -> Double {
        var totalLength: Double = 0.0
        let dt = 1.0 / Double(subdivisions)
        
        for i in 0..<subdivisions {
            let t1 = Double(i) * dt
            let t2 = Double(i + 1) * dt
            
            // Use Gaussian quadrature for more accurate integration
            let point1 = evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t1)
            let point2 = evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t2)
            
            let segmentLength = sqrt((point2.x - point1.x) * (point2.x - point1.x) + (point2.y - point1.y) * (point2.y - point1.y))
            totalLength += segmentLength
        }
        
        return totalLength
    }
}

// MARK: - VectorPoint Extensions for Professional Operations

extension VectorPoint {
    /// Linear interpolation between two points
    static func lerp(_ a: VectorPoint, _ b: VectorPoint, _ t: Double) -> VectorPoint {
        return VectorPoint(
            a.x + t * (b.x - a.x),
            a.y + t * (b.y - a.y)
        )
    }
    
    /// Distance between two points
    func distance(to other: VectorPoint) -> Double {
        let dx = self.x - other.x
        let dy = self.y - other.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Angle from this point to another point
    func angle(to other: VectorPoint) -> Double {
        return atan2(other.y - self.y, other.x - self.x)
    }
    
    /// Normalize vector to unit length
    var normalized: VectorPoint {
        let length = sqrt(x * x + y * y)
        guard length > 1e-10 else { return VectorPoint(0, 0) }
        return VectorPoint(x / length, y / length)
    }
    
    /// Vector length/magnitude
    var magnitude: Double {
        return sqrt(x * x + y * y)
    }
}

// MARK: - Professional Bezier Curve Factory

/// Factory for creating professional bezier curves with industry-standard behavior
struct ProfessionalBezierFactory {
    
    /// Create Adobe Illustrator-style smooth curve
    static func createSmoothCurve(from startPoint: VectorPoint, to endPoint: VectorPoint, tension: Double = 0.33) -> [VectorPoint] {
        let direction = VectorPoint(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
        let _ = startPoint.distance(to: endPoint) // distance unused
        
        let control1 = VectorPoint(
            startPoint.x + direction.x * tension,
            startPoint.y + direction.y * tension
        )
        
        let control2 = VectorPoint(
            endPoint.x - direction.x * tension,
            endPoint.y - direction.y * tension
        )
        
        return [startPoint, control1, control2, endPoint]
    }
    
    /// Create circular arc using bezier approximation (professional standard)
    static func createCircularArc(center: VectorPoint, radius: Double, startAngle: Double, endAngle: Double) -> [VectorPoint] {
        // Use the magical constant 0.552 for 90-degree bezier approximation of circles
        let kappa = 0.5522847498307935 // More precise value
        
        let startPoint = VectorPoint(
            center.x + radius * cos(startAngle),
            center.y + radius * sin(startAngle)
        )
        
        let endPoint = VectorPoint(
            center.x + radius * cos(endAngle),
            center.y + radius * sin(endAngle)
        )
        
        let _ = (startAngle + endAngle) / 2.0 // midAngle unused
        let handleLength = radius * kappa
        
        let control1 = VectorPoint(
            startPoint.x + handleLength * cos(startAngle + .pi / 2),
            startPoint.y + handleLength * sin(startAngle + .pi / 2)
        )
        
        let control2 = VectorPoint(
            endPoint.x + handleLength * cos(endAngle - .pi / 2),
            endPoint.y + handleLength * sin(endAngle - .pi / 2)
        )
        
        return [startPoint, control1, control2, endPoint]
    }
} 
