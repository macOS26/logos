//
//  VectorShape.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import SwiftUI

// MARK: - Codable Extensions for Core Graphics Types
extension CGLineCap: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int32.self)
        self = CGLineCap(rawValue: rawValue) ?? .butt
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension CGLineJoin: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int32.self)
        self = CGLineJoin(rawValue: rawValue) ?? .miter
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}


// MARK: - Stroke Properties
enum StrokePlacement: String, CaseIterable, Codable {
    case center = "Center"
    case inside = "Inside"
    case outside = "Outside"
    
    var iconName: String {
        switch self {
        case .center: return "circle"
        case .inside: return "circle.fill"
        case .outside: return "circle.circle"
        }
    }
}

struct StrokeStyle: Codable, Hashable {
    var color: VectorColor
    var width: Double
    var placement: StrokePlacement
    var dashPattern: [Double]
    var lineCap: CGLineCap
    var lineJoin: CGLineJoin
    var miterLimit: Double
    var opacity: Double // PROFESSIONAL STROKE TRANSPARENCY (Adobe Illustrator Standard)
    var blendMode: BlendMode // PROFESSIONAL STROKE BLEND MODES
    
    init(color: VectorColor = .black, width: Double = 1.0, placement: StrokePlacement = .center, dashPattern: [Double] = [], lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: Double = 10.0, opacity: Double = 1.0, blendMode: BlendMode = .normal) {
        self.color = color
        self.width = width
        self.placement = placement
        self.dashPattern = dashPattern
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
        self.opacity = opacity
        self.blendMode = blendMode
    }
}

// MARK: - Fill Properties
struct FillStyle: Codable, Hashable {
    var color: VectorColor
    var opacity: Double
    var blendMode: BlendMode
    
    init(color: VectorColor = .clear, opacity: Double = 1.0, blendMode: BlendMode = .normal) {
        self.color = color
        self.opacity = opacity
        self.blendMode = blendMode
    }
}

// MARK: - Geometric Shape Types
enum GeometricShapeType: String, CaseIterable, Codable {
    case rectangle = "Rectangle"
    case roundedRectangle = "Rounded Rectangle"
    case circle = "Circle"
    case ellipse = "Ellipse"
    case triangle = "Triangle"
    case pentagon = "Pentagon"
    case hexagon = "Hexagon"
    case star = "Star"
    case polygon = "Polygon"
    case line = "Line"
    case arrow = "Arrow"
    case diamond = "Diamond"
    case heart = "Heart"
    case stopSign = "Stop Sign"
    
    var iconName: String {
        switch self {
        case .rectangle: return "rectangle"
        case .roundedRectangle: return "rectangle.roundedtop"
        case .circle: return "circle"
        case .ellipse: return "oval"
        case .triangle: return "triangle"
        case .pentagon: return "pentagon"
        case .hexagon: return "hexagon"
        case .star: return "star"
        case .polygon: return "octagon"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.right"
        case .diamond: return "diamond"
        case .heart: return "heart"
        case .stopSign: return "octagon.fill"
        }
    }
}

// MARK: - Vector Shape
struct VectorShape: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var path: VectorPath
    var geometricType: GeometricShapeType?
    var strokeStyle: StrokeStyle?
    var fillStyle: FillStyle?
    var transform: CGAffineTransform
    var isVisible: Bool
    var isLocked: Bool
    var opacity: Double
    var blendMode: BlendMode
    var bounds: CGRect
    
    init(name: String = "Shape", path: VectorPath, geometricType: GeometricShapeType? = nil, strokeStyle: StrokeStyle? = nil, fillStyle: FillStyle? = nil, transform: CGAffineTransform = .identity, isVisible: Bool = true, isLocked: Bool = false, opacity: Double = 1.0, blendMode: BlendMode = .normal) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.geometricType = geometricType
        self.strokeStyle = strokeStyle
        self.fillStyle = fillStyle
        self.transform = transform
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.opacity = opacity
        self.blendMode = blendMode
        self.bounds = path.cgPath.boundingBoxOfPath
    }
    
    var transformedPath: CGPath {
        var mutableTransform = transform
        return path.cgPath.copy(using: &mutableTransform) ?? path.cgPath
    }
    
    mutating func updateBounds() {
        // Use original path bounds, not transformed bounds
        // This prevents double transformation issues during rendering
        bounds = path.cgPath.boundingBoxOfPath
        // Transform is applied separately during rendering via .transformEffect()
    }
    
    // Factory methods for common shapes
    static func rectangle(at origin: CGPoint, size: CGSize) -> VectorShape {
        let rect = CGRect(origin: origin, size: size)
        let path = VectorPath(elements: [
            .move(to: VectorPoint(rect.minX, rect.minY)),
            .line(to: VectorPoint(rect.maxX, rect.minY)),
            .line(to: VectorPoint(rect.maxX, rect.maxY)),
            .line(to: VectorPoint(rect.minX, rect.maxY)),
            .close
        ], isClosed: true)
        
        // PROFESSIONAL DEFAULTS (Adobe Illustrator Standards) - ALWAYS VISIBLE
        return VectorShape(
            name: "Rectangle", 
            path: path, 
            geometricType: .rectangle, 
            strokeStyle: StrokeStyle(color: .black, width: 1.0, opacity: 1.0), 
            fillStyle: FillStyle(color: .white, opacity: 1.0)
        )
    }
    
    static func circle(center: CGPoint, radius: Double) -> VectorShape {
        let path = VectorPath(elements: [
            .move(to: VectorPoint(center.x + radius, center.y)),
            .curve(to: VectorPoint(center.x, center.y + radius),
                   control1: VectorPoint(center.x + radius, center.y + radius * 0.552),
                   control2: VectorPoint(center.x + radius * 0.552, center.y + radius)),
            .curve(to: VectorPoint(center.x - radius, center.y),
                   control1: VectorPoint(center.x - radius * 0.552, center.y + radius),
                   control2: VectorPoint(center.x - radius, center.y + radius * 0.552)),
            .curve(to: VectorPoint(center.x, center.y - radius),
                   control1: VectorPoint(center.x - radius, center.y - radius * 0.552),
                   control2: VectorPoint(center.x - radius * 0.552, center.y - radius)),
            .curve(to: VectorPoint(center.x + radius, center.y),
                   control1: VectorPoint(center.x + radius * 0.552, center.y - radius),
                   control2: VectorPoint(center.x + radius, center.y - radius * 0.552)),
            .close
        ], isClosed: true)
        
        // PROFESSIONAL DEFAULTS (Adobe Illustrator Standards) - ALWAYS VISIBLE
        return VectorShape(
            name: "Circle", 
            path: path, 
            geometricType: .circle, 
            strokeStyle: StrokeStyle(color: .black, width: 1.0, opacity: 1.0), 
            fillStyle: FillStyle(color: .white, opacity: 1.0)
        )
    }
    
    static func star(center: CGPoint, outerRadius: Double, innerRadius: Double, points: Int = 5) -> VectorShape {
        var elements: [PathElement] = []
        let angleStep = .pi / Double(points)
        
        for i in 0..<(points * 2) {
            let angle = Double(i) * angleStep - .pi / 2
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
        
        let path = VectorPath(elements: elements, isClosed: true)
        return VectorShape(name: "Star", path: path, geometricType: .star, strokeStyle: StrokeStyle(), fillStyle: FillStyle(color: .white))
    }
}

// MARK: - Vector Layer
struct VectorLayer: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var shapes: [VectorShape]
    var isVisible: Bool
    var isLocked: Bool
    var opacity: Double
    var blendMode: BlendMode
    
    init(name: String, shapes: [VectorShape] = [], isVisible: Bool = true, isLocked: Bool = false, opacity: Double = 1.0, blendMode: BlendMode = .normal) {
        self.id = UUID()
        self.name = name
        self.shapes = shapes
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.opacity = opacity
        self.blendMode = blendMode
    }
    
    mutating func addShape(_ shape: VectorShape) {
        shapes.append(shape)
    }
    
    mutating func removeShape(_ shape: VectorShape) {
        shapes.removeAll { $0.id == shape.id }
    }
}