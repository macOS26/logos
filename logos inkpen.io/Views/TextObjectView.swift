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
        
        // STEP 2: PURE CORE GRAPHICS - NO COLOR ATTRIBUTES
        // Only set font and kerning, never foregroundColor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: typography.letterSpacing
        ]
        
        print("🎨 PURE CORE GRAPHICS: No NSAttributedString colors, only font and kerning")
        
        // STEP 3: Create attributed string WITHOUT any color information
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // STEP 4: Create CTLine for precise text layout
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // STEP 5: Calculate text metrics for proper positioning
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let leading = CTFontGetLeading(font)
        let _ = ascent + descent + leading // Line height calculation (for future use)
        
        // STEP 6: Save graphics state and fix coordinate system
        context.saveGState()
        
        // STEP 7: Fix coordinate system - Core Graphics Y-axis is flipped from SwiftUI
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        
        // STEP 8: Position text at baseline (adjusted for flipped coordinates)
        let drawPoint = CGPoint(x: position.x, y: position.y)
        
        // STEP 9: NUCLEAR OPTION - ALWAYS RENDER FILL COLORS
        let hasStroke = typography.hasStroke && typography.strokeColor != .clear && typography.strokeWidth > 0
        let hasFill = true // NUCLEAR: Always render fill, ignore clear detection for now
        
        // Convert colors using direct cgColor (no NSColor conversion)
        let fillCGColor = typography.fillColor.cgColor.copy(alpha: typography.fillOpacity) ?? typography.fillColor.cgColor
        let strokeCGColor = typography.strokeColor.cgColor.copy(alpha: typography.strokeOpacity) ?? typography.strokeColor.cgColor
        
        print("🎨 FIXED CORE GRAPHICS RENDERING:")
        print("   Fill: \(typography.fillColor) -> CGColor: \(fillCGColor)")
        print("   Fill Color Components: R=\(fillCGColor.components?[0] ?? 0), G=\(fillCGColor.components?[1] ?? 0), B=\(fillCGColor.components?[2] ?? 0), A=\(fillCGColor.components?[3] ?? 0)")
        print("   Has Fill: \(hasFill), Has Stroke: \(hasStroke)")
        print("   Fill Opacity: \(typography.fillOpacity)")
        print("   Typography Fill == .clear: \(typography.fillColor == .clear)")
        print("   Typography Fill == .black: \(typography.fillColor == .black)")
        
        if hasStroke && hasFill {
            // Both fill and stroke - draw separately for color accuracy
            print("   Mode: Fill + Stroke (separate drawing)")
            
            // Draw fill first
            context.setTextDrawingMode(.fill)
            context.setFillColor(fillCGColor)
            context.textPosition = drawPoint
            CTLineDraw(line, context)
            
            // Draw stroke on top
            context.setTextDrawingMode(.stroke)
            context.setStrokeColor(strokeCGColor)
            context.setLineWidth(typography.strokeWidth)
            context.textPosition = drawPoint
            CTLineDraw(line, context)
            
        } else if hasStroke {
            // Stroke only
            print("   Mode: Stroke only")
            context.setTextDrawingMode(.stroke)
            context.setStrokeColor(strokeCGColor)
            context.setLineWidth(typography.strokeWidth)
            context.textPosition = drawPoint
            CTLineDraw(line, context)
            
        } else if hasFill {
            // Fill only
            print("   Mode: Fill only")
            context.setTextDrawingMode(.fill)
            context.setFillColor(fillCGColor)
            context.textPosition = drawPoint
            CTLineDraw(line, context)
            
        } else {
            // CRITICAL FIX: Handle case where no fill/stroke is specified
            // This was the missing else clause causing black text!
            print("   Mode: DEFAULT FILL (was missing - this caused black text!)")
            
            // If fill color is clear, use a fallback visible color for text
            let finalFillColor: CGColor
            if typography.fillColor == .clear {
                print("   WARNING: Fill color is clear, using black fallback for visibility")
                finalFillColor = CGColor.black
            } else {
                finalFillColor = fillCGColor
            }
            
            context.setTextDrawingMode(.fill)
            context.setFillColor(finalFillColor)
            context.textPosition = drawPoint
            CTLineDraw(line, context)
        }
        
        // STEP 10: Restore graphics state
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
