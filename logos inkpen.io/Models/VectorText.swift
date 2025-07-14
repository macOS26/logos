//
//  VectorText.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import SwiftUI
import CoreText

// MARK: - Professional Text Alignment (Adobe Illustrator / FreeHand Standards)
enum TextAlignment: String, CaseIterable, Codable {
    case left = "Left"
    case center = "Center"
    case right = "Right"
    case justified = "Justified"
    
    var iconName: String {
        switch self {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        case .justified: return "text.justify"
        }
    }
    
    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        case .justified: return .justified
        }
    }
}

// MARK: - Professional Font Weight (Adobe Standards)
enum FontWeight: String, CaseIterable, Codable {
    case thin = "Thin"
    case ultraLight = "UltraLight"
    case light = "Light"
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    case heavy = "Heavy"
    case black = "Black"
    
    var systemWeight: Font.Weight {
        switch self {
        case .thin: return .thin
        case .ultraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
    
    var nsWeight: NSFont.Weight {
        switch self {
        case .thin: return .thin
        case .ultraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

// MARK: - Professional Font Style (Adobe / FreeHand Standards)
enum FontStyle: String, CaseIterable, Codable {
    case normal = "Normal"
    case italic = "Italic"
    case oblique = "Oblique"
    
    var iconName: String {
        switch self {
        case .normal: return "textformat"
        case .italic: return "italic"
        case .oblique: return "textformat.size"
        }
    }
}

// MARK: - Professional Typography Properties
struct TypographyProperties: Codable, Hashable {
    var fontFamily: String
    var fontWeight: FontWeight
    var fontStyle: FontStyle
    var fontSize: Double // In points (professional standard)
    var lineHeight: Double // Leading in typography
    var letterSpacing: Double // Tracking
    var alignment: TextAlignment
    
    // Professional stroke properties for outlined text
    var hasStroke: Bool
    var strokeColor: VectorColor
    var strokeWidth: Double
    var strokeOpacity: Double
    
    // Professional fill properties for text
    var fillColor: VectorColor
    var fillOpacity: Double
    
    // PROFESSIONAL DEFAULTS INITIALIZER (Adobe Illustrator Standards)
    init(
        fontFamily: String = "Helvetica",
        fontWeight: FontWeight = .regular,
        fontStyle: FontStyle = .normal,
        fontSize: Double = 24.0,
        lineHeight: Double = 28.8,
        letterSpacing: Double = 0.0,
        alignment: TextAlignment = .left,
        hasStroke: Bool = false,
        strokeColor: VectorColor = .black,
        strokeWidth: Double = 1.0,
        strokeOpacity: Double = 1.0,
        fillColor: VectorColor = .black,
        fillOpacity: Double = 1.0
    ) {
        self.fontFamily = fontFamily
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
        self.alignment = alignment
        self.hasStroke = hasStroke
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.strokeOpacity = strokeOpacity
        self.fillColor = fillColor
        self.fillOpacity = fillOpacity
    }

    
    // Create NSFont for text rendering
    var nsFont: NSFont {
        let descriptor = NSFontDescriptor(name: fontFamily, size: fontSize)
        let traits: NSFontDescriptor.SymbolicTraits = fontStyle == .italic ? .italic : []
        let weightedDescriptor = descriptor.addingAttributes([
            .traits: [
                NSFontDescriptor.TraitKey.weight: fontWeight.nsWeight.rawValue,
                NSFontDescriptor.TraitKey.symbolic: traits.rawValue
            ]
        ])
        return NSFont(descriptor: weightedDescriptor, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    }
    
    // Create SwiftUI Font for UI display
    var swiftUIFont: Font {
        let baseFont = Font.custom(fontFamily, size: fontSize)
            .weight(fontWeight.systemWeight)
        
        if fontStyle == .italic {
            return baseFont.italic()
        } else {
            return baseFont
        }
    }
}

// MARK: - Professional Vector Text Object
struct VectorText: Identifiable, Codable, Hashable {
    var id: UUID
    var content: String
    var typography: TypographyProperties
    var position: CGPoint // Text origin point
    var transform: CGAffineTransform
    var bounds: CGRect
    var isVisible: Bool
    var isLocked: Bool
    var isEditing: Bool // For inline text editing
    var layerIndex: Int? // Which layer this text belongs to
    
    // PROFESSIONAL TEXT TOOL PROPERTIES (Adobe Illustrator/FreeHand Standards)
    var isPointText: Bool // Point text (expands as you type) vs Area text (fixed area)
    var cursorPosition: Int // Current cursor position for inline editing
    var areaSize: CGSize? // Area size for area text (nil for point text)
    
    // Professional text metrics
    var textBounds: CGRect {
        let nsString = NSString(string: content.isEmpty ? "Text" : content)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: typography.nsFont, // Uses weight and style
            NSAttributedString.Key.kern: typography.letterSpacing
        ]
        
        // PROFESSIONAL TEXT MEASUREMENT: Use reasonable maximum width for area text
        let maxWidth: CGFloat = {
            if !isPointText, let areaSize = areaSize {
                return areaSize.width
            } else {
                return 10000  // Reasonable max width instead of .greatestFiniteMagnitude
            }
        }()
        
        let rect = nsString.boundingRect(
            with: CGSize(width: maxWidth, height: 10000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        
        return rect
    }
    
    init(
        content: String = "Text",
        typography: TypographyProperties = TypographyProperties(),
        position: CGPoint = .zero,
        transform: CGAffineTransform = .identity,
        isVisible: Bool = true,
        isLocked: Bool = false,
        isEditing: Bool = false,
        layerIndex: Int? = nil,
        isPointText: Bool = true,
        cursorPosition: Int = 0,
        areaSize: CGSize? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.typography = typography
        self.position = position
        self.transform = transform
        self.bounds = .zero
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.isEditing = isEditing
        self.layerIndex = layerIndex
        self.isPointText = isPointText
        self.cursorPosition = cursorPosition
        self.areaSize = areaSize
        updateBounds()
    }
    
    mutating func updateBounds() {
        // SURGICAL FIX: CoreGraphics-compliant text bounds calculation
        // Uses actual text content for dynamic sizing (fixes editing growth issue)
        let font = typography.nsFont
        let displayText = content.isEmpty ? "Text" : content
        let nsString = NSString(string: displayText)
        
        // CRITICAL: Use boundingRect for accurate multi-line text bounds (CoreGraphics standard)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: typography.letterSpacing
        ]
        
        let boundingRect = nsString.boundingRect(
            with: CGSize(width: isPointText ? 10000 : (areaSize?.width ?? 10000), height: 10000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        
        // SURGICAL FIX: CoreGraphics baseline positioning
        // According to CoreGraphics manual: baseline is reference point, bounds extend up/down from it
        bounds = CGRect(
            x: 0,  // Relative to position (CoreGraphics standard)
            y: boundingRect.minY,  // Use actual text bounds minY (includes ascent offset)
            width: max(boundingRect.width, content.isEmpty ? 20 : 1),  // Dynamic width, min for empty
            height: max(boundingRect.height, typography.fontSize * 1.2)  // Dynamic height with fallback
        )
        
        // Position is handled separately - bounds are relative to position (CoreGraphics standard)
    }
    
    // PROFESSIONAL TEXT TO OUTLINES CONVERSION (Critical Feature)
    func convertToOutlines() -> VectorShape? {
        let attributedString = NSAttributedString(string: content, attributes: [
            .font: typography.nsFont
        ])
        
        let line = CTLineCreateWithAttributedString(attributedString)
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        
        var pathElements: [PathElement] = []
        let currentX: Double = 0
        
        for run in runs {
            let glyphCount = CTRunGetGlyphCount(run)
            let glyphs = UnsafeMutablePointer<CGGlyph>.allocate(capacity: glyphCount)
            let positions = UnsafeMutablePointer<CGPoint>.allocate(capacity: glyphCount)
            
            CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphs)
            CTRunGetPositions(run, CFRangeMake(0, 0), positions)
            
            for i in 0..<glyphCount {
                let glyph = glyphs[i]
                let position = positions[i]
                
                if let glyphPath = CTFontCreatePathForGlyph(typography.nsFont, glyph, nil) {
                    // Convert CGPath to VectorPath elements
                    let bezierPath = NSBezierPath(cgPath: glyphPath)
                    let glyphElements = convertBezierPathToElements(bezierPath, offset: CGPoint(x: currentX + Double(position.x), y: Double(position.y)))
                    pathElements.append(contentsOf: glyphElements)
                }
            }
            
            glyphs.deallocate()
            positions.deallocate()
        }
        
        if !pathElements.isEmpty {
            let vectorPath = VectorPath(elements: pathElements, isClosed: true)
            return VectorShape(
                name: "Text Outline: \(content)",
                path: vectorPath,
                strokeStyle: typography.hasStroke ? StrokeStyle(color: typography.strokeColor, width: typography.strokeWidth, opacity: typography.strokeOpacity) : nil,
                fillStyle: FillStyle(color: typography.fillColor, opacity: typography.fillOpacity)
            )
        }
        
        return nil
    }
    
    private func convertBezierPathToElements(_ bezierPath: NSBezierPath, offset: CGPoint) -> [PathElement] {
        var elements: [PathElement] = []
        let elementCount = bezierPath.elementCount
        let points = UnsafeMutablePointer<NSPoint>.allocate(capacity: 3)
        
        for i in 0..<elementCount {
            let elementType = bezierPath.element(at: i, associatedPoints: points)
            
            switch elementType {
            case .moveTo:
                let point = VectorPoint(Double(points[0].x + offset.x), Double(points[0].y + offset.y))
                elements.append(.move(to: point))
            case .lineTo:
                let point = VectorPoint(Double(points[0].x + offset.x), Double(points[0].y + offset.y))
                elements.append(.line(to: point))
            case .curveTo:
                let to = VectorPoint(Double(points[2].x + offset.x), Double(points[2].y + offset.y))
                let control1 = VectorPoint(Double(points[0].x + offset.x), Double(points[0].y + offset.y))
                let control2 = VectorPoint(Double(points[1].x + offset.x), Double(points[1].y + offset.y))
                elements.append(.curve(to: to, control1: control1, control2: control2))
            case .cubicCurveTo:
                // Same as curveTo for NSBezierPath
                let to = VectorPoint(Double(points[2].x + offset.x), Double(points[2].y + offset.y))
                let control1 = VectorPoint(Double(points[0].x + offset.x), Double(points[0].y + offset.y))
                let control2 = VectorPoint(Double(points[1].x + offset.x), Double(points[1].y + offset.y))
                elements.append(.curve(to: to, control1: control1, control2: control2))
            case .quadraticCurveTo:
                // Convert quadratic to regular curve
                let to = VectorPoint(Double(points[1].x + offset.x), Double(points[1].y + offset.y))
                let control = VectorPoint(Double(points[0].x + offset.x), Double(points[0].y + offset.y))
                elements.append(.quadCurve(to: to, control: control))
            case .closePath:
                elements.append(.close)
            @unknown default:
                break
            }
        }
        
        points.deallocate()
        return elements
    }
}

// MARK: - Professional Font Management
class FontManager: ObservableObject {
    @Published var availableFonts: [String] = []
    @Published var systemFonts: [String] = []
    @Published var googleFonts: [String] = []
    
    // SELECTED FONT PROPERTIES for new text objects
    @Published var selectedFontFamily: String = "Helvetica"
    @Published var selectedFontWeight: FontWeight = .regular
    @Published var selectedFontStyle: FontStyle = .normal
    @Published var selectedFontSize: Double = 24.0
    
    // Common professional fonts (Adobe/FreeHand standard)
    static let professionalFonts = [
        "Helvetica", "Helvetica Neue", "Arial", "Times", "Times New Roman",
        "Futura", "Avenir", "Garamond", "Minion Pro", "Myriad Pro",
        "Proxima Nova", "Gotham", "Interstate", "Franklin Gothic",
        "Optima", "Gill Sans", "Frutiger", "Universe", "Trade Gothic"
    ]
    
    init() {
        loadAvailableFonts()
    }
    
    private func loadAvailableFonts() {
        // Get system fonts
        let fontManager = NSFontManager.shared
        systemFonts = fontManager.availableFontFamilies.sorted()
        
        // Prioritize professional fonts
        var orderedFonts: [String] = []
        
        // Add professional fonts first if available
        for professionalFont in FontManager.professionalFonts {
            if systemFonts.contains(professionalFont) {
                orderedFonts.append(professionalFont)
            }
        }
        
        // Add remaining system fonts
        for font in systemFonts {
            if !orderedFonts.contains(font) {
                orderedFonts.append(font)
            }
        }
        
        availableFonts = orderedFonts
    }
    
    // Get font weights available for a family
    func getAvailableWeights(for family: String) -> [FontWeight] {
        let fontManager = NSFontManager.shared
        let members = fontManager.availableMembers(ofFontFamily: family) ?? []
        
        var weights: Set<FontWeight> = []
        for member in members {
            if let weightNumber = member[2] as? NSNumber {
                let weight = mapNSWeightToFontWeight(weightNumber.intValue)
                weights.insert(weight)
            }
        }
        
        return Array(weights).sorted { weight1, weight2 in
            FontWeight.allCases.firstIndex(of: weight1)! < FontWeight.allCases.firstIndex(of: weight2)!
        }
    }
    
    private func mapNSWeightToFontWeight(_ nsWeight: Int) -> FontWeight {
        switch nsWeight {
        case 0...2: return .thin
        case 3: return .ultraLight
        case 4: return .light
        case 5: return .regular
        case 6: return .medium
        case 7...8: return .semibold
        case 9: return .bold
        case 10...11: return .heavy
        default: return .black
        }
    }
}

// MARK: - Extensions for NSBezierPath CGPath conversion
extension NSBezierPath {
    convenience init(cgPath: CGPath) {
        self.init()
        
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            let points = element.points
            
            switch element.type {
            case .moveToPoint:
                self.move(to: points[0])
            case .addLineToPoint:
                self.line(to: points[0])
            case .addQuadCurveToPoint:
                self.curve(to: points[1], controlPoint1: points[0], controlPoint2: points[0])
            case .addCurveToPoint:
                self.curve(to: points[2], controlPoint1: points[0], controlPoint2: points[1])
            case .closeSubpath:
                self.close()
            @unknown default:
                break
            }
        }
    }
} 