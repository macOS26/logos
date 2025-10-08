//
//  VectorText.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import Combine

// MARK: - Text Box State Tracking (Blue, Green, Gray)
enum TextBoxState: String, CaseIterable {
    case editing = "editing"      // BLUE - Currently being edited
    case selected = "selected"    // GREEN - Selected and draggable
    case unselected = "unselected" // GRAY - Not selected, not editing
    
    var color: Color {
        switch self {
        case .editing: return .blue
        case .selected: return .green
        case .unselected: return .gray
        }
    }
    
    var description: String {
        switch self {
        case .editing: return "BLUE - Edit Mode"
        case .selected: return "GREEN - Selected & Draggable"
        case .unselected: return "GRAY - Unselected"
        }
    }
}

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
    var fontVariant: String?  // Store the actual variant name like "Condensed Bold"
    var fontWeight: FontWeight
    var fontStyle: FontStyle
    var fontSize: Double // In points (professional standard)
    var lineHeight: Double // Leading in typography
    var lineSpacing: Double // Extra spacing between lines (0 to fontSize/2)
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
    
    // NO DEFAULT FONT COLORS - COLORS MUST BE EXPLICITLY PROVIDED
    init(
        fontFamily: String = "Helvetica",
        fontVariant: String? = nil,
        fontWeight: FontWeight = .regular,
        fontStyle: FontStyle = .normal,
        fontSize: Double = 24.0,
        lineHeight: Double = 24.0,
        lineSpacing: Double = 0.0,
        letterSpacing: Double = 0.0,
        alignment: TextAlignment = .left,
        hasStroke: Bool = false,
        strokeColor: VectorColor,  // NO DEFAULT - MUST BE PROVIDED
        strokeWidth: Double = 1.0,
        strokeOpacity: Double = 1.0,
        fillColor: VectorColor,    // NO DEFAULT - MUST BE PROVIDED
        fillOpacity: Double = 1.0
    ) {
        self.fontFamily = fontFamily
        self.fontVariant = fontVariant
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.lineSpacing = lineSpacing
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
        // If we have a variant name, try to use it to get exact font
        if let variant = fontVariant {
            let fontManager = NSFontManager.shared
            let members = fontManager.availableMembers(ofFontFamily: fontFamily) ?? []

            for member in members {
                if let postScriptName = member[0] as? String,
                   let displayName = member[1] as? String,
                   displayName == variant {
                    if let font = NSFont(name: postScriptName, size: fontSize) {
                        return font
                    }
                }
            }
        }

        // Fallback to weight/style based creation
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
    // Removed isPointText - only area text is used
    var cursorPosition: Int // Current cursor position for inline editing
    var areaSize: CGSize? // Area size for area text (nil for point text)
    
    // HELPER: Get current text box state based on selection and editing
    func getState(in document: VectorDocument) -> TextBoxState {
        if isEditing {
            return .editing  // BLUE
        } else if document.selectedTextIDs.contains(id) {
            return .selected // GREEN
        } else {
            return .unselected // GRAY
        }
    }
    
    // HELPER: Check if this text box can be edited (not locked and visible)
    var canBeEdited: Bool {
        return isVisible && !isLocked
    }
    
    // HELPER: Check if font settings should be shown in font panel
    func shouldShowFontSettings(in document: VectorDocument) -> Bool {
        let state = getState(in: document)
        return state == .editing || state == .selected
    }
    
    // Professional text metrics using Core Text
    var textBounds: CGRect {
        let font = createCoreTextFont()
        let displayText = content.isEmpty ? "" : content
        
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
        content: String = "",
        typography: TypographyProperties = TypographyProperties(strokeColor: .black, fillColor: .black),  // Fallback for manual creation only
        position: CGPoint = .zero,
        transform: CGAffineTransform = .identity,
        isVisible: Bool = true,
        isLocked: Bool = false,
        isEditing: Bool = false,
        layerIndex: Int? = nil,
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
        self.cursorPosition = cursorPosition
        self.areaSize = areaSize
        updateBounds()
    }
    
    mutating func updateBounds() {
        // CRITICAL FIX: Don't override bounds that are managed by ProfessionalTextCanvas
        // The ProfessionalTextCanvas handles proper multi-line text bounds calculation
        // This old method was treating multi-line text as single line, causing the thin blue selection line
        
        // CRITICAL FIX: If areaSize is set, use it for bounds instead of calculating
        // This preserves user-drawn text box dimensions during copy/paste
        if let userAreaSize = areaSize {
            bounds = CGRect(x: 0, y: 0, width: userAreaSize.width, height: userAreaSize.height)
            return
        }
        
        // Only calculate bounds if we don't have proper bounds set (width and height both > 0)
        // OR if this is clearly single-line text (no line breaks)
        let hasProperBounds = bounds.width > 0 && bounds.height > 0
        let isSingleLineText = !content.contains("\n") && !content.contains("\r")
        
        // If we already have proper bounds from ProfessionalTextCanvas, don't override them
        if hasProperBounds && !isSingleLineText {
            return
        }
        
        // LEGACY SINGLE-LINE CALCULATION: Only for single-line text or fallback cases
        let font = createCoreTextFont()
        let displayText = content.isEmpty ? "" : content
        
        if isSingleLineText {
            // Single line text: Use CTLine (original logic)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .kern: typography.letterSpacing
            ]
            
            let attributedString = NSAttributedString(string: displayText, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributedString)
            let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            
            let ascent = CTFontGetAscent(font)
            let descent = CTFontGetDescent(font)
            let leading = CTFontGetLeading(font)
            
            bounds = CGRect(
                x: 0,
                y: -ascent,
                width: max(textBounds.width, content.isEmpty ? 20 : 1),
                height: ascent + descent + leading
            )
            
        } else {
            // Multi-line text: Use CTFramesetter for proper wrapping calculation
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = typography.alignment.nsTextAlignment
            paragraphStyle.lineSpacing = max(0, typography.lineSpacing)
            paragraphStyle.minimumLineHeight = typography.lineHeight
            paragraphStyle.maximumLineHeight = typography.lineHeight
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .kern: typography.letterSpacing,
                .paragraphStyle: paragraphStyle
            ]
            
            let attributedString = NSAttributedString(string: displayText, attributes: attributes)
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            
            // Use a reasonable default width for text wrapping if no bounds set
            let defaultWidth: CGFloat = 300.0
            let constraintSize = CGSize(width: defaultWidth, height: CGFloat.greatestFiniteMagnitude)
            
            let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRangeMake(0, 0),
                nil,
                constraintSize,
                nil
            )
            
            let ascent = CTFontGetAscent(font)
            
            bounds = CGRect(
                x: 0,
                y: -ascent,
                width: max(suggestedSize.width, content.isEmpty ? 20 : 1),
                height: max(suggestedSize.height + 20, typography.lineHeight) // Add padding for proper rendering
            )
            
        }
    }
    
    private func createCoreTextFont() -> CTFont {
        // SURGICAL FIX: Use the existing nsFont property from TypographyProperties
        // This already handles weight and style correctly using SwiftUI's font system
        let nsFont = typography.nsFont
        
        // Convert NSFont to CTFont
        return CTFontCreateWithName(nsFont.fontName as CFString, typography.fontSize, nil)
    }
    
    
    // MIGRATION: Convert VectorShape back to VectorText for unified access
    static func from(_ vectorShape: VectorShape) -> VectorText? {
        guard vectorShape.isTextObject else { return nil }

        // CRITICAL FIX: Check for existing typography FIRST to preserve alignment and all properties
        let typography: TypographyProperties
        if let existingTypography = vectorShape.typography {
            // Use existing typography if available (preserves alignment!)
            typography = existingTypography
        } else if !vectorShape.metadata.isEmpty,
           let fontFamily = vectorShape.metadata["fontFamily"],
           let fontSizeStr = vectorShape.metadata["fontSize"],
           let fontSize = Double(fontSizeStr) {

            // Reconstruct typography from PDF import metadata (legacy fallback)
            let letterSpacing = Double(vectorShape.metadata["letterSpacing"] ?? "0") ?? 0
            let lineSpacing = Double(vectorShape.metadata["lineSpacing"] ?? "0") ?? 0
            // Note: wordSpacing is stored but not used in TypographyProperties init

            typography = TypographyProperties(
                fontFamily: fontFamily,
                fontWeight: .regular,
                fontStyle: .normal,
                fontSize: fontSize,
                lineHeight: fontSize * 1.2,
                lineSpacing: lineSpacing,
                letterSpacing: letterSpacing,
                alignment: .left,
                hasStroke: vectorShape.strokeStyle != nil,
                strokeColor: vectorShape.strokeStyle?.color ?? .black,
                strokeWidth: vectorShape.strokeStyle?.width ?? 1.0,
                strokeOpacity: vectorShape.strokeStyle?.opacity ?? 1.0,
                fillColor: vectorShape.fillStyle?.color ?? .black,
                fillOpacity: vectorShape.fillStyle?.opacity ?? 1.0
            )
        } else {
            // Fallback: create from stroke/fill
            typography = TypographyProperties(
                strokeColor: vectorShape.strokeStyle?.color ?? .black,
                fillColor: vectorShape.fillStyle?.color ?? .black
            )
        }

        // Extract VectorText data from VectorShape
        // This is a reverse conversion from VectorShape.from(_:VectorText)
        // Use textPosition if available (preserved from original text), otherwise use transform
        let position = vectorShape.textPosition ?? CGPoint(x: vectorShape.transform.tx, y: vectorShape.transform.ty)
        var vectorText = VectorText(
            content: vectorShape.textContent ?? "", // Use the actual text content
            typography: typography,
            position: position,
            areaSize: vectorShape.areaSize
        )

        // CRITICAL: Restore bounds from shape
        vectorText.bounds = vectorShape.bounds

        // CRITICAL FIX: Preserve the original VectorShape ID so object lookups work
        vectorText.id = vectorShape.id

        // CRITICAL FIX: Preserve lock and visibility states from the shape
        vectorText.isLocked = vectorShape.isLocked
        vectorText.isVisible = vectorShape.isVisible

        // CRITICAL FIX: Preserve editing state from the shape
        vectorText.isEditing = vectorShape.isEditing ?? false

        // CRITICAL FIX: Preserve cursor position from the shape
        vectorText.cursorPosition = vectorShape.cursorPosition ?? 0

        return vectorText
    }
}

// MARK: - Professional Font Management
class FontManager: ObservableObject {
    @Published var availableFonts: [String] = []
    @Published var systemFonts: [String] = []
    @Published var googleFonts: [String] = []

    // Cache for font variants to avoid expensive NSFontManager calls
    private var fontVariantsCache: [String: [String]] = [:]

    // SELECTED FONT PROPERTIES for new text objects
    @Published var selectedFontFamily: String = "Helvetica Neue"
    @Published var selectedFontVariant: String = "Regular"  // Store selected variant name
    @Published var selectedFontWeight: FontWeight = .regular
    @Published var selectedFontStyle: FontStyle = .normal
    @Published var selectedFontSize: Double = 24.0
    
    // NEW: Line spacing and line height properties for new text creation
    @Published var selectedLineSpacing: Double = 0.0
    @Published var selectedLineHeight: Double = 24.0 // Default to font size
    @Published var selectedTextAlignment: TextAlignment = .left
    
    init() {
        loadAvailableFonts()
    }
    
    private func loadAvailableFonts() {
        // Get system fonts
        let fontManager = NSFontManager.shared
        systemFonts = fontManager.availableFontFamilies.sorted()
        
        // Prioritize professional fonts
        var orderedFonts: [String] = []
        
        // Add remaining system fonts
        for font in systemFonts {
            if !orderedFonts.contains(font) {
                orderedFonts.append(font)
            }
        }
        
        availableFonts = orderedFonts
    }
    
    // Get all font variant names for a family (for display in Weight picker)
    func getAvailableVariantNames(for family: String) -> [String] {
        // Check cache first
        if let cached = fontVariantsCache[family] {
            return cached
        }

        // Not in cache, calculate and store
        let fontManager = NSFontManager.shared
        let members = fontManager.availableMembers(ofFontFamily: family) ?? []

        var variants: [(name: String, weight: Int)] = []

        for member in members {
            if let displayName = member[1] as? String,
               let weightNumber = member[2] as? NSNumber {
                variants.append((name: displayName, weight: weightNumber.intValue))
            }
        }

        // Sort by weight (light to heavy)
        let sortedVariants = variants.sorted { $0.weight < $1.weight }.map { $0.name }

        // Store in cache
        fontVariantsCache[family] = sortedVariants

        return sortedVariants
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
        
        // Fallback: if no weights found, provide common defaults
        if weights.isEmpty {
            weights = [.regular, .bold]
        } else if !weights.contains(.regular) {
            // Always include regular as an option
            weights.insert(.regular)
        }
        
        return Array(weights).sorted { weight1, weight2 in
            let index1 = FontWeight.allCases.firstIndex(of: weight1) ?? 0
            let index2 = FontWeight.allCases.firstIndex(of: weight2) ?? 0
            return index1 < index2
        }
    }
    
    func mapNSWeightToFontWeight(_ nsWeight: Int) -> FontWeight {
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
        
        // Fallback: if no styles found, provide defaults
        if styles.isEmpty {
            styles = [.normal, .italic]
        } else if !styles.contains(.normal) {
            // Always include normal as an option
            styles.insert(.normal)
        }
        
        return Array(styles).sorted { style1, style2 in
            let index1 = FontStyle.allCases.firstIndex(of: style1) ?? 0
            let index2 = FontStyle.allCases.firstIndex(of: style2) ?? 0
            return index1 < index2
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

// MARK: - VectorText to VectorShape Conversion

extension VectorText {
    /// Convert VectorText to VectorShape for unified storage
    /// This is used by both PDF and SVG import to convert text objects to shapes
    func toVectorShape() -> VectorShape {
        // Create fill and stroke styles from typography
        let fillStyle = FillStyle(
            color: typography.fillColor,
            opacity: typography.fillOpacity
        )

        let strokeStyle = typography.hasStroke ? StrokeStyle(
            color: typography.strokeColor,
            width: typography.strokeWidth,
            opacity: typography.strokeOpacity
        ) : nil

        // For text objects, position is handled separately from transform
        // Use the text's transform (may contain rotation, scale, etc)
        var shape = VectorShape(
            name: "Text: \(content.prefix(20))",
            path: VectorPath(elements: []), // Empty path for text objects
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            transform: transform  // Use text's transform
        )

        // Mark as text object
        shape.isTextObject = true
        shape.textContent = content
        shape.textPosition = position
        shape.typography = typography  // CRITICAL: Store typography for text rendering
        shape.areaSize = areaSize      // CRITICAL: Store area size for text display
        shape.bounds = bounds           // CRITICAL: Set proper bounds for rendering
        shape.cursorPosition = 0        // Initialize cursor position

        // Store font info in metadata for import reconstruction
        shape.metadata["fontFamily"] = typography.fontFamily
        shape.metadata["fontSize"] = "\(typography.fontSize)"
        shape.metadata["letterSpacing"] = "\(typography.letterSpacing)"
        shape.metadata["lineSpacing"] = "\(typography.lineSpacing)"

        return shape
    }
}

