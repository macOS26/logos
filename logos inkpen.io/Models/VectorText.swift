//
//  VectorText.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import SwiftUI
import CoreText
import CoreGraphics

// MARK: - Professional Text Alignment
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
    
    // PROFESSIONAL DEFAULTS INITIALIZER
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
        fillColor: VectorColor = .white, // Default to white (will be overridden by drawing app colors)
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
    
    // PROFESSIONAL TEXT TOOL PROPERTIES
    var isPointText: Bool // Point text (expands as you type) vs Area text (fixed area)
    var cursorPosition: Int // Current cursor position for inline editing
    var areaSize: CGSize? // Area size for area text (nil for point text)
    
    // Professional text metrics using Core Text
    var textBounds: CGRect {
        let font = createCoreTextFont()
        let displayText = content.isEmpty ? "Text" : content
        
        // Create attributed string with proper font and kerning
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: typography.letterSpacing
        ]
        
        let attributedString = NSAttributedString(string: displayText, attributes: attributes)
        
        // Use CTLine for precise text layout metrics
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // Get accurate text bounds from Core Text
        let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        
        return textBounds
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
        // NATIVE CORE GRAPHICS BOUNDS CALCULATION
        // Uses Core Text for accurate text metrics at all zoom levels
        let font = createCoreTextFont()
        let displayText = content.isEmpty ? "Text" : content
        
        // Create attributed string with proper font and kerning
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: typography.letterSpacing
        ]
        
        let attributedString = NSAttributedString(string: displayText, attributes: attributes)
        
        // PROFESSIONAL CORE TEXT MEASUREMENT
        // Use CTLine for precise text layout metrics
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // Get accurate text bounds from Core Text
        let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        
        // Get font metrics for proper baseline positioning
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let leading = CTFontGetLeading(font)
        
        // CORE GRAPHICS STANDARD: Position is baseline, bounds are relative to baseline
        bounds = CGRect(
            x: 0,  // Relative to position (Core Graphics standard)
            y: -ascent,  // Above baseline (negative Y)
            width: max(textBounds.width, content.isEmpty ? 20 : 1),  // Actual text width
            height: ascent + descent + leading  // Total line height
        )
        
        // Position is handled separately - bounds are relative to position (Core Graphics standard)
    }
    
    private func createCoreTextFont() -> CTFont {
        // SURGICAL FIX: Use the existing nsFont property from TypographyProperties
        // This already handles weight and style correctly using SwiftUI's font system
        let nsFont = typography.nsFont
        
        // Convert NSFont to CTFont
        return CTFontCreateWithName(nsFont.fontName as CFString, typography.fontSize, nil)
    }
    
    // PROFESSIONAL TEXT TO OUTLINES CONVERSION
    func convertToOutlines() -> VectorShape? {
        let attributedString = NSAttributedString(string: content, attributes: [
            .font: typography.nsFont,
            .kern: typography.letterSpacing
        ])
        
        let line = CTLineCreateWithAttributedString(attributedString)
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        
        var allPathElements: [PathElement] = []
        let font = createCoreTextFont()
        
        // Get font metrics for proper coordinate transformation
        let ascent = CTFontGetAscent(font)
        let _ = CTFontGetDescent(font) // Font descent (for future use)
        
        for run in runs {
            let glyphCount = CTRunGetGlyphCount(run)
            let glyphs = UnsafeMutablePointer<CGGlyph>.allocate(capacity: glyphCount)
            let positions = UnsafeMutablePointer<CGPoint>.allocate(capacity: glyphCount)
            
            CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphs)
            CTRunGetPositions(run, CFRangeMake(0, 0), positions)
            
            for i in 0..<glyphCount {
                let glyph = glyphs[i]
                let glyphPosition = positions[i]
                
                if let glyphPath = CTFontCreatePathForGlyph(font, glyph, nil) {
                    // CRITICAL FIX: Apply coordinate system transformation for SwiftUI
                    // Core Graphics uses bottom-left origin, SwiftUI uses top-left
                    var transform = CGAffineTransform(scaleX: 1.0, y: -1.0) // Flip Y-axis
                        .translatedBy(x: Double(glyphPosition.x), y: -ascent) // Position glyph correctly
                    
                    if let transformedPath = glyphPath.copy(using: &transform) {
                        // Convert transformed CGPath to VectorPath elements
                        let glyphElements = convertCGPathToElements(transformedPath)
                        allPathElements.append(contentsOf: glyphElements)
                    }
                }
            }
            
            glyphs.deallocate()
            positions.deallocate()
        }
        
        if !allPathElements.isEmpty {
            // CRITICAL FIX: Create single grouped shape with all letters combined
            let vectorPath = VectorPath(elements: allPathElements, isClosed: false) // Let individual letters handle closing
            return VectorShape(
                name: "Text Outline: \(content)",
                path: vectorPath,
                strokeStyle: typography.hasStroke ? StrokeStyle(color: typography.strokeColor, width: typography.strokeWidth, opacity: typography.strokeOpacity) : nil,
                fillStyle: FillStyle(color: typography.fillColor, opacity: typography.fillOpacity),
                transform: .identity, // No additional transform needed
                isGroup: false // Single unified shape, not a group
            )
        }
        
        return nil
    }
    
    private func convertCGPathToElements(_ cgPath: CGPath) -> [PathElement] {
        var elements: [PathElement] = []
        
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            
            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(Double(point.x), Double(point.y))))
                
            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(Double(point.x), Double(point.y))))
                
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let point = element.points[1]
                elements.append(.quadCurve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control: VectorPoint(Double(control.x), Double(control.y))
                ))
                
            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let point = element.points[2]
                elements.append(.curve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control1: VectorPoint(Double(control1.x), Double(control1.y)),
                    control2: VectorPoint(Double(control2.x), Double(control2.y))
                ))
                
            case .closeSubpath:
                elements.append(.close)
                
            @unknown default:
                break
            }
        }
        
        return elements
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
    
    // Get font styles available for a family
    func getAvailableStyles(for family: String) -> [FontStyle] {
        let fontManager = NSFontManager.shared
        let members = fontManager.availableMembers(ofFontFamily: family) ?? []
        
        var styles: Set<FontStyle> = []
        for member in members {
            if let traits = member[3] as? NSNumber {
                let traitMask = NSFontDescriptor.SymbolicTraits(rawValue: UInt32(traits.intValue))
                
                if traitMask.contains(.italic) {
                    styles.insert(.italic)
                } else {
                    styles.insert(.normal)
                }
                
                // Check for oblique - this is harder to detect, but we can include it if the font name suggests it
                if let fontName = member[1] as? String,
                   fontName.lowercased().contains("oblique") {
                    styles.insert(.oblique)
                }
            }
        }
        
        // Always include normal if we found any fonts
        if !styles.isEmpty {
            styles.insert(.normal)
        }
        
        return Array(styles).sorted { style1, style2 in
            FontStyle.allCases.firstIndex(of: style1)! < FontStyle.allCases.firstIndex(of: style2)!
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
