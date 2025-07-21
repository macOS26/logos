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
        
        // STEP 2: CRITICAL FIX - Core Text REQUIRES foregroundColor in NSAttributedString
        // Graphics context fill color is IGNORED by Core Text!
        let nsColor = NSColor(cgColor: typography.fillColor.cgColor) ?? NSColor.red // Red fallback to debug failures
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: typography.letterSpacing,
            .foregroundColor: nsColor
        ]
        
        print("🎨 CORE TEXT FIX: Using NSAttributedString.foregroundColor=\(nsColor) instead of graphics context")
        
        // STEP 3: Create attributed string WITH color information (required by Core Text)
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
        
        // STEP 9: USE DRAWING APP COLOR SYSTEM - DEBUG COLORS
        let hasStroke = typography.hasStroke && typography.strokeColor != .clear && typography.strokeWidth > 0
        let hasFill = true // Always render fill using drawing app colors
        
        // DEBUG: Print actual colors being used
        print("🎨 TEXT RENDER: fillColor=\(typography.fillColor), strokeColor=\(typography.strokeColor)")
        print("🎨 TEXT RENDER: hasStroke=\(hasStroke), hasFill=\(hasFill)")
        
        // Convert colors using direct cgColor (no NSColor conversion)
        let baseFillCGColor = typography.fillColor.cgColor
        let fillCGColor = baseFillCGColor.copy(alpha: typography.fillOpacity) ?? baseFillCGColor
        let baseStrokeCGColor = typography.strokeColor.cgColor  
        let strokeCGColor = baseStrokeCGColor.copy(alpha: typography.strokeOpacity) ?? baseStrokeCGColor
        
        // DEBUG: Print actual CGColor values being used
        print("🎨 CGColor DEBUG: baseFillCGColor=\(baseFillCGColor), finalFillCGColor=\(fillCGColor)")
        print("🎨 CGColor DEBUG: baseStrokeCGColor=\(baseStrokeCGColor), finalStrokeCGColor=\(strokeCGColor)")
        
        // Clean rendering using drawing app color system
        
                // SIMPLIFIED: Core Text handles color via NSAttributedString.foregroundColor
        // No need to set graphics context colors since Core Text ignores them
        context.textPosition = drawPoint
        
        if hasStroke && hasFill {
            // Both fill and stroke - Core Text handles fill, we add stroke manually
            CTLineDraw(line, context) // Fill handled by NSAttributedString.foregroundColor
            
            // Add stroke manually
            context.setTextDrawingMode(.stroke)
            context.setStrokeColor(strokeCGColor)
            context.setLineWidth(typography.strokeWidth)
            context.textPosition = drawPoint
            CTLineDraw(line, context)
            print("🎨 CORE TEXT: Fill via NSAttributedString + manual stroke")

        } else if hasStroke {
            // Stroke only - override NSAttributedString color with stroke
            context.setTextDrawingMode(.stroke)
            context.setStrokeColor(strokeCGColor)
            context.setLineWidth(typography.strokeWidth)
            context.textPosition = drawPoint
            CTLineDraw(line, context)
            print("🎨 CORE TEXT: Stroke only override")

        } else {
            // Fill only - Core Text handles everything via NSAttributedString.foregroundColor
            CTLineDraw(line, context)
            print("🎨 CORE TEXT: Fill via NSAttributedString.foregroundColor")
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
