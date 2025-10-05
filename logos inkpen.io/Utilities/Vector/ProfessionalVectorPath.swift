//
//  ProfessionalVectorPath.swift
//  logos
//
//  Professional Vector Path
//  Implements advanced bezier curve mathematics and anchor point types
//
//  Created by Todd Bruss on 7/6/25.
//

import SwiftUI

// MARK: - Professional Vector Path Structure

/// Uses advanced bezier mathematics and professional anchor point types
struct ProfessionalVectorPath: Codable, Hashable, Identifiable {
    var id: UUID
    var points: [ProfessionalBezierMathematics.BezierPoint]  // Professional bezier points with handles
    var isClosed: Bool
    var pathStyle: PathStyle                                 // Professional path style settings
    var continuityConstraints: [ContinuityConstraint]        // G0, G1, G2 continuity constraints
    
    /// Professional path style settings
    struct PathStyle: Codable, Hashable {
        var tension: Double = 0.33                          // Default tension for auto-generated handles
        var handleVisibility: HandleVisibility = .selected  // When to show handles
        var snapToGrid: Bool = false                        // Professional grid snapping
        var smartGuides: Bool = true                        // smart guides
        var precisionMode: Bool = false                     // High precision calculation mode
        
        enum HandleVisibility: String, Codable, CaseIterable {
            case never = "Never"
            case selected = "Selected"
            case always = "Always"
            case onHover = "On Hover"
        }
    }
    
    /// Continuity constraint between two adjacent curve segments
    struct ContinuityConstraint: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var pointIndex: Int                                 // Index of the connection point
        var continuityType: ProfessionalBezierMathematics.ContinuityType
        var isLocked: Bool = false                          // Whether constraint is locked
        var tolerance: Double = 1e-6                       // Tolerance for continuity checking
    }
    
    init(points: [ProfessionalBezierMathematics.BezierPoint] = [], 
         isClosed: Bool = false,
         pathStyle: PathStyle = PathStyle()) {
        self.id = UUID()
        self.points = points
        self.isClosed = isClosed
        self.pathStyle = pathStyle
        self.continuityConstraints = []
        
        // Initialize continuity constraints for adjacent points
        if points.count > 1 {
            for i in 0..<points.count - 1 {
                continuityConstraints.append(ContinuityConstraint(
                    pointIndex: i,
                    continuityType: .g1  // Default to G1 continuity
                ))
            }
        }
    }
    
    // MARK: - Professional Path Operations
    
    /// Add a professional bezier point to the path
    mutating func addPoint(_ point: ProfessionalBezierMathematics.BezierPoint) {
        points.append(point)
        
        // Add continuity constraint if this isn't the first point
        if points.count > 1 {
            continuityConstraints.append(ContinuityConstraint(
                pointIndex: points.count - 2,
                continuityType: .g1
            ))
        }
    }
    
    /// Insert a point at specific index with automatic handle generation
    mutating func insertPoint(_ point: ProfessionalBezierMathematics.BezierPoint, at index: Int) {
        guard index >= 0 && index <= points.count else { return }
        
        if index == points.count {
            addPoint(point)
            return
        }
        
        points.insert(point, at: index)
        
        // Update continuity constraints
        regenerateContinuityConstraints()
    }
    
    /// Remove point at index and update continuity
    mutating func removePoint(at index: Int) {
        guard index >= 0 && index < points.count else { return }
        
        points.remove(at: index)
        regenerateContinuityConstraints()
    }
    
    /// Update point at index with handle recalculation
    mutating func updatePoint(at index: Int, newPoint: ProfessionalBezierMathematics.BezierPoint, maintainContinuity: Bool = true) {
        guard index >= 0 && index < points.count else { return }
        
        points[index] = newPoint
        
        if maintainContinuity {
            enforceLocalContinuity(at: index)
        }
    }
    
    /// Close the path and ensure proper continuity at connection point
    mutating func close() {
        guard !isClosed && points.count >= 3 else { return }
        
        isClosed = true
        
        // Add continuity constraint between last and first point
        continuityConstraints.append(ContinuityConstraint(
            pointIndex: points.count - 1,
            continuityType: .g1
        ))
        
        // Ensure continuity at the closing point
        enforceClosingContinuity()
    }
    
    /// Open the path
    mutating func open() {
        guard isClosed else { return }
        
        isClosed = false
        
        // Remove closing continuity constraint
        continuityConstraints.removeAll { $0.pointIndex == points.count - 1 }
    }
    
    // MARK: - Professional Handle Operations
    
    /// Generate smooth handles for all points using algorithm
    mutating func generateSmoothHandles() {
        for i in 0..<points.count {
            let previousPoint = (i > 0) ? points[i - 1].point : (isClosed ? points.last?.point : nil)
            let nextPoint = (i < points.count - 1) ? points[i + 1].point : (isClosed ? points.first?.point : nil)
            
            if points[i].pointType == .smoothCurve || points[i].pointType == .smoothCorner {
                let (incomingHandle, outgoingHandle) = ProfessionalBezierMathematics.generateSmoothHandles(
                    previousPoint: previousPoint,
                    currentPoint: points[i].point,
                    nextPoint: nextPoint,
                    tension: pathStyle.tension
                )
                
                points[i].incomingHandle = incomingHandle
                points[i].outgoingHandle = outgoingHandle
            }
        }
    }
    
    /// Convert point type and adjust handles accordingly
    mutating func convertPointType(at index: Int, to newType: ProfessionalBezierMathematics.AnchorPointType) {
        guard index >= 0 && index < points.count else { return }
        
        let oldPoint = points[index]
        var newPoint = oldPoint
        newPoint.pointType = newType
        
        switch newType {
        case .corner:
            // Remove handles for corner points
            newPoint.incomingHandle = nil
            newPoint.outgoingHandle = nil
            newPoint.handleConstraint = .independent
            
        case .smoothCurve:
            // Generate symmetric handles
            newPoint.handleConstraint = .symmetric
            generateHandlesForPoint(at: index, pointType: newType)
            
        case .smoothCorner:
            // Generate aligned handles with different lengths
            newPoint.handleConstraint = .aligned
            generateHandlesForPoint(at: index, pointType: newType)
            
        case .cusp:
            // Keep existing handles but make them independent
            newPoint.handleConstraint = .independent
            
        case .connector:
            // FreeHand-style automatic handles
            newPoint.handleConstraint = .automatic
            generateHandlesForPoint(at: index, pointType: newType)
        }
        
        points[index] = newPoint
    }
    
    /// Generate handles for a specific point based on its type
    private mutating func generateHandlesForPoint(at index: Int, pointType: ProfessionalBezierMathematics.AnchorPointType) {
        guard index >= 0 && index < points.count else { return }
        
        let previousPoint = (index > 0) ? points[index - 1].point : (isClosed ? points.last?.point : nil)
        let nextPoint = (index < points.count - 1) ? points[index + 1].point : (isClosed ? points.first?.point : nil)
        
        let (incomingHandle, outgoingHandle) = ProfessionalBezierMathematics.generateSmoothHandles(
            previousPoint: previousPoint,
            currentPoint: points[index].point,
            nextPoint: nextPoint,
            tension: pathStyle.tension
        )
        
        switch pointType {
        case .smoothCurve:
            // Symmetric handles
            if let incoming = incomingHandle, let outgoing = outgoingHandle {
                let avgLength = (points[index].point.distance(to: incoming) + points[index].point.distance(to: outgoing)) / 2.0
                let direction = points[index].point.angle(to: outgoing)
                
                points[index].incomingHandle = VectorPoint(
                    points[index].point.x - cos(direction) * avgLength,
                    points[index].point.y - sin(direction) * avgLength
                )
                points[index].outgoingHandle = VectorPoint(
                    points[index].point.x + cos(direction) * avgLength,
                    points[index].point.y + sin(direction) * avgLength
                )
            }
            
        case .smoothCorner:
            // Aligned handles with different lengths
            points[index].incomingHandle = incomingHandle
            points[index].outgoingHandle = outgoingHandle
            
        case .connector:
            // FreeHand-style intelligent handles
            points[index].incomingHandle = incomingHandle
            points[index].outgoingHandle = outgoingHandle
            
        default:
            break
        }
    }
    
    // MARK: - Continuity Management
    
    /// Regenerate all continuity constraints
    private mutating func regenerateContinuityConstraints() {
        continuityConstraints.removeAll()
        
        for i in 0..<max(0, points.count - 1) {
            continuityConstraints.append(ContinuityConstraint(
                pointIndex: i,
                continuityType: .g1
            ))
        }
        
        if isClosed && points.count > 2 {
            continuityConstraints.append(ContinuityConstraint(
                pointIndex: points.count - 1,
                continuityType: .g1
            ))
        }
    }
    
    /// Enforce continuity constraints at a specific point
    private mutating func enforceLocalContinuity(at index: Int) {
        guard index >= 0 && index < points.count else { return }
        
        // Find continuity constraints affecting this point
        let relevantConstraints = continuityConstraints.filter { constraint in
            constraint.pointIndex == index || constraint.pointIndex == index - 1
        }
        
        for constraint in relevantConstraints where constraint.isLocked {
            enforceContinuityConstraint(constraint)
        }
    }
    
    /// Enforce a specific continuity constraint
    private mutating func enforceContinuityConstraint(_ constraint: ContinuityConstraint) {
        let index = constraint.pointIndex
        guard index >= 0 && index < points.count - 1 else { return }
        
        let currentPoint = points[index]
        let nextPoint = points[index + 1]
        
        switch constraint.continuityType {
        case .g1:
            // Ensure tangent continuity
            if let outgoing = currentPoint.outgoingHandle,
               nextPoint.incomingHandle != nil {
                
                // Make handles collinear
                let direction = currentPoint.point.angle(to: outgoing)
                let incomingLength = nextPoint.point.distance(to: nextPoint.incomingHandle!)
                
                points[index + 1].incomingHandle = VectorPoint(
                    nextPoint.point.x - cos(direction) * incomingLength,
                    nextPoint.point.y - sin(direction) * incomingLength
                )
            }
            
        case .c1:
            // Ensure first derivative continuity (same magnitude)
            if let outgoing = currentPoint.outgoingHandle {
                
                let direction = currentPoint.point.angle(to: outgoing)
                let outgoingLength = currentPoint.point.distance(to: outgoing)
                
                points[index + 1].incomingHandle = VectorPoint(
                    nextPoint.point.x - cos(direction) * outgoingLength,
                    nextPoint.point.y - sin(direction) * outgoingLength
                )
            }
            
        default:
            break
        }
    }
    
    /// Enforce continuity at the closing point of a closed path
    private mutating func enforceClosingContinuity() {
        guard isClosed && points.count > 2 else { return }
        
        let lastIndex = points.count - 1
        let firstPoint = points[0]
        let lastPoint = points[lastIndex]
        
        // Ensure the closing segment has proper continuity
        if let lastOutgoing = lastPoint.outgoingHandle,
           let firstIncoming = firstPoint.incomingHandle {
            
            let direction = lastPoint.point.angle(to: lastOutgoing)
            let incomingLength = firstPoint.point.distance(to: firstIncoming)
            
            points[0].incomingHandle = VectorPoint(
                firstPoint.point.x - cos(direction) * incomingLength,
                firstPoint.point.y - sin(direction) * incomingLength
            )
        }
    }
    
    // MARK: - Conversion to Legacy VectorPath
    
    /// Convert to legacy VectorPath for compatibility
    func toLegacyVectorPath() -> VectorPath {
        guard !points.isEmpty else {
            return VectorPath(elements: [], isClosed: isClosed)
        }
        
        var elements: [PathElement] = []
        
        // Start with move to first point
        elements.append(.move(to: points[0].point))
        
        // Generate curve elements for each segment
        for i in 1..<points.count {
            let currentPoint = points[i]
            let previousPoint = points[i - 1]
            
            if let prevOutgoing = previousPoint.outgoingHandle,
               let currIncoming = currentPoint.incomingHandle {
                // Create cubic bezier curve
                elements.append(.curve(
                    to: currentPoint.point,
                    control1: prevOutgoing,
                    control2: currIncoming
                ))
            } else {
                // Create straight line
                elements.append(.line(to: currentPoint.point))
            }
        }
        
        // Handle closing segment for closed paths
        if isClosed,
           let lastPoint = points.last,
           let firstPoint = points.first {
            
            if let lastOutgoing = lastPoint.outgoingHandle,
               let firstIncoming = firstPoint.incomingHandle {
                elements.append(.curve(
                    to: firstPoint.point,
                    control1: lastOutgoing,
                    control2: firstIncoming
                ))
            } else {
                elements.append(.line(to: firstPoint.point))
            }
            
            elements.append(.close)
        }
        
        return VectorPath(elements: elements, isClosed: isClosed)
    }
    
    // MARK: - Conversion from Legacy VectorPath
    
    /// Create from legacy VectorPath
    static func fromLegacyVectorPath(_ legacyPath: VectorPath) -> ProfessionalVectorPath {
        var professionalPoints: [ProfessionalBezierMathematics.BezierPoint] = []
        var currentPoint: VectorPoint?
        
        for element in legacyPath.elements {
            switch element {
            case .move(let to):
                currentPoint = to
                professionalPoints.append(ProfessionalBezierMathematics.BezierPoint.cornerPoint(at: to))
                
            case .line(let to):
                professionalPoints.append(ProfessionalBezierMathematics.BezierPoint.cornerPoint(at: to))
                currentPoint = to
                
            case .curve(let to, let control1, let control2):
                // Update previous point's outgoing handle
                if !professionalPoints.isEmpty {
                    professionalPoints[professionalPoints.count - 1].outgoingHandle = control1
                    professionalPoints[professionalPoints.count - 1].pointType = .smoothCurve
                    professionalPoints[professionalPoints.count - 1].handleConstraint = .symmetric
                }
                
                // Add new point with incoming handle
                let newPoint = ProfessionalBezierMathematics.BezierPoint(
                    point: to,
                    incomingHandle: control2,
                    outgoingHandle: nil,
                    pointType: .smoothCurve,
                    handleConstraint: .symmetric
                )
                professionalPoints.append(newPoint)
                currentPoint = to
                
            case .quadCurve(let to, let control):
                // Convert quadratic to cubic
                if let current = currentPoint {
                    let control1 = VectorPoint(
                        current.x + (2.0/3.0) * (control.x - current.x),
                        current.y + (2.0/3.0) * (control.y - current.y)
                    )
                    let control2 = VectorPoint(
                        to.x + (2.0/3.0) * (control.x - to.x),
                        to.y + (2.0/3.0) * (control.y - to.y)
                    )
                    
                    // Update previous point's outgoing handle
                    if !professionalPoints.isEmpty {
                        professionalPoints[professionalPoints.count - 1].outgoingHandle = control1
                        professionalPoints[professionalPoints.count - 1].pointType = .smoothCurve
                    }
                    
                    // Add new point with incoming handle
                    let newPoint = ProfessionalBezierMathematics.BezierPoint(
                        point: to,
                        incomingHandle: control2,
                        outgoingHandle: nil,
                        pointType: .smoothCurve,
                        handleConstraint: .symmetric
                    )
                    professionalPoints.append(newPoint)
                }
                currentPoint = to
                
            case .close:
                break // Handled by isClosed flag
            }
        }
        
        var professionalPath = ProfessionalVectorPath(
            points: professionalPoints,
            isClosed: legacyPath.isClosed
        )
        
        // Generate smooth handles for all curve points
        professionalPath.generateSmoothHandles()
        
        return professionalPath
    }
    
    // MARK: - Professional Analysis Methods

    struct PathAnalysis {
        var issues: [String] = []
        var suggestions: [String] = []
        var quality: Double = 1.0
        var continuityIssues: [ContinuityIssue] = []
    }

    struct ContinuityIssue {
        // Empty struct for now
    }

    /// Analyze path for quality and suggest improvements
    func analyzePath() -> PathAnalysis {
        var analysis = PathAnalysis()
        
        // Check for continuity issues
        for i in 0..<points.count - 1 {
            if let constraint = continuityConstraints.first(where: { $0.pointIndex == i }) {
                let curve1 = getSegmentPoints(at: i)
                let curve2 = getSegmentPoints(at: i + 1)
                
                if let c1 = curve1, let c2 = curve2 {
                    let actualContinuity = ProfessionalBezierMathematics.analyzeContinuity(
                        curve1: c1,
                        curve2: c2,
                        tolerance: constraint.tolerance
                    )
                    
                    if actualContinuity.priority < constraint.continuityType.priority {
                        analysis.continuityIssues.append(ContinuityIssue())
                    }
                }
            }
        }

        return analysis
    }
    
    /// Get the four control points for a curve segment
    private func getSegmentPoints(at index: Int) -> [VectorPoint]? {
        guard index >= 0 && index < points.count - 1 else { return nil }
        
        let p0 = points[index].point
        let p3 = points[index + 1].point
        
        let p1 = points[index].outgoingHandle ?? p0
        let p2 = points[index + 1].incomingHandle ?? p3
        
        return [p0, p1, p2, p3]
    }
    
}
