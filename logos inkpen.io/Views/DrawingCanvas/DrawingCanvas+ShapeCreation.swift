//
//  ShapeCreation.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Shape Creation Functions
extension DrawingCanvas {
    
    /// Create a professional 4-curve circle path that FILLS the entire bounds (like rectangle/ellipse tools)
    internal func createCirclePath(rect: CGRect) -> VectorPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // FIXED: Fill entire bounds like rectangle tool, not just inscribed circle
        let radiusX = rect.width / 2   // Use full width
        let radiusY = rect.height / 2  // Use full height  
        let controlPointOffsetX = radiusX * 0.552
        let controlPointOffsetY = radiusY * 0.552
        
        // PROFESSIONAL 4-CURVE ELLIPSE that fills bounds: Each quadrant gets its own curve
        // Start at 3 o'clock, go clockwise: Right → Bottom → Left → Top → Back to Right
        return VectorPath(elements: [
            // Start at right (3 o'clock)
            .move(to: VectorPoint(center.x + radiusX, center.y)),
            
            // Curve 1: Right → Bottom (3 o'clock to 6 o'clock)
            .curve(to: VectorPoint(center.x, center.y + radiusY),
                   control1: VectorPoint(center.x + radiusX, center.y + controlPointOffsetY),
                   control2: VectorPoint(center.x + controlPointOffsetX, center.y + radiusY)),
            
            // Curve 2: Bottom → Left (6 o'clock to 9 o'clock)
            .curve(to: VectorPoint(center.x - radiusX, center.y),
                   control1: VectorPoint(center.x - controlPointOffsetX, center.y + radiusY),
                   control2: VectorPoint(center.x - radiusX, center.y + controlPointOffsetY)),
            
            // Curve 3: Left → Top (9 o'clock to 12 o'clock)
            .curve(to: VectorPoint(center.x, center.y - radiusY),
                   control1: VectorPoint(center.x - radiusX, center.y - controlPointOffsetY),
                   control2: VectorPoint(center.x - controlPointOffsetX, center.y - radiusY)),
            
            // Curve 4: Top → Right (12 o'clock back to 3 o'clock) - CRITICAL!
            // This completes the ellipse with a proper curve, not a straight line
            .curve(to: VectorPoint(center.x + radiusX, center.y),
                   control1: VectorPoint(center.x + controlPointOffsetX, center.y - radiusY),
                   control2: VectorPoint(center.x + radiusX, center.y - controlPointOffsetY)),
            
            // Close the path (this just marks it as closed, the curves do the actual work)
            .close
        ], isClosed: true)
    }

    /// Create a professional 4-curve circle path (legacy center/radius method)
    internal func createCirclePath(center: CGPoint, radius: Double) -> VectorPath {
        let controlPointOffset = radius * 0.552
        
        // PROFESSIONAL 4-CURVE CIRCLE: Each quadrant gets its own curve
        // Start at 3 o'clock, go clockwise: Right → Bottom → Left → Top → Back to Right
        return VectorPath(elements: [
            // Start at right (3 o'clock)
            .move(to: VectorPoint(center.x + radius, center.y)),
            
            // Curve 1: Right → Bottom (3 o'clock to 6 o'clock)
            .curve(to: VectorPoint(center.x, center.y + radius),
                   control1: VectorPoint(center.x + radius, center.y + controlPointOffset),
                   control2: VectorPoint(center.x + controlPointOffset, center.y + radius)),
            
            // Curve 2: Bottom → Left (6 o'clock to 9 o'clock)
            .curve(to: VectorPoint(center.x - radius, center.y),
                   control1: VectorPoint(center.x - controlPointOffset, center.y + radius),
                   control2: VectorPoint(center.x - radius, center.y + controlPointOffset)),
            
            // Curve 3: Left → Top (9 o'clock to 12 o'clock)
            .curve(to: VectorPoint(center.x, center.y - radius),
                   control1: VectorPoint(center.x - radius, center.y - controlPointOffset),
                   control2: VectorPoint(center.x - controlPointOffset, center.y - radius)),
            
            // Curve 4: Top → Right (12 o'clock back to 3 o'clock) - CRITICAL!
            // This completes the circle with a proper curve, not a straight line
            .curve(to: VectorPoint(center.x + radius, center.y),
                   control1: VectorPoint(center.x + controlPointOffset, center.y - radius),
                   control2: VectorPoint(center.x + radius, center.y - controlPointOffset)),
            
            // Close the path (this just marks it as closed, the curves do the actual work)
            .close
        ], isClosed: true)
    }
    
    /// Create a professional 4-curve ellipse path
    internal func createEllipsePath(rect: CGRect) -> VectorPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        let controlPointOffsetX = radiusX * 0.552
        let controlPointOffsetY = radiusY * 0.552
        
        // PROFESSIONAL 4-CURVE ELLIPSE: Each quadrant gets its own curve
        // Start at 3 o'clock, go clockwise: Right → Bottom → Left → Top → Back to Right
        return VectorPath(elements: [
            // Start at right (3 o'clock)
            .move(to: VectorPoint(center.x + radiusX, center.y)),
            
            // Curve 1: Right → Bottom (3 o'clock to 6 o'clock)
            .curve(to: VectorPoint(center.x, center.y + radiusY),
                   control1: VectorPoint(center.x + radiusX, center.y + controlPointOffsetY),
                   control2: VectorPoint(center.x + controlPointOffsetX, center.y + radiusY)),
            
            // Curve 2: Bottom → Left (6 o'clock to 9 o'clock)
            .curve(to: VectorPoint(center.x - radiusX, center.y),
                   control1: VectorPoint(center.x - controlPointOffsetX, center.y + radiusY),
                   control2: VectorPoint(center.x - radiusX, center.y + controlPointOffsetY)),
            
            // Curve 3: Left → Top (9 o'clock to 12 o'clock)
            .curve(to: VectorPoint(center.x, center.y - radiusY),
                   control1: VectorPoint(center.x - radiusX, center.y - controlPointOffsetY),
                   control2: VectorPoint(center.x - controlPointOffsetX, center.y - radiusY)),
            
            // Curve 4: Top → Right (12 o'clock back to 3 o'clock)
            .curve(to: VectorPoint(center.x + radiusX, center.y),
                   control1: VectorPoint(center.x + controlPointOffsetX, center.y - radiusY),
                   control2: VectorPoint(center.x + radiusX, center.y - controlPointOffsetY)),
            
            // Close the path
            .close
        ], isClosed: true)
    }
    
    /// Create a star path with specified parameters
    internal func createStarPath(center: CGPoint, outerRadius: Double, innerRadius: Double, points: Int) -> VectorPath {
        var elements: [PathElement] = []
        let angleStep = .pi / Double(points)
        
        for i in 0..<(points * 2) {
            let angle = Double(i) * angleStep - .pi / 2 // Start at top
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            if i == 0 {
                elements.append(.move(to: VectorPoint(x, y)))
            } else {
                elements.append(.line(to: VectorPoint(x, y)))
            }
        }
        elements.append(.close)
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    /// Create a polygon path with specified parameters
    internal func createPolygonPath(center: CGPoint, radius: Double, sides: Int) -> VectorPath {
        var elements: [PathElement] = []
        let angleStep = 2 * .pi / Double(sides)
        
        for i in 0..<sides {
            let angle = Double(i) * angleStep - .pi / 2 // Start at top
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            if i == 0 {
                elements.append(.move(to: VectorPoint(x, y)))
            } else {
                elements.append(.line(to: VectorPoint(x, y)))
            }
        }
        elements.append(.close)
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    /// Create a simple circle path for testing purposes
    internal func createTestCirclePath(center: CGPoint, radius: Double) -> VectorPath {
        let steps = 32 // Number of segments for circle approximation
        var elements: [PathElement] = []
        
        for i in 0...steps {
            let angle = Double(i) * 2.0 * .pi / Double(steps)
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            if i == 0 {
                elements.append(.move(to: VectorPoint(x, y)))
            } else {
                elements.append(.line(to: VectorPoint(x, y)))
            }
        }
        elements.append(.close)
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    /// Create a rounded rectangle path
    internal func createRoundedRectPath(rect: CGRect, cornerRadius: Double) -> VectorPath {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        let controlPointOffset = radius * 0.552 // Bezier curve control point offset
        
        return VectorPath(elements: [
            // Start at top-left corner (after radius)
            .move(to: VectorPoint(rect.minX + radius, rect.minY)),
            
            // Top edge
            .line(to: VectorPoint(rect.maxX - radius, rect.minY)),
            
            // Top-right corner curve
            .curve(to: VectorPoint(rect.maxX, rect.minY + radius),
                   control1: VectorPoint(rect.maxX - radius + controlPointOffset, rect.minY),
                   control2: VectorPoint(rect.maxX, rect.minY + radius - controlPointOffset)),
            
            // Right edge
            .line(to: VectorPoint(rect.maxX, rect.maxY - radius)),
            
            // Bottom-right corner curve
            .curve(to: VectorPoint(rect.maxX - radius, rect.maxY),
                   control1: VectorPoint(rect.maxX, rect.maxY - radius + controlPointOffset),
                   control2: VectorPoint(rect.maxX - radius + controlPointOffset, rect.maxY)),
            
            // Bottom edge
            .line(to: VectorPoint(rect.minX + radius, rect.maxY)),
            
            // Bottom-left corner curve
            .curve(to: VectorPoint(rect.minX, rect.maxY - radius),
                   control1: VectorPoint(rect.minX + radius - controlPointOffset, rect.maxY),
                   control2: VectorPoint(rect.minX, rect.maxY - radius + controlPointOffset)),
            
            // Left edge
            .line(to: VectorPoint(rect.minX, rect.minY + radius)),
            
            // Top-left corner curve
            .curve(to: VectorPoint(rect.minX + radius, rect.minY),
                   control1: VectorPoint(rect.minX, rect.minY + radius - controlPointOffset),
                   control2: VectorPoint(rect.minX + radius - controlPointOffset, rect.minY)),
            
            .close
        ], isClosed: true)
    }
    
    /// Create an equilateral triangle path
    internal func createEquilateralTrianglePath(rect: CGRect) -> VectorPath {
        let size = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let height = size * sqrt(3) / 2
        
        let topPoint = VectorPoint(center.x, center.y - height / 2)
        let bottomLeft = VectorPoint(center.x - size / 2, center.y + height / 2)
        let bottomRight = VectorPoint(center.x + size / 2, center.y + height / 2)
        
        return VectorPath(elements: [
            .move(to: topPoint),
            .line(to: bottomLeft),
            .line(to: bottomRight),
            .close
        ], isClosed: true)
    }
    
    /// Create a right triangle path
    internal func createRightTrianglePath(rect: CGRect) -> VectorPath {
        let topLeft = VectorPoint(rect.minX, rect.minY)
        let bottomLeft = VectorPoint(rect.minX, rect.maxY)
        let bottomRight = VectorPoint(rect.maxX, rect.maxY)
        
        return VectorPath(elements: [
            .move(to: topLeft),
            .line(to: bottomLeft),
            .line(to: bottomRight),
            .close
        ], isClosed: true)
    }
    
    /// Create an acute triangle path (all angles less than 90 degrees)
    internal func createAcuteTrianglePath(rect: CGRect) -> VectorPath {
        // Create a tall, narrow triangle with all acute angles
        let baseWidth = rect.width * 0.6 // Make it narrower for acute angles
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let topPoint = VectorPoint(center.x, rect.minY)
        let bottomLeft = VectorPoint(center.x - baseWidth / 2, rect.maxY)
        let bottomRight = VectorPoint(center.x + baseWidth / 2, rect.maxY)
        
        return VectorPath(elements: [
            .move(to: topPoint),
            .line(to: bottomLeft),
            .line(to: bottomRight),
            .close
        ], isClosed: true)
    }
    
    /// Create an isosceles triangle path
    internal func createIsoscelesTrianglePath(rect: CGRect) -> VectorPath {
        let topPoint = VectorPoint(rect.midX, rect.minY)
        let bottomLeft = VectorPoint(rect.minX, rect.maxY)
        let bottomRight = VectorPoint(rect.maxX, rect.maxY)
        
        return VectorPath(elements: [
            .move(to: topPoint),
            .line(to: bottomLeft),
            .line(to: bottomRight),
            .close
        ], isClosed: true)
    }
} 