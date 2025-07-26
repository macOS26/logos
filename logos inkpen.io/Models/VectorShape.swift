//
//  VectorShape.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
    var opacity: Double // PROFESSIONAL STROKE TRANSPARENCY
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
    
    // MARK: - Gradient Support
    
    /// Create a stroke style with a gradient
    init(gradient: VectorGradient, width: Double = 1.0, placement: StrokePlacement = .center, dashPattern: [Double] = [], lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: Double = 10.0, opacity: Double = 1.0, blendMode: BlendMode = .normal) {
        self.color = .gradient(gradient)
        self.width = width
        self.placement = placement
        self.dashPattern = dashPattern
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
        self.opacity = opacity
        self.blendMode = blendMode
    }
    
    /// Check if this stroke is a gradient
    var isGradient: Bool {
        if case .gradient = color {
            return true
        }
        return false
    }
    
    /// Get the gradient if this stroke is a gradient
    var gradient: VectorGradient? {
        if case .gradient(let gradient) = color {
            return gradient
        }
        return nil
    }
    
    /// Check if this stroke is a solid color
    var isSolidColor: Bool {
        return !isGradient
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
    
    // MARK: - Gradient Support
    
    /// Create a fill style with a gradient
    init(gradient: VectorGradient, opacity: Double = 1.0, blendMode: BlendMode = .normal) {
        self.color = .gradient(gradient)
        self.opacity = opacity
        self.blendMode = blendMode
    }
    
    /// Check if this fill is a gradient
    var isGradient: Bool {
        if case .gradient = color {
            return true
        }
        return false
    }
    
    /// Get the gradient if this fill is a gradient
    var gradient: VectorGradient? {
        if case .gradient(let gradient) = color {
            return gradient
        }
        return nil
    }
    
    /// Check if this fill is a solid color
    var isSolidColor: Bool {
        return !isGradient
    }
    
    /// Get the solid color if this fill is not a gradient
    var solidColor: VectorColor? {
        if isGradient {
            return nil
        }
        return color
    }
    
    // MARK: - Convenience Gradient Creators
    
    /// Create a horizontal linear gradient fill
    static func linearGradient(from startColor: VectorColor, to endColor: VectorColor, opacity: Double = 1.0) -> FillStyle {
        let stops = [
            GradientStop(position: 0.0, color: startColor, opacity: 1.0),
            GradientStop(position: 1.0, color: endColor, opacity: 1.0)
        ]
        let linear = LinearGradient(
            startPoint: CGPoint(x: 0, y: 0), 
            endPoint: CGPoint(x: 1, y: 0), 
            stops: stops, 
            spreadMethod: .pad
        )
        let gradient = VectorGradient.linear(linear)
        return FillStyle(gradient: gradient, opacity: opacity)
    }
    
    /// Create a radial gradient fill
    static func radialGradient(from innerColor: VectorColor, to outerColor: VectorColor, opacity: Double = 1.0) -> FillStyle {
        let stops = [
            GradientStop(position: 0.0, color: innerColor, opacity: 1.0),
            GradientStop(position: 1.0, color: outerColor, opacity: 1.0)
        ]
        let radial = RadialGradient(
            centerPoint: CGPoint(x: 0.5, y: 0.5), 
            radius: 0.5, 
            stops: stops, 
            focalPoint: nil, 
            spreadMethod: .pad
        )
        let gradient = VectorGradient.radial(radial)
        return FillStyle(gradient: gradient, opacity: opacity)
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
    
    // MARK: - Group Properties
    var isGroup: Bool
    var groupedShapes: [VectorShape]
    var groupTransform: CGAffineTransform
    
    // MARK: - Compound Path Properties
    var isCompoundPath: Bool
    
    // MARK: - Warp Object Properties (Professional Envelope Warping)
    var isWarpObject: Bool
    var originalPath: VectorPath?  // Original unwrapped path
    var warpEnvelope: [CGPoint]    // 4 corner points defining the current warp envelope
    var originalEnvelope: [CGPoint] // 4 corner points defining the original envelope (for continuous warping)
    
    init(name: String = "Shape", path: VectorPath, geometricType: GeometricShapeType? = nil, strokeStyle: StrokeStyle? = nil, fillStyle: FillStyle? = nil, transform: CGAffineTransform = .identity, isVisible: Bool = true, isLocked: Bool = false, opacity: Double = 1.0, blendMode: BlendMode = .normal, isGroup: Bool = false, groupedShapes: [VectorShape] = [], groupTransform: CGAffineTransform = .identity, isCompoundPath: Bool = false, isWarpObject: Bool = false, originalPath: VectorPath? = nil, warpEnvelope: [CGPoint] = [], originalEnvelope: [CGPoint] = []) {
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
        self.isGroup = isGroup
        self.groupedShapes = groupedShapes
        self.groupTransform = groupTransform
        self.isCompoundPath = isCompoundPath
        self.isWarpObject = isWarpObject
        self.originalPath = originalPath
        self.warpEnvelope = warpEnvelope
        self.originalEnvelope = originalEnvelope
    }
    
    var transformedPath: CGPath {
        var mutableTransform = transform
        return path.cgPath.copy(using: &mutableTransform) ?? path.cgPath
    }
    
    mutating func updateBounds() {
        // FLATTENED SHAPE FIX: For flattened groups, calculate bounds from grouped shapes, not container path
        if isGroup && !groupedShapes.isEmpty {
            // Flattened shape: Use union of all grouped shapes' bounds
            var calculatedBounds = CGRect.zero
            for (index, shape) in groupedShapes.enumerated() {
                let shapeBounds = shape.bounds
                if index == 0 {
                    calculatedBounds = shapeBounds
                } else {
                    calculatedBounds = calculatedBounds.union(shapeBounds)
                }
            }
            bounds = calculatedBounds
        } else {
            // Regular shape: Use original path bounds, not transformed bounds
            // This prevents double transformation issues during rendering
            bounds = path.cgPath.boundingBoxOfPath
            // Transform is applied separately during rendering via .transformEffect()
        }
    }
    
    // MARK: - Group Methods
    
    /// Create a group from multiple shapes
    static func group(from shapes: [VectorShape], name: String = "Group") -> VectorShape {
        // Calculate group bounds
        var calculatedGroupBounds = CGRect.null
        for shape in shapes {
            calculatedGroupBounds = calculatedGroupBounds.union(shape.bounds)
        }
        
        // Create empty path for group container
        let groupPath = VectorPath(elements: [], isClosed: false)
        
        var groupShape = VectorShape(
            name: name,
            path: groupPath,
            geometricType: nil,
            strokeStyle: nil,
            fillStyle: nil,
            transform: .identity,
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            isGroup: true,
            groupedShapes: shapes,
            groupTransform: .identity
        )
        
        // Set the group bounds manually
        groupShape.bounds = calculatedGroupBounds
        
        return groupShape
    }
    
    /// Check if this shape is a group
    var isGroupContainer: Bool {
        return isGroup && !groupedShapes.isEmpty
    }
    
    /// Check if this shape is a compound path
    var isCompoundPathContainer: Bool {
        return isCompoundPath
    }
    
    /// Get bounds of group (union of all child shapes)
    var groupBounds: CGRect {
        guard isGroupContainer else { return bounds }
        
        var groupBounds = CGRect.null
        for shape in groupedShapes {
            groupBounds = groupBounds.union(shape.bounds)
        }
        return groupBounds
    }
    
    // MARK: - Warp Object Methods
    
    /// Create a warp object from this shape with the given warped path and envelope
    func createWarpObject(warpedPath: VectorPath, warpEnvelope: [CGPoint], originalEnvelope: [CGPoint]) -> VectorShape {
        var warpObject = self
        warpObject.id = UUID() // New ID for the warp object
        warpObject.name = "Warped " + self.name
        warpObject.isWarpObject = true
        warpObject.originalPath = self.path  // Store original path
        warpObject.path = warpedPath         // Use warped path as current path
        warpObject.warpEnvelope = warpEnvelope // Store current envelope corners
        warpObject.originalEnvelope = originalEnvelope // Store original envelope corners for continuous warping
        warpObject.transform = .identity     // Reset transform since coordinates are already warped
        warpObject.updateBounds()
        return warpObject
    }
    
    /// Unwrap this warp object back to its original shape
    func unwrapWarpObject() -> VectorShape? {
        guard isWarpObject else { return nil }
        
        var unwrappedShape = self
        unwrappedShape.id = UUID() // New ID for the unwrapped shape
        unwrappedShape.name = self.name.replacingOccurrences(of: "Warped ", with: "")
        unwrappedShape.isWarpObject = false
        unwrappedShape.warpEnvelope = []     // Clear current envelope
        unwrappedShape.originalEnvelope = [] // Clear original envelope
        unwrappedShape.transform = .identity
        
        if isGroup && !groupedShapes.isEmpty {
            // GROUP/FLATTENED WARP OBJECT: Need to restore original grouped shapes
            // For groups, we don't have a single originalPath, so we can't truly "unwrap"
            // Instead, we just remove the warp object status and keep current shapes
            unwrappedShape.originalPath = nil
            // Keep the current grouped shapes (they are already warped permanently)
            print("⚠️ GROUP UNWRAP: Cannot restore original - keeping warped shapes as permanent")
        } else if let originalPath = originalPath {
            // SINGLE SHAPE WARP OBJECT: Restore original path
            unwrappedShape.originalPath = nil
            unwrappedShape.path = originalPath   // Restore original path
        } else {
            // No original path available - keep current path
            unwrappedShape.originalPath = nil
        }
        
        unwrappedShape.updateBounds()
        return unwrappedShape
    }
    
    /// Expand this warp object to permanently apply the warp transformation
    func expandWarpObject() -> VectorShape? {
        guard isWarpObject else { return nil }
        
        var expandedShape = self
        expandedShape.id = UUID() // New ID for the expanded shape
        expandedShape.name = self.name.replacingOccurrences(of: "Warped ", with: "Expanded ")
        expandedShape.isWarpObject = false
        expandedShape.originalPath = nil     // Remove reference to original
        expandedShape.warpEnvelope = []      // Clear current envelope
        expandedShape.originalEnvelope = [] // Clear original envelope
        expandedShape.transform = .identity
        
        // For both single shapes and groups, keep current warped state as permanent
        // The current path and groupedShapes already contain the warped geometry
        
        expandedShape.updateBounds()
        return expandedShape
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
        
        // PROFESSIONAL DEFAULTS - ALWAYS VISIBLE
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
        
        // PROFESSIONAL DEFAULTS - ALWAYS VISIBLE
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

// MARK: - Drag and Drop Support for Moving Objects Between Layers

/// Transferable wrapper for objects that can be moved between layers
struct DraggableVectorObject: Codable, Transferable {
    enum ObjectType: String, Codable {
        case shape = "shape"
        case text = "text"
    }
    
    let objectType: ObjectType
    let objectId: UUID
    let sourceLayerIndex: Int
    
    init(objectType: ObjectType, objectId: UUID, sourceLayerIndex: Int) {
        self.objectType = objectType
        self.objectId = objectId
        self.sourceLayerIndex = sourceLayerIndex
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .draggableVectorObject)
    }
}

extension UTType {
    static var draggableVectorObject: UTType {
        UTType(exportedAs: "com.toddbruss.logos-inkpen-io.draggableVectorObject")
    }
}
