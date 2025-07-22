//
//  TextObjectView.swift
//  logos
//
//  Professional Core Graphics Text Editing - INTEGRATED WITH NEW TEXTBOX SYSTEM
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
    @ObservedObject var document: VectorDocument
    
    // NEW: TextBox integration state
    @StateObject private var textEditorViewModel = TextEditorViewModel()
    @State private var useNewTextBox = false
    
    var body: some View {
        ZStack {
            if useNewTextBox && document.currentTool == .font && isSelected {
                // NEW: Use advanced TextBox system when font tool is active and text is selected
                NewTextBoxView(
                    textObject: textObject,
                    viewModel: textEditorViewModel,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    document: document
                )
            } else {
                // EXISTING: Use current text rendering for non-font tools or unselected text
                LegacyTextObjectView(
                    textObject: textObject,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    isSelected: isSelected,
                    isEditing: isEditing
                )
            }
        }
        .onAppear {
            syncTextEditorViewModel()
        }
        .onChange(of: textObject.content) { _, _ in
            syncTextEditorViewModel()
        }
        .onChange(of: textObject.typography) { _, _ in
            syncTextEditorViewModel()
        }
        .onChange(of: document.currentTool) { _, newTool in
            useNewTextBox = (newTool == .font && isSelected)
        }
        .onChange(of: isSelected) { _, selected in
            useNewTextBox = (document.currentTool == .font && selected)
        }
    }
    
    private func syncTextEditorViewModel() {
        textEditorViewModel.text = textObject.content
        textEditorViewModel.fontSize = CGFloat(textObject.typography.fontSize)
        textEditorViewModel.selectedFont = textObject.typography.nsFont
        textEditorViewModel.textColor = Color(textObject.typography.fillColor.color)
        textEditorViewModel.textAlignment = textObject.typography.alignment.nsTextAlignment
        textEditorViewModel.lineSpacing = CGFloat(textObject.typography.lineHeight)
        
        // Set text box frame based on text position and bounds
        textEditorViewModel.textBoxFrame = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: max(textObject.bounds.width, 200), // Minimum width
            height: max(textObject.bounds.height, 50)  // Minimum height
        )
    }
}

// NEW: Advanced TextBox view with Gray/Green/Blue states
struct NewTextBoxView: View {
    let textObject: VectorText
    @ObservedObject var viewModel: TextEditorViewModel
    let zoomLevel: Double
    let canvasOffset: CGPoint
    @ObservedObject var document: VectorDocument
    
    var body: some View {
        EditableTextCanvas(viewModel: viewModel)
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(textObject.transform)
            .onChange(of: viewModel.text) { _, newText in
                updateDocumentText(newText)
            }
            .onChange(of: viewModel.textAlignment) { _, newAlignment in
                updateDocumentAlignment(newAlignment)
            }
            .onChange(of: viewModel.lineSpacing) { _, newSpacing in
                updateDocumentLineSpacing(newSpacing)
            }
            .onChange(of: viewModel.textBoxFrame) { _, newFrame in
                updateDocumentPosition(newFrame)
            }
    }
    
    private func updateDocumentText(_ newText: String) {
        guard let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) else { return }
        document.saveToUndoStack()
        document.textObjects[textIndex].content = newText
        document.textObjects[textIndex].updateBounds()
        document.objectWillChange.send()
    }
    
    private func updateDocumentAlignment(_ newAlignment: NSTextAlignment) {
        guard let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) else { return }
        document.saveToUndoStack()
        document.textObjects[textIndex].typography.alignment = TextAlignment.fromNSTextAlignment(newAlignment)
        document.textObjects[textIndex].updateBounds()
        document.objectWillChange.send()
    }
    
    private func updateDocumentLineSpacing(_ newSpacing: CGFloat) {
        guard let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) else { return }
        document.saveToUndoStack()
        document.textObjects[textIndex].typography.lineHeight = Double(newSpacing)
        document.textObjects[textIndex].updateBounds()
        document.objectWillChange.send()
    }
    
    private func updateDocumentPosition(_ newFrame: CGRect) {
        guard let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) else { return }
        document.saveToUndoStack()
        document.textObjects[textIndex].position = CGPoint(x: newFrame.minX, y: newFrame.minY)
        document.textObjects[textIndex].updateBounds()
        document.objectWillChange.send()
    }
}

// EXISTING: Legacy text rendering (unchanged)
struct LegacyTextObjectView: View {
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
    
    // MARK: - Text Rendering
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
            // Fill only - standard text rendering
            let fillText = baseText.foregroundColor(Color(typography.fillColor.color))
            context.draw(fillText, at: position, anchor: .topLeading)
        }
    }
}

// MARK: - Helper Extensions

extension TextAlignment {
    static func fromNSTextAlignment(_ alignment: NSTextAlignment) -> TextAlignment {
        switch alignment {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        case .justified: return .justified
        default: return .left
        }
    }
} 
