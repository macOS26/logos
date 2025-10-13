import SwiftUI

struct ProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let textObjectID: UUID

    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero
    @State private var textBoxState: TextBoxState = .gray
    @State private var isResizeHandleActive = false

    enum TextBoxState {
        case gray
        case green
        case blue
    }

    var body: some View {
        ZStack {
            ProfessionalTextBoxView(
                viewModel: viewModel,
                dragOffset: dragOffset,
                resizeOffset: resizeOffset,
                textBoxState: textBoxState,
                isResizeHandleActive: isResizeHandleActive,
                onTextBoxSelect: handleTextBoxSelect,
                zoomLevel: CGFloat(document.zoomLevel)
            )

            ProfessionalTextDisplayView(
                viewModel: viewModel,
                dragOffset: dragOffset,
                textBoxState: textBoxState
            )

            if textBoxState == .blue {
                ProfessionalResizeHandleView(
                    viewModel: viewModel,
                    dragOffset: dragOffset,
                    resizeOffset: resizeOffset,
                    zoomLevel: CGFloat(document.zoomLevel),
                    onResizeChanged: handleResizeChanged,
                    onResizeEnded: handleResizeEnded,
                    onResizeStarted: handleResizeStarted
                )
            }
        }
        .scaleEffect(document.zoomLevel, anchor: .topLeading)
        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        .offset(x: shouldApplyDragPreview() ? dragPreviewDelta.x * document.zoomLevel : 0,
                y: shouldApplyDragPreview() ? dragPreviewDelta.y * document.zoomLevel : 0)
        .id(dragPreviewTrigger)
        .onKeyPress(action: handleKeyPress)
        .onChange(of: document.selectedTextIDs) { _, selectedIDs in
            updateTextBoxState(selectedIDs: selectedIDs)
        }
        .onChange(of: viewModel.isEditing) { _, isEditing in
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }
        .onChange(of: viewModel.textObject.isEditing) { _, isEditing in
            viewModel.isEditing = isEditing
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }
        .onAppear {
            updateTextBoxState(selectedIDs: document.selectedTextIDs)

            viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
        }
        .onChange(of: document.currentTool) { oldTool, newTool in
            handleToolChange(oldTool: oldTool, newTool: newTool)
        }
    }


    private func shouldApplyDragPreview() -> Bool {
        if document.selectedTextIDs.contains(textObjectID) {
            return true
        }

        for selectedID in document.selectedShapeIDs {
            if let selectedObject = document.findObject(by: selectedID),
               case .shape(let selectedShape) = selectedObject.objectType,
               selectedShape.isGroupContainer {
                if selectedShape.groupedShapes.contains(where: { $0.id == textObjectID && $0.isTextObject }) {
                    return true
                }
            }
        }

        return false
    }


    private func handleToolChange(oldTool: DrawingTool, newTool: DrawingTool) {
        let isThisTextSelected = document.selectedTextIDs.contains(textObjectID)

        if oldTool != .font && newTool == .font && (textBoxState == .green || isThisTextSelected) {

            for unifiedObj in document.unifiedObjects {
                guard case .shape(let shape) = unifiedObj.objectType,
                      shape.isTextObject,
                      shape.id != viewModel.textObject.id,
                      shape.isEditing == true else { continue }

                document.setTextEditingInUnified(id: shape.id, isEditing: false)
            }

            viewModel.startEditing()

            document.setTextEditingInUnified(id: viewModel.textObject.id, isEditing: true)

            textBoxState = .blue

            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }

        if oldTool == .font && newTool != .font && viewModel.isEditing {
            viewModel.stopEditing()

            document.setTextEditingInUnified(id: viewModel.textObject.id, isEditing: false)

            // Resign first responder to restore key command handling
            if let window = NSApp.keyWindow {
                window.makeFirstResponder(nil)
            }

            textBoxState = .gray
        }

        if oldTool == .font && newTool != .font {
            viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
        }
    }


    private func updateTextBoxState(selectedIDs: Set<UUID>) {
        let oldState = textBoxState

        guard let currentTextObject = document.findText(by: textObjectID) else {
            textBoxState = .gray
            return
        }

        let isTextToolActive = document.currentTool == .font
        let isThisTextSelected = selectedIDs.contains(currentTextObject.id)

        if isTextToolActive && currentTextObject.isEditing {
            textBoxState = .blue
        } else if isThisTextSelected {
            textBoxState = .green
        } else {
            textBoxState = .gray
        }

        if oldState != textBoxState {
            if oldState == .blue && (textBoxState == .green || textBoxState == .gray) {
                viewModel.document.updateTextContent(viewModel.textObject.id, content: viewModel.text)
                viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)

                // Resign first responder when exiting editing mode
                if let window = NSApp.keyWindow {
                    window.makeFirstResponder(nil)
                }
            }
        }
    }


    private func handleTextBoxSelect(location: CGPoint) {
        for unifiedObj in document.unifiedObjects {
            guard case .shape(let shape) = unifiedObj.objectType,
                  shape.isTextObject,
                  shape.id != viewModel.textObject.id,
                  shape.isEditing == true else { continue }

            document.setTextEditingInUnified(id: shape.id, isEditing: false)
        }

        switch textBoxState {
        case .gray:
            textBoxState = .green
            document.selectedTextIDs = [viewModel.textObject.id]
            document.selectedShapeIDs.removeAll()

        case .green:
            break

        case .blue:
            break
        }
    }


    private func handleResizeStarted() {
        isResizeHandleActive = true
    }

    private func handleResizeChanged(value: DragGesture.Value) {
        resizeOffset = value.translation
    }

    private func handleResizeEnded() {
        let newFrame = CGRect(
            x: viewModel.textBoxFrame.minX,
            y: viewModel.textBoxFrame.minY,
            width: max(100, viewModel.textBoxFrame.width + resizeOffset.width),
            height: max(50, viewModel.textBoxFrame.height + resizeOffset.height)
        )


        viewModel.updateTextBoxFrame(newFrame)
        resizeOffset = .zero
        dragOffset = .zero
        isResizeHandleActive = false
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard viewModel.isEditing else { return .ignored }

        if keyPress.key == .escape {
            viewModel.document.updateTextContent(viewModel.textObject.id, content: viewModel.text)
            viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)

            textBoxState = .green
            viewModel.stopEditing()
            document.setTextEditingInUnified(id: viewModel.textObject.id, isEditing: false)

            // Resign first responder to restore key command handling
            if let window = NSApp.keyWindow {
                window.makeFirstResponder(nil)
            }

            return .handled
        }

        return .ignored
    }
}
