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
    
    /// Create an oval path - a rounded, circle-like shape
    /// An oval is a smooth, rounded shape that's more circular than an ellipse
    internal func createOvalPath(rect: CGRect) -> VectorPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        
        // Use control points that create a more rounded, circle-like appearance
        // This makes the oval more rounded and less elliptical
        let controlPointOffsetX = radiusX * 0.58  // More rounded than ellipse's 0.552
        let controlPointOffsetY = radiusY * 0.58
        
        // Create a smooth oval using 4 curves, similar to ellipse but with slight variation
        return VectorPath(elements: [
            // Start at rightmost point
            .move(to: VectorPoint(center.x + radiusX, center.y)),
            
            // Curve 1: Right → Bottom
            .curve(to: VectorPoint(center.x, center.y + radiusY),
                   control1: VectorPoint(center.x + radiusX, center.y + controlPointOffsetY),
                   control2: VectorPoint(center.x + controlPointOffsetX, center.y + radiusY)),
            
            // Curve 2: Bottom → Left
            .curve(to: VectorPoint(center.x - radiusX, center.y),
                   control1: VectorPoint(center.x - controlPointOffsetX, center.y + radiusY),
                   control2: VectorPoint(center.x - radiusX, center.y + controlPointOffsetY)),
            
            // Curve 3: Left → Top
            .curve(to: VectorPoint(center.x, center.y - radiusY),
                   control1: VectorPoint(center.x - radiusX, center.y - controlPointOffsetY),
                   control2: VectorPoint(center.x - controlPointOffsetX, center.y - radiusY)),
            
            // Curve 4: Top → Right
            .curve(to: VectorPoint(center.x + radiusX, center.y),
                   control1: VectorPoint(center.x + controlPointOffsetX, center.y - radiusY),
                   control2: VectorPoint(center.x + radiusX, center.y - controlPointOffsetY)),
            
            .close
        ], isClosed: true)
    }
    
    /// Create an egg path using mathematical egg curve formula
    /// An egg shape is asymmetric with a pointed top and rounded bottom
    internal func createEggPath(rect: CGRect) -> VectorPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        
        // Egg shape parameters: wider at bottom, narrower at top
        let eggFactor = 0.3  // Controls the egg asymmetry
        let topRadiusX = radiusX * (1.0 - eggFactor)
        let topRadiusY = radiusY * (1.0 - eggFactor)
        let bottomRadiusX = radiusX * (1.0 + eggFactor * 0.5)
        let bottomRadiusY = radiusY * (1.0 + eggFactor * 0.5)
        
        // Create egg shape using modified ellipse curves
        // Top half (narrower)
        let topControlOffsetX = topRadiusX * 0.552
        let topControlOffsetY = topRadiusY * 0.552
        
        // Bottom half (wider)
        let bottomControlOffsetX = bottomRadiusX * 0.552
        let bottomControlOffsetY = bottomRadiusY * 0.552
        
        return VectorPath(elements: [
            // Start at top point
            .move(to: VectorPoint(center.x, center.y - topRadiusY)),
            
            // Top right curve (narrower)
            .curve(to: VectorPoint(center.x + topRadiusX, center.y),
                   control1: VectorPoint(center.x + topControlOffsetX, center.y - topRadiusY),
                   control2: VectorPoint(center.x + topRadiusX, center.y - topControlOffsetY)),
            
            // Bottom right curve (wider)
            .curve(to: VectorPoint(center.x, center.y + bottomRadiusY),
                   control1: VectorPoint(center.x + bottomRadiusX, center.y + bottomControlOffsetY),
                   control2: VectorPoint(center.x + bottomControlOffsetX, center.y + bottomRadiusY)),
            
            // Bottom left curve (wider)
            .curve(to: VectorPoint(center.x - bottomRadiusX, center.y),
                   control1: VectorPoint(center.x - bottomControlOffsetX, center.y + bottomRadiusY),
                   control2: VectorPoint(center.x - bottomRadiusX, center.y + bottomControlOffsetY)),
            
            // Top left curve (narrower)
            .curve(to: VectorPoint(center.x, center.y - topRadiusY),
                   control1: VectorPoint(center.x - topRadiusX, center.y - topControlOffsetY),
                   control2: VectorPoint(center.x - topControlOffsetX, center.y - topRadiusY)),
            
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
    
    /// Create a rounded rectangle path with individual corner radii (Adobe Illustrator style)
    internal func createRoundedRectPathWithIndividualCorners(rect: CGRect, cornerRadii: [Double]) -> VectorPath {
        // Ensure we have exactly 4 radii: [topLeft, topRight, bottomRight, bottomLeft]
        guard cornerRadii.count == 4 else {
            return createRoundedRectPath(rect: rect, cornerRadius: 0)
        }
        
        let topLeftRadius = min(cornerRadii[0], min(rect.width, rect.height) / 2)
        let topRightRadius = min(cornerRadii[1], min(rect.width, rect.height) / 2)
        let bottomRightRadius = min(cornerRadii[2], min(rect.width, rect.height) / 2)
        let bottomLeftRadius = min(cornerRadii[3], min(rect.width, rect.height) / 2)
        
        // Bezier control point offsets for each corner
        let topLeftOffset = topLeftRadius * 0.552
        let topRightOffset = topRightRadius * 0.552
        let bottomRightOffset = bottomRightRadius * 0.552
        let bottomLeftOffset = bottomLeftRadius * 0.552
        
        return VectorPath(elements: [
            // Start at top-left corner (after radius)
            .move(to: VectorPoint(rect.minX + topLeftRadius, rect.minY)),
            
            // Top edge
            .line(to: VectorPoint(rect.maxX - topRightRadius, rect.minY)),
            
            // Top-right corner curve
            .curve(to: VectorPoint(rect.maxX, rect.minY + topRightRadius),
                   control1: VectorPoint(rect.maxX - topRightRadius + topRightOffset, rect.minY),
                   control2: VectorPoint(rect.maxX, rect.minY + topRightRadius - topRightOffset)),
            
            // Right edge
            .line(to: VectorPoint(rect.maxX, rect.maxY - bottomRightRadius)),
            
            // Bottom-right corner curve
            .curve(to: VectorPoint(rect.maxX - bottomRightRadius, rect.maxY),
                   control1: VectorPoint(rect.maxX, rect.maxY - bottomRightRadius + bottomRightOffset),
                   control2: VectorPoint(rect.maxX - bottomRightRadius + bottomRightOffset, rect.maxY)),
            
            // Bottom edge
            .line(to: VectorPoint(rect.minX + bottomLeftRadius, rect.maxY)),
            
            // Bottom-left corner curve
            .curve(to: VectorPoint(rect.minX, rect.maxY - bottomLeftRadius),
                   control1: VectorPoint(rect.minX + bottomLeftRadius - bottomLeftOffset, rect.maxY),
                   control2: VectorPoint(rect.minX, rect.maxY - bottomLeftRadius + bottomLeftOffset)),
            
            // Left edge
            .line(to: VectorPoint(rect.minX, rect.minY + topLeftRadius)),
            
            // Top-left corner curve
            .curve(to: VectorPoint(rect.minX + topLeftRadius, rect.minY),
                   control1: VectorPoint(rect.minX, rect.minY + topLeftRadius - topLeftOffset),
                   control2: VectorPoint(rect.minX + topLeftRadius - topLeftOffset, rect.minY)),
            
            .close
        ], isClosed: true)
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
    
    /// Create an equilateral triangle path that fills the full rectangle bounds (like square tool)
    internal func createEquilateralTrianglePath(rect: CGRect) -> VectorPath {
        // Normalize rect to handle negative width/height from different drag directions
        let normalizedRect = CGRect(
            x: min(rect.minX, rect.maxX),
            y: min(rect.minY, rect.maxY),
            width: abs(rect.width),
            height: abs(rect.height)
        )
        
        // FIXED: Fill the entire rectangle bounds (like square tool), don't center it
        // Create equilateral triangle that fits within the full rectangle
        let topPoint = VectorPoint(normalizedRect.midX, normalizedRect.minY)
        let bottomLeft = VectorPoint(normalizedRect.minX, normalizedRect.maxY)
        let bottomRight = VectorPoint(normalizedRect.maxX, normalizedRect.maxY)
        
        return VectorPath(elements: [
            .move(to: topPoint),
            .line(to: bottomLeft),
            .line(to: bottomRight),
            .close
        ], isClosed: true)
    }
    
    /// Create a right triangle path that flips based on drag direction
    internal func createRightTrianglePath(rect: CGRect, dragDirection: String) -> VectorPath {
        // Normalize rect to get proper bounds, but handle flipping separately
        let normalizedRect = CGRect(
            x: min(rect.minX, rect.maxX),
            y: min(rect.minY, rect.maxY),
            width: abs(rect.width),
            height: abs(rect.height)
        )
        
        let topLeft = VectorPoint(normalizedRect.minX, normalizedRect.minY)
        let topRight = VectorPoint(normalizedRect.maxX, normalizedRect.minY)
        let bottomLeft = VectorPoint(normalizedRect.minX, normalizedRect.maxY)
        let bottomRight = VectorPoint(normalizedRect.maxX, normalizedRect.maxY)
        
        print("🔺 CREATE RIGHT TRIANGLE DEBUG:")
        print("  input rect: \(rect)")
        print("  normalizedRect: \(normalizedRect)")
        print("  topLeft: \(topLeft)")
        print("  topRight: \(topRight)")
        print("  bottomLeft: \(bottomLeft)")
        print("  bottomRight: \(bottomRight)")
        print("  dragDirection: \(dragDirection)")
        
        switch dragDirection {
        case "RIGHT_DOWN":
            // Dragging right and down: Right angle at top-left, sharp angle at bottom-right
            print("  CREATING: Right triangle for RIGHT_DOWN drag - right angle at top-left, points to bottom-right")
            return VectorPath(elements: [
                .move(to: topLeft),
                .line(to: bottomLeft),
                .line(to: bottomRight),
                .close
            ], isClosed: true)
            
        case "RIGHT_UP":
            // Dragging right and up: Right angle at bottom-left, sharp angle at top-right
            print("  CREATING: Right triangle for RIGHT_UP drag - right angle at bottom-left, points to top-right")
            return VectorPath(elements: [
                .move(to: bottomLeft),
                .line(to: topLeft),
                .line(to: topRight),
                .close
            ], isClosed: true)
            
        case "LEFT_DOWN":
            // Dragging left and down: Right angle at top-right, sharp angle at bottom-left
            print("  CREATING: Right triangle for LEFT_DOWN drag - right angle at top-right, points to bottom-left")
            return VectorPath(elements: [
                .move(to: topRight),
                .line(to: bottomRight),
                .line(to: bottomLeft),
                .close
            ], isClosed: true)
            
        case "LEFT_UP":
            // Dragging left and up: Right angle at bottom-right, sharp angle at top-left
            print("  CREATING: Right triangle for LEFT_UP drag - right angle at bottom-right, points to top-left")
            return VectorPath(elements: [
                .move(to: bottomRight),
                .line(to: topRight),
                .line(to: topLeft),
                .close
            ], isClosed: true)
            
        default:
            // Fallback to right-down for any unexpected direction
            print("  CREATING: Right triangle for UNKNOWN drag (\(dragDirection)) - using RIGHT_DOWN fallback")
            return VectorPath(elements: [
                .move(to: topLeft),
                .line(to: bottomLeft),
                .line(to: bottomRight),
                .close
            ], isClosed: true)
        }
    }
    
    /// Create an acute triangle path (all angles less than 90 degrees)
    internal func createAcuteTrianglePath(rect: CGRect) -> VectorPath {
        // Normalize rect to handle negative width/height from different drag directions
        let normalizedRect = CGRect(
            x: min(rect.minX, rect.maxX),
            y: min(rect.minY, rect.maxY),
            width: abs(rect.width),
            height: abs(rect.height)
        )
        
        // Create a tall, narrow triangle with all acute angles
        let baseWidth = normalizedRect.width * 0.6 // Make it narrower for acute angles
        
        let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
        let topPoint = VectorPoint(center.x, normalizedRect.minY)
        let bottomLeft = VectorPoint(center.x - baseWidth / 2, normalizedRect.maxY)
        let bottomRight = VectorPoint(center.x + baseWidth / 2, normalizedRect.maxY)
        
        return VectorPath(elements: [
            .move(to: topPoint),
            .line(to: bottomLeft),
            .line(to: bottomRight),
            .close
        ], isClosed: true)
    }
    
    /// Create an isosceles triangle path
    internal func createIsoscelesTrianglePath(rect: CGRect) -> VectorPath {
        // Normalize rect to handle negative width/height from different drag directions
        let normalizedRect = CGRect(
            x: min(rect.minX, rect.maxX),
            y: min(rect.minY, rect.maxY),
            width: abs(rect.width),
            height: abs(rect.height)
        )
        
        let topPoint = VectorPoint(normalizedRect.midX, normalizedRect.minY)
        let bottomLeft = VectorPoint(normalizedRect.minX, normalizedRect.maxY)
        let bottomRight = VectorPoint(normalizedRect.maxX, normalizedRect.maxY)
        
        return VectorPath(elements: [
            .move(to: topPoint),
            .line(to: bottomLeft),
            .line(to: bottomRight),
            .close
        ], isClosed: true)
    }
} 