//
//  PathOperations.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import CoreGraphics

class PathOperations {
    
    // MARK: - Union Operation
    static func union(_ path1: CGPath, _ path2: CGPath) -> CGPath {
        // This is a simplified implementation
        // In a real implementation, you would use a proper boolean path operation library
        let result = CGMutablePath()
        
        // Add both paths to the result
        result.addPath(path1)
        result.addPath(path2)
        
        return result
    }
    
    // MARK: - Intersection Operation
    static func intersect(_ path1: CGPath, _ path2: CGPath) -> CGPath {
        // This would implement path intersection logic
        // For now, return a simple approximation
        let bounds1 = path1.boundingBoxOfPath
        let bounds2 = path2.boundingBoxOfPath
        let intersectionBounds = bounds1.intersection(bounds2)
        
        if intersectionBounds.isEmpty {
            return CGPath(rect: .zero, transform: nil)
        }
        
        return CGPath(rect: intersectionBounds, transform: nil)
    }
    
    // MARK: - Difference Operation
    static func difference(_ path1: CGPath, _ path2: CGPath) -> CGPath {
        // This would implement path difference logic
        // For now, return the first path (simplified)
        return path1
    }
    
    // MARK: - Exclude Operation
    static func exclude(_ path1: CGPath, _ path2: CGPath) -> CGPath {
        // This would implement path exclusion logic
        // For now, return a combination of both paths
        let result = CGMutablePath()
        result.addPath(path1)
        result.addPath(path2)
        return result
    }
    
    // MARK: - Path Simplification
    static func simplify(_ path: CGPath, tolerance: CGFloat = 1.0) -> CGPath {
        // Douglas-Peucker algorithm for path simplification
        let simplified = CGMutablePath()
        
        var points: [CGPoint] = []
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                points.append(element.pointee.points[0])
            case .addLineToPoint:
                points.append(element.pointee.points[0])
            case .addQuadCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
            case .addCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
                points.append(element.pointee.points[2])
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        
        let simplifiedPoints = douglasPeucker(points, tolerance: tolerance)
        
        if !simplifiedPoints.isEmpty {
            simplified.move(to: simplifiedPoints[0])
            for i in 1..<simplifiedPoints.count {
                simplified.addLine(to: simplifiedPoints[i])
            }
        }
        
        return simplified
    }
    
    // MARK: - Douglas-Peucker Algorithm
    private static func douglasPeucker(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        let firstPoint = points.first!
        let lastPoint = points.last!
        
        var maxDistance: CGFloat = 0
        var maxIndex = 0
        
        for i in 1..<points.count - 1 {
            let distance = perpendicularDistance(points[i], lineStart: firstPoint, lineEnd: lastPoint)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        if maxDistance > tolerance {
            let leftPoints = douglasPeucker(Array(points[0...maxIndex]), tolerance: tolerance)
            let rightPoints = douglasPeucker(Array(points[maxIndex...]), tolerance: tolerance)
            
            return leftPoints + Array(rightPoints.dropFirst())
        } else {
            return [firstPoint, lastPoint]
        }
    }
    
    // MARK: - Perpendicular Distance
    private static func perpendicularDistance(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        
        if dx == 0 && dy == 0 {
            return sqrt(pow(point.x - lineStart.x, 2) + pow(point.y - lineStart.y, 2))
        }
        
        let t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (dx * dx + dy * dy)
        let projectionX = lineStart.x + t * dx
        let projectionY = lineStart.y + t * dy
        
        return sqrt(pow(point.x - projectionX, 2) + pow(point.y - projectionY, 2))
    }
    
    // MARK: - Path Bounds
    static func calculateBounds(_ paths: [CGPath]) -> CGRect {
        guard !paths.isEmpty else { return .zero }
        
        var bounds = paths[0].boundingBoxOfPath
        for i in 1..<paths.count {
            bounds = bounds.union(paths[i].boundingBoxOfPath)
        }
        
        return bounds
    }
    
    // MARK: - Path Offset
    static func offset(_ path: CGPath, by distance: CGFloat) -> CGPath {
        // This would implement path offsetting
        // For now, return a simple expanded version
        let bounds = path.boundingBoxOfPath
        let expandedBounds = bounds.insetBy(dx: -distance, dy: -distance)
        
        return CGPath(rect: expandedBounds, transform: nil)
    }
    
    // MARK: - Path to String (for SVG export)
    static func pathToSVGString(_ path: CGPath) -> String {
        var pathString = ""
        
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                let point = element.pointee.points[0]
                pathString += "M \(point.x) \(point.y) "
            case .addLineToPoint:
                let point = element.pointee.points[0]
                pathString += "L \(point.x) \(point.y) "
            case .addQuadCurveToPoint:
                let control = element.pointee.points[0]
                let point = element.pointee.points[1]
                pathString += "Q \(control.x) \(control.y) \(point.x) \(point.y) "
            case .addCurveToPoint:
                let control1 = element.pointee.points[0]
                let control2 = element.pointee.points[1]
                let point = element.pointee.points[2]
                pathString += "C \(control1.x) \(control1.y) \(control2.x) \(control2.y) \(point.x) \(point.y) "
            case .closeSubpath:
                pathString += "Z "
            @unknown default:
                break
            }
        }
        
        return pathString.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Bezier Curve Operations
    static func createBezierCurve(from startPoint: CGPoint, to endPoint: CGPoint, control1: CGPoint, control2: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addCurve(to: endPoint, control1: control1, control2: control2)
        return path
    }
    
    static func subdivideBezierCurve(startPoint: CGPoint, control1: CGPoint, control2: CGPoint, endPoint: CGPoint, t: CGFloat) -> (left: (CGPoint, CGPoint, CGPoint, CGPoint), right: (CGPoint, CGPoint, CGPoint, CGPoint)) {
        // De Casteljau's algorithm
        let q0 = CGPoint(x: (1 - t) * startPoint.x + t * control1.x, y: (1 - t) * startPoint.y + t * control1.y)
        let q1 = CGPoint(x: (1 - t) * control1.x + t * control2.x, y: (1 - t) * control1.y + t * control2.y)
        let q2 = CGPoint(x: (1 - t) * control2.x + t * endPoint.x, y: (1 - t) * control2.y + t * endPoint.y)
        
        let r0 = CGPoint(x: (1 - t) * q0.x + t * q1.x, y: (1 - t) * q0.y + t * q1.y)
        let r1 = CGPoint(x: (1 - t) * q1.x + t * q2.x, y: (1 - t) * q1.y + t * q2.y)
        
        let s = CGPoint(x: (1 - t) * r0.x + t * r1.x, y: (1 - t) * r0.y + t * r1.y)
        
        return (left: (startPoint, q0, r0, s), right: (s, r1, q2, endPoint))
    }
    
    // MARK: - Path Hit Testing
    static func hitTest(_ path: CGPath, point: CGPoint, tolerance: CGFloat = 5.0) -> Bool {
        // Check if point is within the path bounds first
        let bounds = path.boundingBoxOfPath.insetBy(dx: -tolerance, dy: -tolerance)
        guard bounds.contains(point) else { return false }
        
        // Check if point is inside the path
        if path.contains(point) {
            return true
        }
        
        // Check if point is near the path stroke
        return isPointNearStroke(path, point: point, tolerance: tolerance)
    }
    
    private static func isPointNearStroke(_ path: CGPath, point: CGPoint, tolerance: CGFloat) -> Bool {
        // This is a simplified implementation
        // In a real implementation, you would check the distance to the actual path stroke
        var isNear = false
        
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                let pathPoint = element.pointee.points[0]
                let distance = sqrt(pow(point.x - pathPoint.x, 2) + pow(point.y - pathPoint.y, 2))
                if distance <= tolerance {
                    isNear = true
                }
            case .addQuadCurveToPoint, .addCurveToPoint:
                // For curves, check multiple points along the curve
                let pathPoint = element.pointee.points[element.pointee.type == .addQuadCurveToPoint ? 1 : 2]
                let distance = sqrt(pow(point.x - pathPoint.x, 2) + pow(point.y - pathPoint.y, 2))
                if distance <= tolerance {
                    isNear = true
                }
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        
        return isNear
    }
    
    // MARK: - Path Validation
    static func isValidPath(_ path: CGPath) -> Bool {
        guard !path.isEmpty else { return false }
        
        let bounds = path.boundingBoxOfPath
        return !bounds.isEmpty && bounds.width > 0 && bounds.height > 0
    }
    
    // MARK: - Path Optimization
    static func optimizePath(_ path: CGPath) -> CGPath {
        // Remove redundant points and simplify the path
        let simplified = simplify(path, tolerance: 0.5)
        return simplified
    }
}