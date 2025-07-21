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
    var typography: TypographyProperties = TypographyProperties(strokeColor: .black, fillColor: .black)  // Fallback for preview only
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
        
        // STEP 2: Determine fill and stroke requirements
        let hasStroke = typography.hasStroke && typography.strokeColor != .clear && typography.strokeWidth > 0
        let hasFill = typography.fillColor != .clear
        
        // ALWAYS use Core Graphics approach - CTLineDraw doesn't support stroke properly
        drawWithCoreGraphics(context: context, font: font, hasStroke: hasStroke, hasFill: hasFill)
    }
    
    private func drawWithCoreGraphics(context: CGContext, font: CTFont, hasStroke: Bool, hasFill: Bool) {
        // CORE GRAPHICS + CORE TEXT HYBRID: Use Core Text for layout, Core Graphics for rendering
        context.saveGState()
        
        // Create Core Text line for proper text layout
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: typography.letterSpacing
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // Get glyph runs for manual drawing
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        
        // Set text matrix (flip Y for proper orientation)
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        
        // Convert colors to Core Graphics
        let fillCGColor = typography.fillColor.cgColor.copy(alpha: typography.fillOpacity) ?? typography.fillColor.cgColor
        let strokeCGColor = typography.strokeColor.cgColor.copy(alpha: typography.strokeOpacity) ?? typography.strokeColor.cgColor
        
        // Position text at baseline
        let drawPoint = CGPoint(x: position.x, y: position.y)
        
        // Draw each glyph run manually for proper fill/stroke control
        var xOffset: CGFloat = 0
        
        for run in runs {
            let glyphCount = CTRunGetGlyphCount(run)
            var glyphs = Array<CGGlyph>(repeating: 0, count: glyphCount)
            var positions = Array<CGPoint>(repeating: .zero, count: glyphCount)
            
            CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, 0), &positions)
            
            // Get font for this run
            let runAttributes = CTRunGetAttributes(run) as! [String: Any]
            let runFont = runAttributes[kCTFontAttributeName as String] as! CTFont
            
            // Set drawing mode and colors
            if hasStroke && hasFill {
                context.setTextDrawingMode(.fillStroke)
                context.setFillColor(fillCGColor)
                context.setStrokeColor(strokeCGColor)
                context.setLineWidth(typography.strokeWidth)
            } else if hasStroke {
                context.setTextDrawingMode(.stroke)
                context.setStrokeColor(strokeCGColor)
                context.setLineWidth(typography.strokeWidth)
            } else if hasFill {
                context.setTextDrawingMode(.fill)
                context.setFillColor(fillCGColor)
            }
            
            // Draw glyphs with proper positioning
            for i in 0..<glyphCount {
                var glyphPosition = CGPoint(
                    x: drawPoint.x + positions[i].x + xOffset,
                    y: drawPoint.y + positions[i].y
                )
                context.textPosition = glyphPosition
                CTFontDrawGlyphs(runFont, &glyphs[i], &glyphPosition, 1, context)
            }
            
            // Update offset for next run
            if glyphCount > 0 {
                xOffset += positions[glyphCount - 1].x
            }
        }
        
        context.restoreGState()
    }

    
    private func createCoreTextFont() -> CTFont {
        // SURGICAL FIX: Use the existing nsFont property from TypographyProperties
        // This already handles weight and style correctly using SwiftUI's font system
        let nsFont = typography.nsFont
        
        // Convert NSFont to CTFont
        return CTFontCreateWithName(nsFont.fontName as CFString, typography.fontSize, nil)
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
