//
//  GeometricShapes.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import CoreGraphics

class GeometricShapes {
    
    // MARK: - Rectangle
    static func createRectangle(origin: CGPoint, size: CGSize, cornerRadius: CGFloat = 0) -> VectorPath {
        let rect = CGRect(origin: origin, size: size)
        var elements: [PathElement] = []
        
        if cornerRadius > 0 {
            // Rounded rectangle
            let radius = min(cornerRadius, min(size.width, size.height) / 2)
            
            elements.append(.move(to: VectorPoint(rect.minX + radius, rect.minY)))
            elements.append(.line(to: VectorPoint(rect.maxX - radius, rect.minY)))
            elements.append(.curve(to: VectorPoint(rect.maxX, rect.minY + radius),
                                 control1: VectorPoint(rect.maxX - radius * 0.552, rect.minY),
                                 control2: VectorPoint(rect.maxX, rect.minY + radius * 0.552)))
            elements.append(.line(to: VectorPoint(rect.maxX, rect.maxY - radius)))
            elements.append(.curve(to: VectorPoint(rect.maxX - radius, rect.maxY),
                                 control1: VectorPoint(rect.maxX, rect.maxY - radius * 0.552),
                                 control2: VectorPoint(rect.maxX - radius * 0.552, rect.maxY)))
            elements.append(.line(to: VectorPoint(rect.minX + radius, rect.maxY)))
            elements.append(.curve(to: VectorPoint(rect.minX, rect.maxY - radius),
                                 control1: VectorPoint(rect.minX + radius * 0.552, rect.maxY),
                                 control2: VectorPoint(rect.minX, rect.maxY - radius * 0.552)))
            elements.append(.line(to: VectorPoint(rect.minX, rect.minY + radius)))
            elements.append(.curve(to: VectorPoint(rect.minX + radius, rect.minY),
                                 control1: VectorPoint(rect.minX, rect.minY + radius * 0.552),
                                 control2: VectorPoint(rect.minX + radius * 0.552, rect.minY)))
            elements.append(.close)
        } else {
            // Regular rectangle
            elements.append(.move(to: VectorPoint(rect.minX, rect.minY)))
            elements.append(.line(to: VectorPoint(rect.maxX, rect.minY)))
            elements.append(.line(to: VectorPoint(rect.maxX, rect.maxY)))
            elements.append(.line(to: VectorPoint(rect.minX, rect.maxY)))
            elements.append(.close)
        }
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    // MARK: - Circle
    static func createCircle(center: CGPoint, radius: CGFloat) -> VectorPath {
        let controlPointOffset = radius * 0.552
        
        let elements: [PathElement] = [
            .move(to: VectorPoint(center.x + radius, center.y)),
            .curve(to: VectorPoint(center.x, center.y + radius),
                   control1: VectorPoint(center.x + radius, center.y + controlPointOffset),
                   control2: VectorPoint(center.x + controlPointOffset, center.y + radius)),
            .curve(to: VectorPoint(center.x - radius, center.y),
                   control1: VectorPoint(center.x - controlPointOffset, center.y + radius),
                   control2: VectorPoint(center.x - radius, center.y + controlPointOffset)),
            .curve(to: VectorPoint(center.x, center.y - radius),
                   control1: VectorPoint(center.x - radius, center.y - controlPointOffset),
                   control2: VectorPoint(center.x - controlPointOffset, center.y - radius)),
            .curve(to: VectorPoint(center.x + radius, center.y),
                   control1: VectorPoint(center.x + controlPointOffset, center.y - radius),
                   control2: VectorPoint(center.x + radius, center.y - controlPointOffset)),
            .close
        ]
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    // MARK: - Ellipse
    static func createEllipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) -> VectorPath {
        let controlPointOffsetX = radiusX * 0.552
        let controlPointOffsetY = radiusY * 0.552
        
        let elements: [PathElement] = [
            .move(to: VectorPoint(center.x + radiusX, center.y)),
            .curve(to: VectorPoint(center.x, center.y + radiusY),
                   control1: VectorPoint(center.x + radiusX, center.y + controlPointOffsetY),
                   control2: VectorPoint(center.x + controlPointOffsetX, center.y + radiusY)),
            .curve(to: VectorPoint(center.x - radiusX, center.y),
                   control1: VectorPoint(center.x - controlPointOffsetX, center.y + radiusY),
                   control2: VectorPoint(center.x - radiusX, center.y + controlPointOffsetY)),
            .curve(to: VectorPoint(center.x, center.y - radiusY),
                   control1: VectorPoint(center.x - radiusX, center.y - controlPointOffsetY),
                   control2: VectorPoint(center.x - controlPointOffsetX, center.y - radiusY)),
            .curve(to: VectorPoint(center.x + radiusX, center.y),
                   control1: VectorPoint(center.x + controlPointOffsetX, center.y - radiusY),
                   control2: VectorPoint(center.x + radiusX, center.y - controlPointOffsetY)),
            .close
        ]
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    // MARK: - Triangle
    static func createTriangle(center: CGPoint, radius: CGFloat, orientation: CGFloat = 0) -> VectorPath {
        let points = regularPolygonPoints(center: center, radius: radius, sides: 3, orientation: orientation)
        
        let elements: [PathElement] = [
            .move(to: VectorPoint(points[0])),
            .line(to: VectorPoint(points[1])),
            .line(to: VectorPoint(points[2])),
            .close
        ]
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    // MARK: - Regular Polygon
    static func createRegularPolygon(center: CGPoint, radius: CGFloat, sides: Int, orientation: CGFloat = 0) -> VectorPath {
        let points = regularPolygonPoints(center: center, radius: radius, sides: sides, orientation: orientation)
        
        var elements: [PathElement] = [.move(to: VectorPoint(points[0]))]
        
        for i in 1..<points.count {
            elements.append(.line(to: VectorPoint(points[i])))
        }
        
        elements.append(.close)
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    // MARK: - Star
    static func createStar(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, points: Int, orientation: CGFloat = 0) -> VectorPath {
        var elements: [PathElement] = []
        let angleStep = .pi / Double(points)
        
        for i in 0..<(points * 2) {
            let angle = Double(i) * angleStep + Double(orientation) - .pi / 2
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
    
    // MARK: - Pentagon
    static func createPentagon(center: CGPoint, radius: CGFloat, orientation: CGFloat = 0) -> VectorPath {
        return createRegularPolygon(center: center, radius: radius, sides: 5, orientation: orientation)
    }
    
    // MARK: - Hexagon
    static func createHexagon(center: CGPoint, radius: CGFloat, orientation: CGFloat = 0) -> VectorPath {
        return createRegularPolygon(center: center, radius: radius, sides: 6, orientation: orientation)
    }
    
    // MARK: - Octagon
    static func createOctagon(center: CGPoint, radius: CGFloat, orientation: CGFloat = 0) -> VectorPath {
        return createRegularPolygon(center: center, radius: radius, sides: 8, orientation: orientation)
    }
    
    // MARK: - Diamond
    static func createDiamond(center: CGPoint, width: CGFloat, height: CGFloat) -> VectorPath {
        let halfWidth = width / 2
        let halfHeight = height / 2
        
        let elements: [PathElement] = [
            .move(to: VectorPoint(center.x, center.y - halfHeight)),
            .line(to: VectorPoint(center.x + halfWidth, center.y)),
            .line(to: VectorPoint(center.x, center.y + halfHeight)),
            .line(to: VectorPoint(center.x - halfWidth, center.y)),
            .close
        ]
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    // MARK: - Heart
    static func createHeart(center: CGPoint, size: CGFloat) -> VectorPath {
        let scale = size / 100.0
        
        // Heart shape based on mathematical formula
        var elements: [PathElement] = []
        
        // Start at bottom point
        elements.append(.move(to: VectorPoint(center.x, center.y + 30 * scale)))
        
        // Left curve
        elements.append(.curve(to: VectorPoint(center.x - 25 * scale, center.y - 10 * scale),
                             control1: VectorPoint(center.x - 15 * scale, center.y + 15 * scale),
                             control2: VectorPoint(center.x - 25 * scale, center.y + 5 * scale)))
        
        // Left top curve
        elements.append(.curve(to: VectorPoint(center.x - 10 * scale, center.y - 25 * scale),
                             control1: VectorPoint(center.x - 25 * scale, center.y - 25 * scale),
                             control2: VectorPoint(center.x - 20 * scale, center.y - 25 * scale)))
        
        // Top center
        elements.append(.curve(to: VectorPoint(center.x, center.y - 10 * scale),
                             control1: VectorPoint(center.x, center.y - 25 * scale),
                             control2: VectorPoint(center.x, center.y - 15 * scale)))
        
        // Right top curve
        elements.append(.curve(to: VectorPoint(center.x + 10 * scale, center.y - 25 * scale),
                             control1: VectorPoint(center.x, center.y - 15 * scale),
                             control2: VectorPoint(center.x, center.y - 25 * scale)))
        
        // Right curve
        elements.append(.curve(to: VectorPoint(center.x + 25 * scale, center.y - 10 * scale),
                             control1: VectorPoint(center.x + 20 * scale, center.y - 25 * scale),
                             control2: VectorPoint(center.x + 25 * scale, center.y - 25 * scale)))
        
        // Right side
        elements.append(.curve(to: VectorPoint(center.x, center.y + 30 * scale),
                             control1: VectorPoint(center.x + 25 * scale, center.y + 5 * scale),
                             control2: VectorPoint(center.x + 15 * scale, center.y + 15 * scale)))
        
        elements.append(.close)
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    // MARK: - Arrow
    static func createArrow(start: CGPoint, end: CGPoint, headLength: CGFloat = 20, headWidth: CGFloat = 10) -> VectorPath {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        
        if length == 0 { return VectorPath() }
        
        let unitX = dx / length
        let unitY = dy / length
        
        // Arrow head points
        let headStart = CGPoint(x: end.x - headLength * unitX, y: end.y - headLength * unitY)
        let headPoint1 = CGPoint(x: headStart.x - headWidth * unitY, y: headStart.y + headWidth * unitX)
        let headPoint2 = CGPoint(x: headStart.x + headWidth * unitY, y: headStart.y - headWidth * unitX)
        
        let elements: [PathElement] = [
            .move(to: VectorPoint(start)),
            .line(to: VectorPoint(headStart)),
            .line(to: VectorPoint(headPoint1)),
            .line(to: VectorPoint(end)),
            .line(to: VectorPoint(headPoint2)),
            .line(to: VectorPoint(headStart)),
            .close
        ]
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    // MARK: - Stop Sign
    static func createStopSign(center: CGPoint, radius: CGFloat) -> VectorPath {
        return createRegularPolygon(center: center, radius: radius, sides: 8, orientation: .pi / 8)
    }
    
    // MARK: - Line
    static func createLine(start: CGPoint, end: CGPoint) -> VectorPath {
        let elements: [PathElement] = [
            .move(to: VectorPoint(start)),
            .line(to: VectorPoint(end))
        ]
        
        return VectorPath(elements: elements, isClosed: false)
    }
    
    // MARK: - Bezier Curve
    static func createBezierCurve(start: CGPoint, end: CGPoint, control1: CGPoint, control2: CGPoint) -> VectorPath {
        let elements: [PathElement] = [
            .move(to: VectorPoint(start)),
            .curve(to: VectorPoint(end), control1: VectorPoint(control1), control2: VectorPoint(control2))
        ]
        
        return VectorPath(elements: elements, isClosed: false)
    }
    
    // MARK: - Quadratic Curve
    static func createQuadraticCurve(start: CGPoint, end: CGPoint, control: CGPoint) -> VectorPath {
        let elements: [PathElement] = [
            .move(to: VectorPoint(start)),
            .quadCurve(to: VectorPoint(end), control: VectorPoint(control))
        ]
        
        return VectorPath(elements: elements, isClosed: false)
    }
    
    // MARK: - Helper Functions
    private static func regularPolygonPoints(center: CGPoint, radius: CGFloat, sides: Int, orientation: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        let angleStep = 2 * .pi / Double(sides)
        
        for i in 0..<sides {
            let angle = Double(i) * angleStep + Double(orientation) - .pi / 2
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            points.append(CGPoint(x: x, y: y))
        }
        
        return points
    }
    
    // MARK: - Complex Shapes
    static func createCog(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, teeth: Int = 12) -> VectorPath {
        var elements: [PathElement] = []
        let angleStep = 2 * .pi / Double(teeth)
        let toothAngle = angleStep * 0.3
        
        for i in 0..<teeth {
            let baseAngle = Double(i) * angleStep
            
            // Outer tooth points
            let outerAngle1 = baseAngle - toothAngle / 2
            let outerAngle2 = baseAngle + toothAngle / 2
            
            // Inner valley points
            let innerAngle1 = baseAngle - angleStep / 2
            let innerAngle2 = baseAngle + angleStep / 2
            
            let outerPoint1 = CGPoint(x: center.x + cos(outerAngle1) * outerRadius, y: center.y + sin(outerAngle1) * outerRadius)
            let outerPoint2 = CGPoint(x: center.x + cos(outerAngle2) * outerRadius, y: center.y + sin(outerAngle2) * outerRadius)
            let innerPoint1 = CGPoint(x: center.x + cos(innerAngle1) * innerRadius, y: center.y + sin(innerAngle1) * innerRadius)
            let innerPoint2 = CGPoint(x: center.x + cos(innerAngle2) * innerRadius, y: center.y + sin(innerAngle2) * innerRadius)
            
            if i == 0 {
                elements.append(.move(to: VectorPoint(outerPoint1)))
            } else {
                elements.append(.line(to: VectorPoint(outerPoint1)))
            }
            
            elements.append(.line(to: VectorPoint(outerPoint2)))
            elements.append(.line(to: VectorPoint(innerPoint2)))
            elements.append(.line(to: VectorPoint(innerPoint1)))
        }
        
        elements.append(.close)
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    // MARK: - Spiral
    static func createSpiral(center: CGPoint, startRadius: CGFloat, endRadius: CGFloat, turns: Double) -> VectorPath {
        var elements: [PathElement] = []
        let steps = Int(turns * 36) // 36 steps per turn
        
        for i in 0..<steps {
            let t = Double(i) / Double(steps - 1)
            let angle = t * turns * 2 * .pi
            let radius = startRadius + (endRadius - startRadius) * t
            
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            if i == 0 {
                elements.append(.move(to: VectorPoint(x, y)))
            } else {
                elements.append(.line(to: VectorPoint(x, y)))
            }
        }
        
        return VectorPath(elements: elements, isClosed: false)
    }
}