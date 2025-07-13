//
//  VectorPath.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import SwiftUI

// MARK: - Point Types
struct VectorPoint: Codable, Hashable {
    var x: Double
    var y: Double
    
    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
    
    init(_ point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }
    
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

struct BezierControlPoint: Codable, Hashable {
    var point: VectorPoint
    var inControl: VectorPoint?
    var outControl: VectorPoint?
    
    init(point: VectorPoint, inControl: VectorPoint? = nil, outControl: VectorPoint? = nil) {
        self.point = point
        self.inControl = inControl
        self.outControl = outControl
    }
}

// MARK: - Path Elements
enum PathElement: Codable, Hashable {
    case move(to: VectorPoint)
    case line(to: VectorPoint)
    case curve(to: VectorPoint, control1: VectorPoint, control2: VectorPoint)
    case quadCurve(to: VectorPoint, control: VectorPoint)
    case close
}

// MARK: - Vector Path
struct VectorPath: Codable, Hashable, Identifiable {
    var id: UUID
    var elements: [PathElement]
    var isClosed: Bool
    
    init(elements: [PathElement] = [], isClosed: Bool = false) {
        self.id = UUID()
        self.elements = elements
        self.isClosed = isClosed
    }
    
    // PROFESSIONAL CONVENIENCE INITIALIZER: CGPath to VectorPath conversion
    /// Creates a VectorPath from a CGPath (for stroke outlining and other Core Graphics operations)
    init(cgPath: CGPath) {
        self.id = UUID()
        self.elements = []
        self.isClosed = false
        
        // Convert CGPath to VectorPath elements
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            
            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(point.x, point.y)))
                
            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(point.x, point.y)))
                
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let point = element.points[1]
                elements.append(.quadCurve(
                    to: VectorPoint(point.x, point.y),
                    control: VectorPoint(control.x, control.y)
                ))
                
            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let point = element.points[2]
                elements.append(.curve(
                    to: VectorPoint(point.x, point.y),
                    control1: VectorPoint(control1.x, control1.y),
                    control2: VectorPoint(control2.x, control2.y)
                ))
                
            case .closeSubpath:
                elements.append(.close)
                isClosed = true
                
            @unknown default:
                break
            }
        }
    }
    
    var cgPath: CGPath {
        let path = CGMutablePath()
        
        for element in elements {
            switch element {
            case .move(let to):
                path.move(to: to.cgPoint)
            case .line(let to):
                path.addLine(to: to.cgPoint)
            case .curve(let to, let control1, let control2):
                path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
            case .quadCurve(let to, let control):
                path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
            case .close:
                path.closeSubpath()
            }
        }
        
        if isClosed && !elements.contains(.close) {
            path.closeSubpath()
        }
        
        return path
    }
    
    mutating func addElement(_ element: PathElement) {
        elements.append(element)
    }
    
    mutating func close() {
        if !isClosed {
            isClosed = true
            if !elements.contains(.close) {
                elements.append(.close)
            }
        }
    }
}

// MARK: - LEGACY PATH OPERATIONS (for backward compatibility)
enum PathOperation: String, CaseIterable, Codable {
    case union = "Union"
    case intersect = "Intersect"
    case frontMinusBack = "Front Minus Back"
    case backMinusFront = "Back Minus Front"
    case exclude = "Exclude"
    case divide = "Divide"
    
    var iconName: String {
        switch self {
        case .union: return "plus.circle"
        case .intersect: return "circle.circle"
        case .frontMinusBack: return "minus.circle"
        case .backMinusFront: return "minus.circle.fill"
        case .exclude: return "xmark.circle"
        case .divide: return "divide.circle"
        }
    }
}