//
//  PathConversionExtensions.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import CoreGraphics

// MARK: - CGPath to ClipperPath Conversion

extension CGPath {
    func toClipperPath() -> ClipperPath {
        // Use the professional curve-preserving conversion from ProfessionalBooleanGeometry
        // Use the professional curve-preserving conversion
        var points = ClipperPath()
        var currentPoint = CGPoint.zero
        
        self.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            
            switch element.type {
            case .moveToPoint:
                currentPoint = element.points[0]
                points.append(currentPoint)
                
            case .addLineToPoint:
                currentPoint = element.points[0]
                points.append(currentPoint)
                
            case .addQuadCurveToPoint:
                // High-quality quadratic curve approximation
                let control = element.points[0]
                let end = element.points[1]
                let start = currentPoint
                
                // Use adaptive subdivision for smooth curves
                let curvePoints = approximateQuadraticCurve(start: start, control: control, end: end, tolerance: 2.0)
                points.append(contentsOf: curvePoints)
                currentPoint = end
                
            case .addCurveToPoint:
                // High-quality cubic curve approximation
                let control1 = element.points[0]
                let control2 = element.points[1]
                let end = element.points[2]
                let start = currentPoint
                
                // Use adaptive subdivision for smooth curves
                let curvePoints = approximateCubicCurve(start: start, control1: control1, control2: control2, end: end, tolerance: 2.0)
                points.append(contentsOf: curvePoints)
                currentPoint = end
                
            case .closeSubpath:
                // Close the path - ClipperPath handles this automatically
                break
                
            @unknown default:
                break
            }
        }
        
        return points
    }
    
    private func approximateQuadraticCurve(start: CGPoint, control: CGPoint, end: CGPoint, tolerance: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        
        // Calculate the number of segments based on the curve's complexity
        let distance = distanceBetween(start, control) + distanceBetween(control, end)
        let segments = max(ClipperConstants.minIterations, min(ClipperConstants.maxIterations, Int(distance / tolerance))) // Adaptive segment count
        
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let point = quadraticBezierPoint(t: t, start: start, control: control, end: end)
            points.append(point)
        }
        
        return points
    }
    
    private func approximateCubicCurve(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, tolerance: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        
        // Calculate the number of segments based on the curve's complexity
        let distance = distanceBetween(start, control1) + distanceBetween(control1, control2) + distanceBetween(control2, end)
        let minSegments = Int(CGFloat(ClipperConstants.minIterations) * 1.5) // 12 for cubic curves
        let maxSegments = Int(CGFloat(ClipperConstants.maxIterations) * 1.5) // 96 for cubic curves
        let segments = max(minSegments, min(maxSegments, Int(distance / tolerance))) // Adaptive segment count for smoother curves
        
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let point = cubicBezierPoint(t: t, start: start, control1: control1, control2: control2, end: end)
            points.append(point)
        }
        
        return points
    }
    
    private func quadraticBezierPoint(t: CGFloat, start: CGPoint, control: CGPoint, end: CGPoint) -> CGPoint {
        let x = (1-t)*(1-t)*start.x + 2*(1-t)*t*control.x + t*t*end.x
        let y = (1-t)*(1-t)*start.y + 2*(1-t)*t*control.y + t*t*end.y
        return CGPoint(x: x, y: y)
    }
    
    private func cubicBezierPoint(t: CGFloat, start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) -> CGPoint {
        let x = (1-t)*(1-t)*(1-t)*start.x + 3*(1-t)*(1-t)*t*control1.x + 3*(1-t)*t*t*control2.x + t*t*t*end.x
        let y = (1-t)*(1-t)*(1-t)*start.y + 3*(1-t)*(1-t)*t*control1.y + 3*(1-t)*t*t*control2.y + t*t*t*end.y
        return CGPoint(x: x, y: y)
    }
    
    private func distanceBetween(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }
}

extension ClipperPath {
    func toCGPath() -> CGPath {
        let path = CGMutablePath()
        
        guard !self.isEmpty else { return path }
        
        path.move(to: self[0])
        for i in 1..<self.count {
            path.addLine(to: self[i])
        }
        path.closeSubpath()
        
        return path
    }
} 