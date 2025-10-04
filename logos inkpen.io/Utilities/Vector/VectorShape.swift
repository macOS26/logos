//
//  VectorShape.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - LineCap Wrapper (Codable wrapper for CGLineCap)
struct LineCap: Codable, Hashable {
    private let cap: String

    init(_ cap: CGLineCap) {
        switch cap {
        case .butt:
            self.cap = "butt"
        case .round:
            self.cap = "round"
        case .square:
            self.cap = "square"
        @unknown default:
            self.cap = "butt"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.cap = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(cap)
    }

    var cgLineCap: CGLineCap {
        switch cap {
        case "butt":
            return .butt
        case "round":
            return .round
        case "square":
            return .square
        default:
            return .butt
        }
    }

    static let butt = LineCap(.butt)
    static let round = LineCap(.round)
    static let square = LineCap(.square)
}

// MARK: - LineJoin Wrapper (Codable wrapper for CGLineJoin)
struct LineJoin: Codable, Hashable {
    private let join: String

    init(_ join: CGLineJoin) {
        switch join {
        case .miter:
            self.join = "miter"
        case .round:
            self.join = "round"
        case .bevel:
            self.join = "bevel"
        @unknown default:
            self.join = "miter"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.join = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(join)
    }

    var cgLineJoin: CGLineJoin {
        switch join {
        case "miter":
            return .miter
        case "round":
            return .round
        case "bevel":
            return .bevel
        default:
            return .miter
        }
    }

    static let miter = LineJoin(.miter)
    static let round = LineJoin(.round)
    static let bevel = LineJoin(.bevel)
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

struct StrokeStyle: Hashable {
    var color: VectorColor
    var width: Double
    var placement: StrokePlacement
    var dashPattern: [Double]
    var lineCap: LineCap
    var lineJoin: LineJoin
    var miterLimit: Double
    var opacity: Double // PROFESSIONAL STROKE TRANSPARENCY
    var blendMode: BlendMode // PROFESSIONAL STROKE BLEND MODES
    
    init(color: VectorColor = .black, width: Double = 1.0, placement: StrokePlacement = .center, dashPattern: [Double] = [], lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: Double = 10.0, opacity: Double = 1.0, blendMode: BlendMode = .normal) {
        self.color = color
        self.width = width
        self.placement = placement
        self.dashPattern = dashPattern
        self.lineCap = LineCap(lineCap)
        self.lineJoin = LineJoin(lineJoin)
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
        self.lineCap = LineCap(lineCap)
        self.lineJoin = LineJoin(lineJoin)
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

// MARK: - StrokeStyle Codable Implementation
extension StrokeStyle: Codable {
    enum CodingKeys: String, CodingKey {
        case color, width, placement, dashPattern, lineCap, lineJoin, miterLimit, opacity, blendMode
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(color, forKey: .color)
        try container.encode(width, forKey: .width)
        try container.encode(placement, forKey: .placement)

        // Only encode dashPattern if not empty
        if !dashPattern.isEmpty {
            try container.encode(dashPattern, forKey: .dashPattern)
        }

        try container.encode(lineCap, forKey: .lineCap)
        try container.encode(lineJoin, forKey: .lineJoin)
        try container.encode(miterLimit, forKey: .miterLimit)

        // Only encode opacity if not 1.0
        if opacity != 1.0 {
            try container.encode(opacity, forKey: .opacity)
        }

        // Only encode blendMode if not normal
        if blendMode != .normal {
            try container.encode(blendMode, forKey: .blendMode)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = try container.decode(VectorColor.self, forKey: .color)
        width = try container.decode(Double.self, forKey: .width)
        placement = try container.decode(StrokePlacement.self, forKey: .placement)
        dashPattern = try container.decodeIfPresent([Double].self, forKey: .dashPattern) ?? []
        lineCap = try container.decode(LineCap.self, forKey: .lineCap)
        lineJoin = try container.decode(LineJoin.self, forKey: .lineJoin)
        miterLimit = try container.decode(Double.self, forKey: .miterLimit)
        // Make opacity and blendMode optional with defaults
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        blendMode = try container.decodeIfPresent(BlendMode.self, forKey: .blendMode) ?? .normal
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

    // Custom encoding to make opacity and blendMode optional when default
    enum CodingKeys: String, CodingKey {
        case color, opacity, blendMode
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(color, forKey: .color)

        // Only encode opacity if not 1.0
        if opacity != 1.0 {
            try container.encode(opacity, forKey: .opacity)
        }

        // Only encode blendMode if not normal
        if blendMode != .normal {
            try container.encode(blendMode, forKey: .blendMode)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = try container.decode(VectorColor.self, forKey: .color)
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        blendMode = try container.decodeIfPresent(BlendMode.self, forKey: .blendMode) ?? .normal
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
    case heptagon = "Heptagon"
    case octagon = "Octagon"
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
        case .heptagon: return "heptagon"
        case .octagon: return "octagon"
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
struct VectorShape: Hashable, Identifiable {
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
    
    // MARK: - Raster Image Persistence (optional)
    /// If this shape represents a placed image, persist either a link or embedded data.
    /// Default behavior is to save `linkedImagePath` only; embedding is user-triggered.
    var embeddedImageData: Data? = nil
    var linkedImagePath: String? = nil
    /// Optional: Security-scoped bookmark for linked image (required for sandboxed access across launches)
    var linkedImageBookmarkData: Data? = nil
    
    // MARK: - Group Properties
    var isGroup: Bool
    var groupedShapes: [VectorShape]
    var groupTransform: CGAffineTransform
    
    // MARK: - Compound Path Properties
    var isCompoundPath: Bool
    
    // MARK: - Clipping Mask Support
    /// When true, this shape acts as a clipping path for its immediate following siblings (Adobe-style)
    var isClippingPath: Bool = false
    /// Optional: Clip this shape's visual output to the path of another shape (typically the previous one)
    var clippedByShapeID: UUID?
    
    // MARK: - Warp Object Properties (Professional Envelope Warping)
    var isWarpObject: Bool
    var originalPath: VectorPath?  // Original unwrapped path
    var warpEnvelope: [CGPoint]    // 4 corner points defining the current warp envelope
    var originalEnvelope: [CGPoint] // 4 corner points defining the original envelope (for continuous warping)
    var warpedBounds: CGRect?      // Actual bounds of the warped path (for transform box)

    // MARK: - Live Corner Radius Properties (Professional Corner Editing)
    var isRoundedRectangle: Bool = false
    var originalBounds: CGRect?    // Original shape bounds (never changes) - used for both rounded rectangles and warped objects
    var cornerRadii: [Double] = [] // Current radius for each corner [topLeft, topRight, bottomRight, bottomLeft] in points
    
    // MARK: - Text Object Properties (when isTextObject = true)
    var isTextObject: Bool = false
    var textContent: String? = nil
    var typography: TypographyProperties? = nil
    var cursorPosition: Int? = nil // Current cursor position for inline editing
    var areaSize: CGSize? = nil // Area size for area text (nil for point text)
    var isEditing: Bool? = nil // For inline text editing
    var textPosition: CGPoint? = nil // Original text position (preserved for undo/redo)
    // Removed isPointText - only area text is used

    // Metadata dictionary for storing additional properties (e.g., from PDF import)
    var metadata: [String: String] = [:]
    
    init(name: String = "Shape", path: VectorPath, geometricType: GeometricShapeType? = nil, strokeStyle: StrokeStyle? = nil, fillStyle: FillStyle? = nil, transform: CGAffineTransform = .identity, isVisible: Bool = true, isLocked: Bool = false, opacity: Double = 1.0, blendMode: BlendMode = .normal, isGroup: Bool = false, groupedShapes: [VectorShape] = [], groupTransform: CGAffineTransform = .identity, isCompoundPath: Bool = false, isClippingPath: Bool = false, clippedByShapeID: UUID? = nil, isWarpObject: Bool = false, originalPath: VectorPath? = nil, warpEnvelope: [CGPoint] = [], originalEnvelope: [CGPoint] = [], warpedBounds: CGRect? = nil, isRoundedRectangle: Bool = false, originalBounds: CGRect? = nil, cornerRadii: [Double] = [], isTextObject: Bool = false, textContent: String? = nil, typography: TypographyProperties? = nil, cursorPosition: Int? = nil, areaSize: CGSize? = nil, isEditing: Bool? = nil, textPosition: CGPoint? = nil, metadata: [String: String] = [:]) {
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
        self.isClippingPath = isClippingPath
        self.clippedByShapeID = clippedByShapeID
        self.isWarpObject = isWarpObject
        self.originalPath = originalPath
        self.warpEnvelope = warpEnvelope
        self.originalEnvelope = originalEnvelope
        self.warpedBounds = warpedBounds
        self.isRoundedRectangle = isRoundedRectangle
        self.originalBounds = originalBounds
        self.cornerRadii = cornerRadii
        self.isTextObject = isTextObject
        self.textContent = textContent
        self.typography = typography
        self.cursorPosition = cursorPosition
        self.areaSize = areaSize
        self.isEditing = isEditing
        self.textPosition = textPosition
        self.metadata = metadata
    }
    
    var transformedPath: CGPath {
        var mutableTransform = transform
        return path.cgPath.copy(using: &mutableTransform) ?? path.cgPath
    }
    
    mutating func updateBounds() {
        // CRITICAL FIX: For text objects, use areaSize if available to avoid infinity bounds
        if isTextObject {
            if let areaSize = areaSize {
                // Use the user-defined area size for text boxes
                bounds = CGRect(x: 0, y: 0, width: areaSize.width, height: areaSize.height)
            } else {
                // Fallback to a default size for text without area size
                // This prevents infinity bounds which make text unselectable
                bounds = CGRect(x: 0, y: 0, width: 200, height: 50)
            }
            return
        }
        
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
            let pathBounds = path.cgPath.boundingBoxOfPath
            // Check for invalid bounds (infinity or NaN)
            if pathBounds.isInfinite || pathBounds.isNull || pathBounds.isEmpty {
                bounds = CGRect(x: 0, y: 0, width: 100, height: 100) // Default fallback
            } else {
                bounds = pathBounds
            }
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
    func createWarpObject(warpedPath: VectorPath, warpEnvelope: [CGPoint]) -> VectorShape {
        var warpObject = self
        warpObject.id = UUID() // New ID for the warp object
        warpObject.name = "Warped " + self.name
        warpObject.isWarpObject = true
        warpObject.originalPath = self.path  // Store original path (NEVER changes)
        warpObject.path = warpedPath         // Use warped path as current path
        warpObject.warpEnvelope = warpEnvelope // Store current envelope corners
        warpObject.transform = .identity     // Reset transform since coordinates are already warped
        warpObject.updateBounds()            // This will update bounds from the warped path
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
    
    // MARK: - Text Object Factory Method
    
    /// Create a VectorShape that represents text
    static func textObject(content: String, typography: TypographyProperties, position: CGPoint, areaSize: CGSize? = nil) -> VectorShape {
        // Create an empty path for text objects (text rendering doesn't use path)
        let emptyPath = VectorPath(elements: [], isClosed: false)
        
        return VectorShape(
            name: "Text: \(content.prefix(20))",
            path: emptyPath,
            geometricType: nil,
            strokeStyle: nil,
            fillStyle: nil,
            transform: CGAffineTransform(translationX: position.x, y: position.y),
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            isTextObject: true,
            textContent: content,
            typography: typography,
            cursorPosition: content.count,
            areaSize: areaSize,
            isEditing: false,
            textPosition: position  // Store original position for undo/redo
        )
    }
    
    /// Convert a VectorText object to a VectorShape
    static func from(_ vectorText: VectorText) -> VectorShape {
        // Create an empty path for text objects (text rendering doesn't use path)
        let emptyPath = VectorPath(elements: [], isClosed: false)
        
        var shape = VectorShape(
            name: "Text: \(vectorText.content.prefix(20))",
            path: emptyPath,
            geometricType: nil,
            strokeStyle: nil,
            fillStyle: nil,
            transform: CGAffineTransform(translationX: vectorText.position.x, y: vectorText.position.y).concatenating(vectorText.transform),
            isVisible: vectorText.isVisible,
            isLocked: vectorText.isLocked,
            opacity: 1.0,
            blendMode: .normal,
            isTextObject: true,
            textContent: vectorText.content,
            typography: vectorText.typography,
            cursorPosition: vectorText.cursorPosition,
            areaSize: vectorText.areaSize,
            isEditing: vectorText.isEditing,
            textPosition: vectorText.position  // Store original position for undo/redo
        )
        
        // CRITICAL FIX: Preserve the original VectorText ID so ProfessionalTextCanvas can find it
        shape.id = vectorText.id
        
        // CRITICAL FIX: Set proper bounds for text objects
        // Use areaSize if available, otherwise use vectorText bounds with validation
        if let areaSize = vectorText.areaSize {
            shape.bounds = CGRect(x: 0, y: 0, width: areaSize.width, height: areaSize.height)
        } else if !vectorText.bounds.isInfinite && !vectorText.bounds.isNull && 
                  vectorText.bounds.width > 0 && vectorText.bounds.height > 0 {
            shape.bounds = CGRect(
                x: 0, y: 0, 
                width: vectorText.bounds.width, 
                height: vectorText.bounds.height
            )
        } else {
            // Fallback to default size if bounds are invalid
            shape.bounds = CGRect(x: 0, y: 0, width: 200, height: 50)
        }
        
        return shape
    }
}

// MARK: - Codable Implementation with Bounds Validation
extension VectorShape: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, path, geometricType, strokeStyle, fillStyle
        case transform, isVisible, isLocked, opacity, blendMode, bounds
        case embeddedImageData, linkedImagePath, linkedImageBookmarkData
        case isGroup, groupedShapes, groupTransform
        case isCompoundPath, isClippingPath, clippedByShapeID
        case isWarpObject, originalPath, warpEnvelope, originalEnvelope, warpedBounds
        case isRoundedRectangle, originalBounds, cornerRadii
        case isTextObject, textContent, typography
        case cursorPosition, areaSize, isEditing, textPosition
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(geometricType, forKey: .geometricType)
        try container.encodeIfPresent(strokeStyle, forKey: .strokeStyle)
        try container.encodeIfPresent(fillStyle, forKey: .fillStyle)

        // Only encode transform if it's not identity
        if transform != .identity {
            try container.encode(transform, forKey: .transform)
        }

        // Only encode isVisible if it's false (true is default)
        if !isVisible { try container.encode(isVisible, forKey: .isVisible) }
        if isLocked { try container.encode(isLocked, forKey: .isLocked) }

        // Only encode opacity if not 1.0
        if opacity != 1.0 {
            try container.encode(opacity, forKey: .opacity)
        }

        // Only encode blendMode if not normal
        if blendMode != .normal {
            try container.encode(blendMode, forKey: .blendMode)
        }
        
        // CRITICAL FIX: Validate bounds before encoding to prevent infinity/NaN errors
        let validBounds: CGRect
        if bounds.isInfinite || bounds.isNull || 
           bounds.width.isInfinite || bounds.height.isInfinite ||
           bounds.width.isNaN || bounds.height.isNaN {
            // Use fallback bounds for invalid values
            if isTextObject {
                validBounds = CGRect(x: 0, y: 0, width: areaSize?.width ?? 200, height: areaSize?.height ?? 50)
            } else {
                validBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
        } else {
            validBounds = bounds
        }
        try container.encode(validBounds, forKey: .bounds)
        
        try container.encodeIfPresent(embeddedImageData, forKey: .embeddedImageData)
        try container.encodeIfPresent(linkedImagePath, forKey: .linkedImagePath)
        try container.encodeIfPresent(linkedImageBookmarkData, forKey: .linkedImageBookmarkData)

        // Only encode group-related properties if this is actually a group
        if isGroup {
            try container.encode(isGroup, forKey: .isGroup)

            // Only encode groupedShapes if not empty
            if !groupedShapes.isEmpty {
                try container.encode(groupedShapes, forKey: .groupedShapes)
            }

            // Only encode groupTransform if it's not identity AND this is a group
            if groupTransform != .identity {
                try container.encode(groupTransform, forKey: .groupTransform)
            }
        }

        if isCompoundPath { try container.encode(isCompoundPath, forKey: .isCompoundPath) }
        if isClippingPath { try container.encode(isClippingPath, forKey: .isClippingPath) }
        try container.encodeIfPresent(clippedByShapeID, forKey: .clippedByShapeID)

        if isWarpObject { try container.encode(isWarpObject, forKey: .isWarpObject) }
        try container.encodeIfPresent(originalPath, forKey: .originalPath)
        // Only encode arrays if not empty
        if !warpEnvelope.isEmpty { try container.encode(warpEnvelope, forKey: .warpEnvelope) }
        if !originalEnvelope.isEmpty { try container.encode(originalEnvelope, forKey: .originalEnvelope) }
        try container.encodeIfPresent(warpedBounds, forKey: .warpedBounds)

        if isRoundedRectangle { try container.encode(isRoundedRectangle, forKey: .isRoundedRectangle) }
        try container.encodeIfPresent(originalBounds, forKey: .originalBounds)
        if !cornerRadii.isEmpty { try container.encode(cornerRadii, forKey: .cornerRadii) }

        if isTextObject { try container.encode(isTextObject, forKey: .isTextObject) }
        try container.encodeIfPresent(textContent, forKey: .textContent)
        try container.encodeIfPresent(typography, forKey: .typography)
        try container.encodeIfPresent(cursorPosition, forKey: .cursorPosition)
        try container.encodeIfPresent(areaSize, forKey: .areaSize)
        if let isEditing = isEditing, isEditing { try container.encode(isEditing, forKey: .isEditing) }
        try container.encodeIfPresent(textPosition, forKey: .textPosition)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Debug logging disabled to reduce noise

        // Decode each field with detailed error handling
        do {
            id = try container.decode(UUID.self, forKey: .id)
        } catch {
            // Log.error("❌ Failed to decode 'id': \(error)", category: .error)
            throw error
        }

        do {
            name = try container.decode(String.self, forKey: .name)
        } catch {
            // Log.error("❌ Failed to decode 'name': \(error)", category: .error)
            throw error
        }

        do {
            path = try container.decode(VectorPath.self, forKey: .path)
        } catch {
            // Log.error("❌ Failed to decode 'path': \(error)", category: .error)
            throw error
        }

        geometricType = try container.decodeIfPresent(GeometricShapeType.self, forKey: .geometricType)
        strokeStyle = try container.decodeIfPresent(StrokeStyle.self, forKey: .strokeStyle)
        fillStyle = try container.decodeIfPresent(FillStyle.self, forKey: .fillStyle)

        // Make transform optional with identity as default
        transform = try container.decodeIfPresent(CGAffineTransform.self, forKey: .transform) ?? .identity

        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false

        // Make opacity optional with 1.0 as default
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0

        // Make blendMode optional with normal as default
        blendMode = try container.decodeIfPresent(BlendMode.self, forKey: .blendMode) ?? .normal
        
        // CRITICAL FIX: Validate bounds after decoding
        let decodedBounds = try container.decode(CGRect.self, forKey: .bounds)
        if decodedBounds.isInfinite || decodedBounds.isNull ||
           decodedBounds.width.isInfinite || decodedBounds.height.isInfinite ||
           decodedBounds.width.isNaN || decodedBounds.height.isNaN {
            bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        } else {
            bounds = decodedBounds
        }
        
        embeddedImageData = try container.decodeIfPresent(Data.self, forKey: .embeddedImageData)
        linkedImagePath = try container.decodeIfPresent(String.self, forKey: .linkedImagePath)
        linkedImageBookmarkData = try container.decodeIfPresent(Data.self, forKey: .linkedImageBookmarkData)
        
        isGroup = try container.decodeIfPresent(Bool.self, forKey: .isGroup) ?? false
        groupedShapes = try container.decodeIfPresent([VectorShape].self, forKey: .groupedShapes) ?? []
        // Make groupTransform optional with identity as default
        groupTransform = try container.decodeIfPresent(CGAffineTransform.self, forKey: .groupTransform) ?? .identity

        isCompoundPath = try container.decodeIfPresent(Bool.self, forKey: .isCompoundPath) ?? false
        isClippingPath = try container.decodeIfPresent(Bool.self, forKey: .isClippingPath) ?? false
        clippedByShapeID = try container.decodeIfPresent(UUID.self, forKey: .clippedByShapeID)
        
        isWarpObject = try container.decodeIfPresent(Bool.self, forKey: .isWarpObject) ?? false
        originalPath = try container.decodeIfPresent(VectorPath.self, forKey: .originalPath)
        warpEnvelope = try container.decodeIfPresent([CGPoint].self, forKey: .warpEnvelope) ?? []
        originalEnvelope = try container.decodeIfPresent([CGPoint].self, forKey: .originalEnvelope) ?? []
        warpedBounds = try container.decodeIfPresent(CGRect.self, forKey: .warpedBounds)

        isRoundedRectangle = try container.decodeIfPresent(Bool.self, forKey: .isRoundedRectangle) ?? false
        originalBounds = try container.decodeIfPresent(CGRect.self, forKey: .originalBounds)
        cornerRadii = try container.decodeIfPresent([Double].self, forKey: .cornerRadii) ?? []
        
        isTextObject = try container.decodeIfPresent(Bool.self, forKey: .isTextObject) ?? false
        textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        typography = try container.decodeIfPresent(TypographyProperties.self, forKey: .typography)
        cursorPosition = try container.decodeIfPresent(Int.self, forKey: .cursorPosition)
        areaSize = try container.decodeIfPresent(CGSize.self, forKey: .areaSize)
        isEditing = try container.decodeIfPresent(Bool.self, forKey: .isEditing)
        textPosition = try container.decodeIfPresent(CGPoint.self, forKey: .textPosition)
    }
}

extension VectorShape {
    // MARK: - Path Type Helpers

    /// Returns true if this is a compound path with even-odd fill rule (creates holes)
    var isEvenOddCompoundPath: Bool {
        return isCompoundPath && path.fillRule.cgPathFillRule == .evenOdd
    }

    /// Returns true if this is a looping path with winding fill rule (no holes, overlaps fill)
    var isWindingLoopingPath: Bool {
        return isCompoundPath && path.fillRule.cgPathFillRule == .winding
    }

    /// Returns true if this is specifically a compound path (not a looping path)
    var isTrueCompoundPath: Bool {
        return isEvenOddCompoundPath
    }

    /// Returns true if this is specifically a looping path (not a compound path)
    var isTrueLoopingPath: Bool {
        return isWindingLoopingPath
    }

    // MARK: - Factory methods for common shapes
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
            strokeStyle: StrokeStyle(color: .black, width: 1.0, placement: .center, opacity: 1.0), 
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
            strokeStyle: StrokeStyle(color: .black, width: 1.0, placement: .center, opacity: 1.0), 
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
        return VectorShape(name: "Star", path: path, geometricType: .star, strokeStyle: StrokeStyle(placement: .center), fillStyle: FillStyle(color: .white))
    }
}

// MARK: - Vector Layer
struct VectorLayer: Hashable, Identifiable {
    var id: UUID
    var name: String
    // REMOVED: shapes - unified objects is the SINGLE source of truth
    var isVisible: Bool
    var isLocked: Bool
    var opacity: Double
    var blendMode: BlendMode
    
    init(name: String, shapes: [VectorShape] = [], isVisible: Bool = true, isLocked: Bool = false, opacity: Double = 1.0, blendMode: BlendMode = .normal) {
        self.id = UUID()
        self.name = name
        // shapes parameter ignored - unified objects is the source
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.opacity = opacity
        self.blendMode = blendMode
    }
    
    mutating func addShape(_ shape: VectorShape) {
        // NO-OP: Shapes managed through unified objects
    }
    
    mutating func removeShape(_ shape: VectorShape) {
        // NO-OP: Shapes managed through unified objects
    }
}

// MARK: - VectorLayer Codable Implementation
extension VectorLayer: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, isVisible, isLocked, opacity, blendMode
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)

        // Only encode isVisible if it's false (true is default)
        if !isVisible { try container.encode(isVisible, forKey: .isVisible) }
        if isLocked { try container.encode(isLocked, forKey: .isLocked) }

        // Only encode opacity if not 1.0
        if opacity != 1.0 { try container.encode(opacity, forKey: .opacity) }

        // Only encode blendMode if not normal
        if blendMode != .normal { try container.encode(blendMode, forKey: .blendMode) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        blendMode = try container.decodeIfPresent(BlendMode.self, forKey: .blendMode) ?? .normal
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
    static var inkpen: UTType {
        UTType(exportedAs: "io.logos.logos-inkpen-io.document")
    }

    static var inkpenSVG: UTType {
        UTType(exportedAs: "io.logos.logos-inkpen-io.svg")
    }

    static var inkpenPDF: UTType {
        UTType(exportedAs: "io.logos.logos-inkpen-io.pdf")
    }

    static var draggableVectorObject: UTType {
        UTType(exportedAs: "io.logos.logos-inkpen-io.draggableVectorObject")
    }
}
