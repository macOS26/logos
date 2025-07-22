//
//  TextObjectView.swift
//  logos
//
//  Professional Core Graphics Text Editing - SAME AS SHAPES
//  COORDINATE SYSTEM: EXACTLY MATCHES SHAPES AND PEN TOOL
//

import SwiftUI
import CoreGraphics
import CoreText

struct TextObjectView:
    View {
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isSelected: Bool
    let isEditing: Bool
    
    // NEW: Enhanced editing state
    @State private var cursorPosition: Int = 0
    @State private var selectionRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showCursor: Bool = true
    
    var body: some View {
        ZStack {
            // PURE SWIFTUI TEXT RENDERING - EXACT SAME AS SHAPES!
            // Canvas draws text at textObject.position, just like Path draws path elements at their coordinates
            Canvas { context, size in
                drawTextWithSwiftUI(context: context, typography: textObject.typography, text: textObject.content.isEmpty ? "Text" : textObject.content, position: textObject.position)
                
                
            }
            // EXACT SAME coordinate chain as shapes in ShapeView - NO .position() modifier!
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(textObject.transform)
            
            // ENHANCED: Professional selection outline using EXACT coordinate system as shapes
            if isSelected && !isEditing {
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
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(textObject.transform)
                .opacity(0.7)
            }
            
            // ENHANCED: Professional text selection highlighting
            if isEditing && selectionRange.length > 0 {
                drawTextSelection()
            }
            
            // ENHANCED: Professional I-beam cursor with precise positioning
            if isEditing && selectionRange.length == 0 && showCursor {
                drawTextCursor()
            }
        }
        .onAppear {
            if isEditing {
                startCursorAnimation()
            }
        }
        .onChange(of: isEditing) { oldValue, newValue in
            if newValue {
                startCursorAnimation()
                cursorPosition = textObject.content.count
            } else {
                stopCursorAnimation()
            }
        }
    }
    
    // MARK: - Enhanced Text Selection
    @ViewBuilder
    private func drawTextSelection() -> some View {
        let selectionRects = getSelectionRects()
        ForEach(selectionRects.indices, id: \.self) { index in
            Path { path in
                path.addRect(selectionRects[index])
            }
            .fill(Color.blue.opacity(0.3))
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(textObject.transform)
        }
    }
    
    // MARK: - Enhanced I-beam Cursor  
    @ViewBuilder
    private func drawTextCursor() -> some View {
        let cursorRect = getCursorRect()
        
        Path { path in
            path.addRect(cursorRect)
        }
        .fill(Color.blue)
        .scaleEffect(zoomLevel, anchor: .topLeading)
        .offset(x: canvasOffset.x, y: canvasOffset.y)
        .transformEffect(textObject.transform)
    }
    
    // MARK: - Professional Text Metrics Calculations
    
    private func getCursorRect() -> CGRect {
        let cursorX = textObject.position.x + getCursorXPosition(at: cursorPosition)
        
        return CGRect(
            x: cursorX - 0.5, // Center the 1pt cursor line
            y: textObject.position.y + textObject.bounds.minY,
            width: 1.0,
            height: textObject.bounds.height
        )
    }
    
    private func getCursorXPosition(at position: Int) -> CGFloat {
        guard position > 0 && position <= textObject.content.count else { return 0 }
        
        let substring = String(textObject.content.prefix(position))
        let nsString = NSString(string: substring)
        let font = textObject.typography.nsFont
        let textSize = nsString.size(withAttributes: [
            .font: font,
            .kern: textObject.typography.letterSpacing
        ])
        return textSize.width
    }
    
    private func getSelectionRects() -> [CGRect] {
        guard selectionRange.length > 0,
              selectionRange.location >= 0,
              selectionRange.location + selectionRange.length <= textObject.content.count else {
            return []
        }
        
        let startX = getCursorXPosition(at: selectionRange.location)
        let endX = getCursorXPosition(at: selectionRange.location + selectionRange.length)
        
        let selectionRect = CGRect(
            x: textObject.position.x + startX,
            y: textObject.position.y + textObject.bounds.minY,
            width: endX - startX,
            height: textObject.bounds.height
        )
        
        return [selectionRect]
    }
    
    // MARK: - Text Position Calculations (Core Graphics Integration)
    
    func getCharacterIndex(at point: CGPoint) -> Int {
        // Convert point from view coordinates to text-relative coordinates
        let relativePoint = CGPoint(
            x: point.x - textObject.position.x,
            y: point.y - textObject.position.y
        )
        
        // Use Core Text to find character index
        let nsFont = textObject.typography.nsFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .kern: textObject.typography.letterSpacing
        ]
        
        let attributedString = NSAttributedString(string: textObject.content, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // Get character index at the relative point
        let index = CTLineGetStringIndexForPosition(line, relativePoint)
        return max(0, min(textObject.content.count, index))
    }
    
    // MARK: - Cursor Animation
    
    private func startCursorAnimation() {
        showCursor = true
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            showCursor.toggle()
        }
    }
    
    private func stopCursorAnimation() {
        showCursor = false
    }
    
    // MARK: - Core Graphics Text Rendering (Same approach as shapes!)
    private func drawTextWithSwiftUI(context: GraphicsContext, typography: TypographyProperties, text: String, position: CGPoint) {
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
            context.draw(fillText, at: position, anchor: .topLeading)
            
            // Add stroke effect using multiple shadows
            let strokeWidth = typography.strokeWidth
            let strokeColor = Color(typography.strokeColor.color)
            
            for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
                let radians = angle * .pi / 180.0
                let offsetX = cos(radians) * strokeWidth * 0.5
                let offsetY = sin(radians) * strokeWidth * 0.5
                
                let strokeText = baseText.foregroundColor(strokeColor)
                context.draw(strokeText, at: CGPoint(x: position.x + offsetX, y: position.y + offsetY), anchor: .topLeading)
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
                context.draw(strokeText, at: CGPoint(x: position.x + offsetX, y: position.y + offsetY), anchor: .topLeading)
            }
            
        } else if hasFill {
            // Fill only - use fill color
            let fillText = baseText.foregroundColor(Color(typography.fillColor.color))
            context.draw(fillText, at: position, anchor: .topLeading)
        }
    }
}

// MARK: - Text Editing Extensions
extension TextObjectView {
    
    // NEW: Professional text editing methods
    func insertText(at position: Int, text: String) -> VectorText {
        var newContent = textObject.content
        let insertIndex = newContent.index(newContent.startIndex, offsetBy: min(position, newContent.count))
        newContent.insert(contentsOf: text, at: insertIndex)
        
        var updatedText = textObject
        updatedText.content = newContent
        updatedText.updateBounds()
        return updatedText
    }
    
    func deleteText(in range: NSRange) -> VectorText {
        guard range.location >= 0 && range.location + range.length <= textObject.content.count else {
            return textObject
        }
        
        var newContent = textObject.content
        let startIndex = newContent.index(newContent.startIndex, offsetBy: range.location)
        let endIndex = newContent.index(startIndex, offsetBy: range.length)
        newContent.removeSubrange(startIndex..<endIndex)
        
        var updatedText = textObject
        updatedText.content = newContent
        updatedText.updateBounds()
        return updatedText
    }
} 
