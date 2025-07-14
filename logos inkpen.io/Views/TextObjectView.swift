//
//  TextObjectView.swift
//  logos
//
//  Core Graphics Text Rendering - PURE SWIFTUI
//  COORDINATE SYSTEM: EXACTLY MATCHES SHAPES AND PEN TOOL
//

import SwiftUI
import CoreGraphics

struct TextObjectView: View {
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isSelected: Bool
    let isEditing: Bool
    
    var body: some View {
        ZStack {
            // FIXED: Pure SwiftUI text rendering with Core Graphics
            // Uses EXACT SAME coordinate system as shapes
            PureSwiftUITextView(
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

// MARK: - Pure SwiftUI Text Renderer with Core Graphics

struct PureSwiftUITextView: View {
    let text: String
    let typography: TypographyProperties
    let position: CGPoint
    
    var body: some View {
        // CRITICAL: Pure SwiftUI text rendering using Canvas
        Canvas { context, size in
            // FIXED: Core Graphics text rendering at exact position
            // Text is positioned at baseline (Core Graphics standard)
            let drawPoint = CGPoint(x: position.x, y: position.y)
            
            // FIXED: Use typography colors properly - ensure visible text
            var textColor: Color
            if typography.fillColor != .clear {
                textColor = Color(typography.fillColor.color).opacity(typography.fillOpacity)
            } else if typography.hasStroke && typography.strokeColor != .clear {
                textColor = Color(typography.strokeColor.color).opacity(typography.strokeOpacity)
            } else {
                // Final fallback to black for visibility
                textColor = Color.black
            }
            
            // CRITICAL: Draw text at baseline position using SwiftUI Canvas
            // The position is the baseline point (Core Graphics standard)
            var baseTextView = Text(text)
                .font(Font.custom(typography.fontFamily, size: typography.fontSize)
                    .weight(typography.fontWeight.systemWeight))
            
            // Apply font style (italic/oblique)
            if typography.fontStyle == .italic {
                baseTextView = baseTextView.italic()
            }
            
            // PROFESSIONAL TEXT STROKE: Draw stroke first, then fill (Adobe Illustrator standard)
            if typography.hasStroke && typography.strokeColor != .clear && typography.strokeWidth > 0 {
                // Draw stroke by drawing multiple offset copies in stroke color
                let strokeColor = Color(typography.strokeColor.color).opacity(typography.strokeOpacity)
                let strokeWidth = typography.strokeWidth
                
                for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
                    let offsetX = cos(angle * .pi / 180) * strokeWidth
                    let offsetY = sin(angle * .pi / 180) * strokeWidth
                    let strokePoint = CGPoint(x: drawPoint.x + offsetX, y: drawPoint.y + offsetY)
                    
                    context.draw(
                        baseTextView.foregroundColor(strokeColor),
                        at: strokePoint,
                        anchor: .bottomLeading
                    )
                }
            }
            
            // Draw fill text on top
            context.draw(
                baseTextView.foregroundColor(textColor),
                at: drawPoint,
                anchor: .bottomLeading
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview Support

#Preview {
    let sampleTypography = TypographyProperties(
        fontFamily: "Helvetica",
        fontWeight: .regular,
        fontStyle: .normal,
        fontSize: 24.0,
        hasStroke: false,
        fillColor: .black
    )
    
    let sampleText = VectorText(
        content: "Sample Text",
        typography: sampleTypography,
        position: CGPoint(x: 50, y: 50)
    )
    
    TextObjectView(
        textObject: sampleText,
        zoomLevel: 1.0,
        canvasOffset: .zero,
        isSelected: false,
        isEditing: false
    )
} 