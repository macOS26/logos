//
//  TextObjectView.swift
//  logos
//
//  Professional Text Editing with New Text Box System
//  Uses Gray/Green/Blue text box states with VectorText integration
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
    
    // NEW: Bridge to new text box system
    @StateObject private var textEditorViewModel = TextEditorViewModel()
    @State private var textBoxState: TextBoxState = .gray
    @State private var isDragging = false
    @State private var isResizing = false
    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero
    @FocusState private var isFocused: Bool
    
    // NEW: Document communication closures
    let onTextSelectionChange: (UUID, Bool) -> Void
    let onTextEditingChange: (UUID, Bool) -> Void
    let onTextContentChange: (UUID, String) -> Void
    let onTextPositionChange: (UUID, CGPoint) -> Void
    let onTextBoundsChange: (UUID, CGRect) -> Void
    
    enum TextBoxState {
        case gray    // Initial state - no selection, no editing
        case green   // Selected - can double-click or drag
        case blue    // Editing mode
    }
    
    init(textObject: VectorText, 
         zoomLevel: Double, 
         canvasOffset: CGPoint, 
         isSelected: Bool, 
         isEditing: Bool,
         onTextSelectionChange: @escaping (UUID, Bool) -> Void = { _, _ in },
         onTextEditingChange: @escaping (UUID, Bool) -> Void = { _, _ in },
         onTextContentChange: @escaping (UUID, String) -> Void = { _, _ in },
         onTextPositionChange: @escaping (UUID, CGPoint) -> Void = { _, _ in },
         onTextBoundsChange: @escaping (UUID, CGRect) -> Void = { _, _ in }) {
        self.textObject = textObject
        self.zoomLevel = zoomLevel
        self.canvasOffset = canvasOffset
        self.isSelected = isSelected
        self.isEditing = isEditing
        self.onTextSelectionChange = onTextSelectionChange
        self.onTextEditingChange = onTextEditingChange
        self.onTextContentChange = onTextContentChange
        self.onTextPositionChange = onTextPositionChange
        self.onTextBoundsChange = onTextBoundsChange
    }
    
    var body: some View {
        ZStack {
            // Text Box Background with state-based border
            Rectangle()
                .fill(Color.white.opacity(0.01)) // Nearly transparent
                .stroke(getBorderColor(), lineWidth: 2)
                .frame(width: adjustedTextBoxFrame.width, height: adjustedTextBoxFrame.height)
                .position(x: adjustedTextBoxFrame.midX, y: adjustedTextBoxFrame.midY)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            // Double-click starts editing
                            if textBoxState == .green {
                                startEditing()
                            }
                        }
                )
                .highPriorityGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            if textBoxState == .green && !isResizing {
                                handleDragChanged(value: value)
                            }
                        }
                        .onEnded { _ in
                            handleDragEnded()
                        }
                )
                .onTapGesture(count: 1) {
                    // Single click selects
                    if textBoxState == .gray {
                        selectText()
                    }
                }
            
            // Text Content - use new text system when editing, SwiftUI when not
            if textBoxState == .blue {
                // BLUE STATE: Use new text box system for editing
                EditableTextCanvas(viewModel: textEditorViewModel)
                    .frame(width: adjustedTextBoxFrame.width, height: adjustedTextBoxFrame.height)
                    .position(x: adjustedTextBoxFrame.midX, y: adjustedTextBoxFrame.midY)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .focused($isFocused)
            } else {
                // GRAY/GREEN STATE: Use SwiftUI Text for display
                SwiftUITextDisplayView(textObject: textObject)
                    .frame(width: adjustedTextBoxFrame.width, height: adjustedTextBoxFrame.height)
                    .position(x: adjustedTextBoxFrame.midX, y: adjustedTextBoxFrame.midY)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .allowsHitTesting(false) // Allow gestures to pass through
            }
            
            // Simple resize handle (only when selected)
            if textBoxState == .green || textBoxState == .blue {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
                    .position(x: adjustedTextBoxFrame.maxX + resizeOffset.width,
                             y: adjustedTextBoxFrame.maxY + resizeOffset.height)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .gesture(
                        DragGesture()
                            .onChanged(handleResizeChanged)
                            .onEnded { _ in handleResizeEnded() }
                    )
            }
        }
        .onAppear {
            syncFromVectorText()
            updateTextBoxState()
        }
        .onChange(of: isSelected) { _, selected in
            updateTextBoxState()
        }
        .onChange(of: isEditing) { _, editing in
            updateTextBoxState()
        }
        .onChange(of: textEditorViewModel.text) { _, newText in
            // Sync back to VectorText when text changes
            onTextContentChange(textObject.id, newText)
        }
        .onChange(of: textEditorViewModel.fontSize) { _, _ in
            syncToVectorText()
        }
        .onChange(of: textEditorViewModel.selectedFont) { _, _ in
            syncToVectorText()
        }
        .onChange(of: textEditorViewModel.textColor) { _, _ in
            syncToVectorText()
        }
        .onChange(of: textEditorViewModel.textAlignment) { _, _ in
            syncToVectorText()
        }
        .onChange(of: textEditorViewModel.lineSpacing) { _, _ in
            syncToVectorText()
        }
    }
    
    // MARK: - Helper Methods
    
    private var adjustedTextBoxFrame: CGRect {
        let frame = textObject.bounds
        return CGRect(
            x: textObject.position.x + frame.minX + dragOffset.width,
            y: textObject.position.y + frame.minY + dragOffset.height,
            width: max(frame.width + resizeOffset.width, 50),
            height: max(frame.height + resizeOffset.height, 30)
        )
    }
    
    private func getBorderColor() -> Color {
        switch textBoxState {
        case .gray: return Color.gray.opacity(0.3)
        case .green: return Color.green
        case .blue: return Color.blue
        }
    }
    
    private func updateTextBoxState() {
        let newState: TextBoxState
        
        if isEditing {
            newState = .blue
        } else if isSelected {
            newState = .green
        } else {
            newState = .gray
        }
        
        // Only update if state changed
        if textBoxState != newState {
            textBoxState = newState
            
            // Update focus state
            if textBoxState == .blue {
                isFocused = true
                textEditorViewModel.startEditing()
            } else {
                isFocused = false
                textEditorViewModel.stopEditing()
            }
        }
    }
    
    private func selectText() {
        textBoxState = .green
        onTextSelectionChange(textObject.id, true)
    }
    
    private func startEditing() {
        textBoxState = .blue
        isFocused = true
        textEditorViewModel.startEditing()
        onTextEditingChange(textObject.id, true)
    }
    
    private func stopEditing() {
        textBoxState = isSelected ? .green : .gray
        isFocused = false
        textEditorViewModel.stopEditing()
        onTextEditingChange(textObject.id, false)
    }
    
    // MARK: - Sync between new system and VectorText
    
    private func syncFromVectorText() {
        // Copy VectorText properties to TextEditorViewModel
        textEditorViewModel.text = textObject.content
        textEditorViewModel.fontSize = CGFloat(textObject.typography.fontSize)
        textEditorViewModel.selectedFont = textObject.typography.nsFont
        textEditorViewModel.textColor = Color(textObject.typography.fillColor.color)
        textEditorViewModel.textAlignment = textObject.typography.alignment.nsTextAlignment
        textEditorViewModel.lineSpacing = CGFloat(textObject.typography.lineHeight)
        
        // Set text box frame
        textEditorViewModel.textBoxFrame = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: max(textObject.bounds.width, 100),
            height: max(textObject.bounds.height, 50)
        )
    }
    
    private func syncToVectorText() {
        // This will be handled by the document when the onChange callbacks are triggered
        print("📝 Text sync: '\(textEditorViewModel.text)' size: \(textEditorViewModel.fontSize)")
    }
    
    // MARK: - Gesture Handlers
    
    private func handleDragChanged(value: DragGesture.Value) {
        if !isResizing && textBoxState == .green {
            isDragging = true
            dragOffset = value.translation
        }
    }
    
    private func handleDragEnded() {
        if isDragging {
            // Calculate new position and notify parent
            let newPosition = CGPoint(
                x: textObject.position.x + dragOffset.width,
                y: textObject.position.y + dragOffset.height
            )
            onTextPositionChange(textObject.id, newPosition)
            dragOffset = .zero
            isDragging = false
        }
    }
    
    private func handleResizeChanged(value: DragGesture.Value) {
        isResizing = true
        resizeOffset = value.translation
    }
    
    private func handleResizeEnded() {
        if isResizing {
            // Calculate new bounds and notify parent
            let newBounds = CGRect(
                x: textObject.bounds.minX,
                y: textObject.bounds.minY,
                width: max(textObject.bounds.width + resizeOffset.width, 50),
                height: max(textObject.bounds.height + resizeOffset.height, 30)
            )
            onTextBoundsChange(textObject.id, newBounds)
            resizeOffset = .zero
            isResizing = false
        }
        dragOffset = .zero
        isDragging = false
    }
}

// MARK: - SwiftUI Text Display for Gray/Green states

struct SwiftUITextDisplayView: View {
    let textObject: VectorText
    
    private var swiftUIAlignment: HorizontalAlignment {
        switch textObject.typography.alignment {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        case .justified:
            return .leading // For justified, we'll handle it differently
        }
    }
    
    var body: some View {
        VStack(alignment: swiftUIAlignment, spacing: 0) {
            Text(textObject.content.isEmpty ? "Text" : textObject.content)
                .font(textObject.typography.swiftUIFont)
                .foregroundColor(Color(textObject.typography.fillColor.color))
                .lineSpacing(CGFloat(textObject.typography.lineHeight))
                .multilineTextAlignment(textObject.typography.alignment == .justified ? .leading : 
                    (textObject.typography.alignment == .left ? .leading :
                     textObject.typography.alignment == .center ? .center : .trailing))
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: swiftUIAlignment, vertical: .top))
            Spacer()
        }
    }
} 
