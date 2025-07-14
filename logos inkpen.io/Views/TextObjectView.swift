//
//  TextObjectView.swift
//  logos
//
//  Core Graphics Text Rendering - NATIVE CORE GRAPHICS
//  COORDINATE SYSTEM: EXACTLY MATCHES SHAPES AND PEN TOOL
//

import SwiftUI
import CoreGraphics
import CoreText

struct TextObjectView: View {
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isSelected: Bool
    let isEditing: Bool
    
    var body: some View {
        ZStack {
            // NATIVE CORE GRAPHICS TEXT RENDERING - NO RASTERIZATION!
            // Uses direct Core Graphics drawing for crisp text at all zoom levels
            CoreGraphicsTextView(
                text: textObject.content.isEmpty ? "Text" : textObject.content,
                typography: textObject.typography,
                position: textObject.position
            )
            // EXACT SAME coordinate chain as shapes in ShapeView
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(textObject.transform)
            
            // FIXED: Selection outline using EXACT coordinate system as shapes
            if isSelected && !isEditing {
                // CRITICAL FIX: Text bounds are relative to position, not absolute
                // Position is baseline point, bounds are relative to that baseline
                let absoluteBounds = CGRect(
                    x: textObject.position.x,
                    y: textObject.position.y + textObject.bounds.minY,
                    width: textObject.bounds.width,
                    height: textObject.bounds.height
                )
                
                Path { path in
                    path.addRect(absoluteBounds)
                }
                .stroke(Color.blue, lineWidth: 1.0 / zoomLevel)
                // EXACT SAME coordinate chain as shapes in ShapeView
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(textObject.transform)
                .opacity(0.7)
            }
            
            // FIXED: Editing cursor using EXACT coordinate system as shapes
            if isEditing {
                let cursorX = textObject.position.x + getCursorXPosition()
                let cursorRect = CGRect(
                    x: cursorX,
                    y: textObject.position.y + textObject.bounds.minY,
                    width: 1.0,
                    height: textObject.bounds.height
                )
                
                Path { path in
                    path.addRect(cursorRect)
                }
                .fill(Color.blue)
                // EXACT SAME coordinate chain as shapes in ShapeView
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(textObject.transform)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isEditing)
            }
        }
    }
    
    private func getCursorXPosition() -> CGFloat {
        // Simple cursor positioning - place at end of text for now
        let nsString = NSString(string: textObject.content)
        // CRITICAL: Use typography.nsFont which includes weight and style
        let font = textObject.typography.nsFont
        let textSize = nsString.size(withAttributes: [.font: font])
        return textSize.width
    }
}

// MARK: - Native Core Graphics Text Renderer

struct CoreGraphicsTextView: NSViewRepresentable {
    let text: String
    let typography: TypographyProperties
    let position: CGPoint
    
    func makeNSView(context: Context) -> CoreGraphicsTextNSView {
        let view = CoreGraphicsTextNSView()
        view.text = text
        view.typography = typography
        view.position = position
        return view
    }
    
    func updateNSView(_ nsView: CoreGraphicsTextNSView, context: Context) {
        nsView.text = text
        nsView.typography = typography
        nsView.position = position
        nsView.needsDisplay = true
    }
}

// MARK: - Native Core Graphics Text NSView

class CoreGraphicsTextNSView: NSView {
    var text: String = ""
    var typography: TypographyProperties = TypographyProperties()
    var position: CGPoint = .zero
    
    override var isFlipped: Bool {
        return true // Use flipped coordinates to match SwiftUI
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // PROFESSIONAL CORE GRAPHICS TEXT RENDERING
        // This gives us crisp, scalable text at all zoom levels
        drawTextWithCoreGraphics(context: context)
    }
    
    private func drawTextWithCoreGraphics(context: CGContext) {
        // STEP 1: Create font with proper weight and style
        let font = createCoreTextFont()
        
        // STEP 2: Set up text attributes
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: typography.letterSpacing
        ]
        
        // STEP 3: Set text color based on typography settings
        var textColor: NSColor
        if typography.fillColor != .clear {
            textColor = NSColor(typography.fillColor.color).withAlphaComponent(typography.fillOpacity)
        } else if typography.hasStroke && typography.strokeColor != .clear {
            textColor = NSColor(typography.strokeColor.color).withAlphaComponent(typography.strokeOpacity)
        } else {
            // Final fallback to black for visibility
            textColor = NSColor.black
        }
        
        attributes[.foregroundColor] = textColor
        
        // STEP 4: Create attributed string
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // STEP 5: Create CTLine for precise text layout
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // STEP 6: Calculate text metrics for proper positioning
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let leading = CTFontGetLeading(font)
        let _ = ascent + descent + leading // Line height calculation (for future use)
        
        // STEP 7: Position text at baseline (Core Graphics standard)
        // Position.y is the baseline in our coordinate system
        let drawPoint = CGPoint(x: position.x, y: position.y)
        
        // STEP 8: Save graphics state
        context.saveGState()
        
        // STEP 9: Handle text stroke if enabled (Adobe Illustrator style)
        if typography.hasStroke && typography.strokeColor != .clear && typography.strokeWidth > 0 {
            // Draw stroke first (behind fill)
            context.setTextDrawingMode(.stroke)
            context.setStrokeColor(NSColor(typography.strokeColor.color).withAlphaComponent(typography.strokeOpacity).cgColor)
            context.setLineWidth(typography.strokeWidth)
            
            // Set text position and draw stroke
            context.textPosition = drawPoint
            CTLineDraw(line, context)
        }
        
        // STEP 10: Draw fill text (on top of stroke)
        context.setTextDrawingMode(.fill)
        context.setFillColor(textColor.cgColor)
        
        // Set text position and draw fill
        context.textPosition = drawPoint
        CTLineDraw(line, context)
        
        // STEP 11: Restore graphics state
        context.restoreGState()
    }
    
    private func createCoreTextFont() -> CTFont {
        // PROFESSIONAL FONT CREATION: Handle weight and style properly
        
        // Start with base font descriptor
        var fontDescriptor = CTFontDescriptorCreateWithNameAndSize(typography.fontFamily as CFString, typography.fontSize)
        
        // Add font traits for weight and style
        var traits: [CFString: Any] = [:]
        
        // Map font weight to Core Text weight
        let weightValue: Double
        switch typography.fontWeight {
        case .thin: weightValue = -0.8
        case .ultraLight: weightValue = -0.6
        case .light: weightValue = -0.4
        case .regular: weightValue = 0.0
        case .medium: weightValue = 0.23
        case .semibold: weightValue = 0.3
        case .bold: weightValue = 0.4
        case .heavy: weightValue = 0.56
        case .black: weightValue = 0.8
        }
        traits[kCTFontWeightTrait] = weightValue
        
        // Handle italic/oblique style
        if typography.fontStyle == .italic {
            traits[kCTFontSlantTrait] = 0.25 // Standard italic slant
        }
        
        // Create font descriptor with traits
        if !traits.isEmpty {
            let traitsDict = [kCTFontTraitsAttribute: traits]
            fontDescriptor = CTFontDescriptorCreateCopyWithAttributes(fontDescriptor, traitsDict as CFDictionary)
        }
        
        // Create the final font
        return CTFontCreateWithFontDescriptor(fontDescriptor, typography.fontSize, nil)
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

// MARK: - Legacy SwiftUI Canvas Implementation (REMOVED)
// The old PureSwiftUITextView has been removed because it caused rasterization
// Native Core Graphics rendering above provides crisp text at all zoom levels 