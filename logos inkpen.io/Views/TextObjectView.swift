//
//  TextObjectView.swift
//  logos
//
//  Pure SwiftUI Text Rendering - SAME AS SHAPES
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
            // PURE SWIFTUI TEXT RENDERING - SAME APPROACH AS SHAPES!
            // Uses SwiftUI Canvas for crisp text at all zoom levels, just like shapes use SwiftUI Path
            Canvas { context, size in
                drawTextWithSwiftUI(context: context, typography: textObject.typography, text: textObject.content.isEmpty ? "Text" : textObject.content)
            }
            // Position at text baseline, just like shapes are positioned at their path coordinates
            .position(x: textObject.position.x, y: textObject.position.y)
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
    
    // MARK: - SwiftUI Canvas Text Rendering (Same approach as shapes!)
    private func drawTextWithSwiftUI(context: GraphicsContext, typography: TypographyProperties, text: String) {
        // Determine fill and stroke requirements
        let hasStroke = typography.hasStroke && typography.strokeColor != .clear && typography.strokeWidth > 0
        let hasFill = typography.fillColor != .clear
        
        // Create the text to render
        let nsFont = typography.nsFont
        let attributedString = AttributedString(text)
        
        // Create base text
        let baseText = Text(attributedString).font(Font(nsFont))
        
        // Apply colors based on stroke/fill requirements and draw
        if hasStroke && hasFill {
            // Both stroke and fill - use fill color (stroke approximation with shadows)
            let fillText = baseText
                .foregroundColor(Color(typography.fillColor.color))
            context.draw(fillText, at: CGPoint.zero, anchor: .topLeading)
            
            // Add stroke effect using multiple shadows
            let strokeWidth = typography.strokeWidth
            let strokeColor = Color(typography.strokeColor.color)
            
            for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
                let radians = angle * .pi / 180.0
                let offsetX = cos(radians) * strokeWidth * 0.5
                let offsetY = sin(radians) * strokeWidth * 0.5
                
                let strokeText = baseText.foregroundColor(strokeColor)
                context.draw(strokeText, at: CGPoint(x: offsetX, y: offsetY), anchor: .topLeading)
            }
            
        } else if hasStroke {
            // Stroke only - use stroke color with shadow effect
            let strokeWidth = typography.strokeWidth
            let strokeColor = Color(typography.strokeColor.color)
            
            for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
                let radians = angle * .pi / 180.0
                let offsetX = cos(radians) * strokeWidth * 0.5
                let offsetY = sin(radians) * strokeWidth * 0.5
                
                let strokeText = baseText.foregroundColor(strokeColor)
                context.draw(strokeText, at: CGPoint(x: offsetX, y: offsetY), anchor: .topLeading)
            }
            
        } else if hasFill {
            // Fill only - use fill color
            let fillText = baseText.foregroundColor(Color(typography.fillColor.color))
            context.draw(fillText, at: CGPoint.zero, anchor: .topLeading)
        }
    }
} 
