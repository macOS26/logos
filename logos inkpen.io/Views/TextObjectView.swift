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
        
        // STEP 3: Only set fill color in attributed string if we're doing fill-only rendering
        // For stroke rendering, we'll handle colors manually via CoreGraphics
        let willUseManualRendering = typography.hasStroke && typography.strokeColor != .clear && typography.strokeWidth > 0
        
        if !willUseManualRendering {
            // Fill-only: Use attributed string foreground color with direct cgColor conversion
            let fillCGColor = typography.fillColor.cgColor.copy(alpha: typography.fillOpacity) ?? typography.fillColor.cgColor
            let fillNSColor = NSColor(cgColor: fillCGColor) ?? NSColor.black
            attributes[.foregroundColor] = fillNSColor
        }
        // For manual stroke/fill rendering, DO NOT set any foregroundColor to avoid conflicts
        
        // STEP 4: Create attributed string
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // STEP 5: Create CTLine for precise text layout
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // STEP 6: Calculate text metrics for proper positioning
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let leading = CTFontGetLeading(font)
        let _ = ascent + descent + leading // Line height calculation (for future use)
        
        // STEP 7: Save graphics state and fix coordinate system
        context.saveGState()
        
        // STEP 8: Fix coordinate system - Core Graphics Y-axis is flipped from SwiftUI
        // We need to flip the coordinate system to match SwiftUI's expectations
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        
        // STEP 9: Position text at baseline (adjusted for flipped coordinates)
        // In the flipped coordinate system, we need to adjust the Y position
        let drawPoint = CGPoint(x: position.x, y: position.y)
        
        // STEP 10: Handle text stroke if enabled (Adobe Illustrator style)
        if typography.hasStroke && typography.strokeColor != .clear && typography.strokeWidth > 0 {
            // Prepare colors for manual rendering
            let fillCGColor = typography.fillColor.cgColor
            let strokeCGColor = typography.strokeColor.cgColor
            
            // If we have both fill and stroke, draw them separately for better color control
            if typography.fillColor != .clear {
                // First draw the fill
                context.setTextDrawingMode(.fill)
                context.setFillColor(fillCGColor.copy(alpha: typography.fillOpacity) ?? fillCGColor)
                context.textPosition = drawPoint
                CTLineDraw(line, context)
                
                // Then draw the stroke on top
                context.setTextDrawingMode(.stroke)
                context.setStrokeColor(strokeCGColor.copy(alpha: typography.strokeOpacity) ?? strokeCGColor)
                context.setLineWidth(typography.strokeWidth)
                context.textPosition = drawPoint
                CTLineDraw(line, context)
            } else {
                // Stroke only (no fill)
                context.setTextDrawingMode(.stroke)
                context.setStrokeColor(strokeCGColor.copy(alpha: typography.strokeOpacity) ?? strokeCGColor)
                context.setLineWidth(typography.strokeWidth)
                
                // Set text position and draw stroke
                context.textPosition = drawPoint
                CTLineDraw(line, context)
            }
        } else if typography.fillColor != .clear {
            // STEP 11: Fill only (no stroke) - attributed string already has foreground color set
            context.setTextDrawingMode(.fill)
            
            // Set text position and draw fill
            context.textPosition = drawPoint
            CTLineDraw(line, context)
        }
        
        // STEP 12: Restore graphics state
        context.restoreGState()
    }
    
    private func createCoreTextFont() -> CTFont {
        // CRITICAL FIX: Use the NSFont directly to preserve ALL attributes (weight, style, etc.)
        let nsFont = typography.nsFont
        
        // Convert NSFont to CTFont while preserving ALL attributes
        return CTFontCreateWithFontDescriptor(nsFont.fontDescriptor, nsFont.pointSize, nil)
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
