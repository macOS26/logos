//
//  ProfessionalTextCanvas.swift
//  logos inkpen.io
//
//  Professional text canvas main view with event handlers
//

import SwiftUI

// MARK: - Professional Text Canvas (Based on Working EditableTextCanvas)
struct ProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let textObjectID: UUID // Store the text object ID for reliable state checking

    // NEW: Drag preview parameters for live preview during dragging
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    // Drag state managed by arrow tool, resize state managed locally in handler
    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero
    @State private var textBoxState: TextBoxState = .gray
    @State private var isResizeHandleActive = false  // NEW: Track resize handle state

    enum TextBoxState {
        case gray    // Initial state - no selection, no editing
        case green   // Selected - can double-click or drag
        case blue    // Editing mode
    }

    var body: some View {
        ZStack {
            ProfessionalTextBoxView(
                viewModel: viewModel,
                dragOffset: dragOffset,
                resizeOffset: resizeOffset,
                textBoxState: textBoxState,
                isResizeHandleActive: isResizeHandleActive,  // NEW: Pass resize handle state
                onTextBoxSelect: handleTextBoxSelect,
                zoomLevel: CGFloat(document.zoomLevel)
            )

            ProfessionalTextDisplayView(
                viewModel: viewModel,
                dragOffset: dragOffset,
                textBoxState: textBoxState
            )

            // RESIZE HANDLE ONLY VISIBLE IN BLUE (EDITING) MODE - NOT IN GREEN (SELECTION) MODE
            if textBoxState == .blue {
                ProfessionalResizeHandleView(
                    viewModel: viewModel,
                    dragOffset: dragOffset,
                    resizeOffset: resizeOffset,
                    zoomLevel: CGFloat(document.zoomLevel),
                    onResizeChanged: handleResizeChanged,
                    onResizeEnded: handleResizeEnded,
                    onResizeStarted: handleResizeStarted  // NEW: Track when resize starts
                )
            }
        }
        // CRITICAL FIX: Apply the SAME coordinate system as all other objects
        .scaleEffect(document.zoomLevel, anchor: .topLeading)
        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        // ULTRA FAST 60FPS: Apply drag preview offset for selected text objects
        // CRITICAL FIX: Also check if this text object is part of a selected group
        .offset(x: shouldApplyDragPreview() ? dragPreviewDelta.x * document.zoomLevel : 0,
                y: shouldApplyDragPreview() ? dragPreviewDelta.y * document.zoomLevel : 0)
        .id(dragPreviewTrigger) // Force efficient re-render when trigger changes
        .onKeyPress(action: handleKeyPress)
        .onChange(of: document.selectedTextIDs) { _, selectedIDs in
            updateTextBoxState(selectedIDs: selectedIDs)
        }
        .onChange(of: viewModel.isEditing) { _, isEditing in
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }
        .onChange(of: viewModel.textObject.isEditing) { _, isEditing in
            // Sync view model with document
            viewModel.isEditing = isEditing
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }
        .onAppear {
            updateTextBoxState(selectedIDs: document.selectedTextIDs)

            // CRITICAL FIX: Ensure VectorText bounds match text canvas on initial appearance
            // This fixes the selection box when text is first created
            viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
        }
        .onChange(of: document.currentTool) { oldTool, newTool in
            handleToolChange(oldTool: oldTool, newTool: newTool)
        }
    }

    // MARK: - Helper Functions

    /// Check if this text object should have drag preview applied
    /// Returns true if: 1) text is directly selected, OR 2) text is part of a selected group
    private func shouldApplyDragPreview() -> Bool {
        // Check if directly selected
        if document.selectedTextIDs.contains(textObjectID) {
            return true
        }

        // Check if this text object is part of a selected group
        // Find all selected shapes that are groups
        for selectedID in document.selectedShapeIDs {
            if let selectedObject = document.findObject(by: selectedID),
               case .shape(let selectedShape) = selectedObject.objectType,
               selectedShape.isGroupContainer {
                // Check if this text object is in the group
                if selectedShape.groupedShapes.contains(where: { $0.id == textObjectID && $0.isTextObject }) {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Tool Change Handler

    private func handleToolChange(oldTool: DrawingTool, newTool: DrawingTool) {
        // NEW: When user selects type tool and this text box is GREEN (selected), change to BLUE (editing)
        // FIXED: Also check if this text is in the selected text IDs to handle the case where state might not be green yet
        let isThisTextSelected = document.selectedTextIDs.contains(textObjectID)

        if oldTool != .font && newTool == .font && (textBoxState == .green || isThisTextSelected) {

            // CRITICAL: Ensure only one text box can be edited at a time
            // OPTIMIZATION: Only stop editing on text boxes that are actually editing
            for unifiedObj in document.unifiedObjects {
                guard case .shape(let shape) = unifiedObj.objectType,
                      shape.isTextObject,
                      shape.id != viewModel.textObject.id,
                      shape.isEditing == true else { continue }

                document.setTextEditingInUnified(id: shape.id, isEditing: false)
            }

            // Start editing this text box
            viewModel.startEditing()

            // Update document editing state
            document.setTextEditingInUnified(id: viewModel.textObject.id, isEditing: true)

            // CRITICAL FIX: Force immediate state update and sync
            textBoxState = .blue

            // Update state immediately
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }

        // PROFESSIONAL UX: Stop editing when user switches away from font tool
        if oldTool == .font && newTool != .font && viewModel.isEditing {
            viewModel.stopEditing()

            // Update document editing state
            document.setTextEditingInUnified(id: viewModel.textObject.id, isEditing: false)

            textBoxState = .gray
        }

        // CRITICAL FIX: Update bounds when switching away from font tool
        // This ensures selection box is correct when using arrow tool
        if oldTool == .font && newTool != .font {
            viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
        }
    }

    // MARK: - State Management (From Working Code)

    private func updateTextBoxState(selectedIDs: Set<UUID>) {
        let oldState = textBoxState

        // PERFORMANCE: Use UUID lookup instead of looping
        guard let currentTextObject = document.findText(by: textObjectID) else {
            textBoxState = .gray
            return
        }

        // CRITICAL RULE: NO blue text boxes can exist unless font tool is selected
        let isTextToolActive = document.currentTool == .font
        let isThisTextSelected = selectedIDs.contains(currentTextObject.id) // Use current document object

        // CRITICAL FIX: Only allow blue (editing) mode when font tool is active AND isEditing is true
        // REMOVED hasTextViewFocus check - it was matching ANY NSTextView, causing ALL text boxes to go blue!
        if isTextToolActive && currentTextObject.isEditing {
            textBoxState = .blue
        } else if isThisTextSelected {
            // When selected, stay GREEN unless explicitly in editing mode
            textBoxState = .green
        } else {
            textBoxState = .gray
        }

        if oldState != textBoxState {
            // VECTOR APP OPTIMIZATION: Save text to document when exiting editing mode
            if oldState == .blue && (textBoxState == .green || textBoxState == .gray) {
                // Save final text content and bounds to document
                viewModel.document.updateTextContent(viewModel.textObject.id, content: viewModel.text)
                viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)

            }
        }
    }

    // MARK: - Event Handlers (Exact from Working Code)

    private func handleTextBoxSelect(location: CGPoint) {
        // CRITICAL FIX: When clicking on ANY text box, stop editing all OTHER text boxes first
        // OPTIMIZATION: Only stop editing on text boxes that are actually editing
        for unifiedObj in document.unifiedObjects {
            guard case .shape(let shape) = unifiedObj.objectType,
                  shape.isTextObject,
                  shape.id != viewModel.textObject.id,
                  shape.isEditing == true else { continue }

            document.setTextEditingInUnified(id: shape.id, isEditing: false)
        }

        // SINGLE CLICK: Handle different states appropriately
        switch textBoxState {
        case .gray:
            // Select the text box
            textBoxState = .green
            document.selectedTextIDs = [viewModel.textObject.id]
            document.selectedShapeIDs.removeAll()

        case .green:
            // Already selected - no change needed
            break

        case .blue:
            // In editing mode - let NSTextView handle the click for text editing
            break
        }
    }

    // Arrow tool handles all text box dragging

    // NEW: Track when resize starts
    private func handleResizeStarted() {
        isResizeHandleActive = true
    }

    private func handleResizeChanged(value: DragGesture.Value) {
        // Begin resize
        resizeOffset = value.translation
    }

    private func handleResizeEnded() {
        let newFrame = CGRect(
            x: viewModel.textBoxFrame.minX,  // DON'T move position when resizing
            y: viewModel.textBoxFrame.minY,  // DON'T move position when resizing
            width: max(100, viewModel.textBoxFrame.width + resizeOffset.width),
            height: max(50, viewModel.textBoxFrame.height + resizeOffset.height)
        )


        viewModel.updateTextBoxFrame(newFrame)
        resizeOffset = .zero
        dragOffset = .zero
        isResizeHandleActive = false  // NEW: Reset resize handle state
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard viewModel.isEditing else { return .ignored }

        // ESC key exits editing mode
        if keyPress.key == .escape {
            // VECTOR APP OPTIMIZATION: Save text to document before exiting editing mode
            viewModel.document.updateTextContent(viewModel.textObject.id, content: viewModel.text)
            viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)

            textBoxState = .green
            viewModel.stopEditing()
            // Use unified system directly
            document.setTextEditingInUnified(id: viewModel.textObject.id, isEditing: false)
            return .handled
        }

        // Let NSTextView handle all other key events
        return .ignored
    }
}
