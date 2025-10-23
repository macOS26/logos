import SwiftUI

struct ProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let textObjectID: UUID
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let viewMode: ViewMode

    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero
    @State private var textBoxState: TextBoxState = .gray
    @State private var isResizeHandleActive = false
    @State private var clickLocation: CGPoint? = nil

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
                zoomLevel: CGFloat(document.viewState.zoomLevel),
                viewMode: viewMode
            )

            ProfessionalTextDisplayView(
                viewModel: viewModel,
                dragOffset: dragOffset,
                textBoxState: textBoxState,
                viewMode: viewMode
            )

            if textBoxState == .blue {
                ProfessionalResizeHandleView(
                    viewModel: viewModel,
                    dragOffset: dragOffset,
                    resizeOffset: resizeOffset,
                    zoomLevel: CGFloat(document.viewState.zoomLevel),
                    viewMode: viewMode,
                    onResizeChanged: handleResizeChanged,
                    onResizeEnded: handleResizeEnded,
                    onResizeStarted: handleResizeStarted
                )
            }
        }
        .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
        .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
        .offset(x: shouldApplyDragPreview() ? dragPreviewDelta.x * document.viewState.zoomLevel : 0,
                y: shouldApplyDragPreview() ? dragPreviewDelta.y * document.viewState.zoomLevel : 0)
        .id(dragPreviewTrigger)
        .onKeyPress(action: handleKeyPress)
        .onChange(of: document.viewState.selectedObjectIDs) { _, selectedIDs in
            updateTextBoxState(selectedIDs: selectedIDs)
        }
        .onChange(of: viewModel.isEditing) { _, isEditing in
            updateTextBoxState(selectedIDs: document.viewState.selectedObjectIDs)
        }
        .onChange(of: viewModel.textObject.isEditing) { _, isEditing in
            viewModel.isEditing = isEditing
            updateTextBoxState(selectedIDs: document.viewState.selectedObjectIDs)
        }
        .onAppear {
            updateTextBoxState(selectedIDs: document.viewState.selectedObjectIDs)

            viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
        }
        .onChange(of: document.viewState.currentTool) { oldTool, newTool in
            handleToolChange(oldTool: oldTool, newTool: newTool)
        }
    }

    private func shouldApplyDragPreview() -> Bool {
        // Check if this text object is directly selected
        if document.viewState.selectedObjectIDs.contains(textObjectID) {
            return true
        }

        // Check if this text is inside a selected group
        for selectedID in document.viewState.selectedObjectIDs {
            if let selectedObject = document.findObject(by: selectedID) {
                switch selectedObject.objectType {
                case .group(let selectedShape), .clipGroup(let selectedShape):
                    if selectedShape.isGroupContainer {
                        if selectedShape.groupedShapes.contains(where: { $0.id == textObjectID }) {
                            return true
                        }
                    }
                default:
                    continue
                }
            }
        }

        return false
    }

    private func handleToolChange(oldTool: DrawingTool, newTool: DrawingTool) {
        let isThisTextSelected = document.viewState.selectedObjectIDs.contains(textObjectID)

        if oldTool != .font && newTool == .font && (textBoxState == .green || isThisTextSelected) {

            for unifiedObj in document.unifiedObjects {
                guard case .text(let shape) = unifiedObj.objectType,
                      shape.id != viewModel.textObject.id,
                      shape.isEditing == true else { continue }

                document.setTextEditingInUnified(id: shape.id, isEditing: false)
            }

            viewModel.startEditing()

            document.setTextEditingInUnified(id: viewModel.textObject.id, isEditing: true)

            textBoxState = .blue

            updateTextBoxState(selectedIDs: document.viewState.selectedObjectIDs)
        }

        if oldTool == .font && newTool != .font && viewModel.isEditing {
            viewModel.stopEditing()

            document.setTextEditingInUnified(id: viewModel.textObject.id, isEditing: false)

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

        let isTextToolActive = document.viewState.currentTool == .font
        let isThisTextSelected = selectedIDs.contains(currentTextObject.id)

        if isTextToolActive && isThisTextSelected {
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

                if let window = NSApp.keyWindow {
                    window.makeFirstResponder(nil)
                }
            }

            // When entering blue mode (editing), position cursor at mouse location
            if oldState != .blue && textBoxState == .blue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if let window = NSApp.keyWindow,
                       let textView = window.firstResponder as? NSTextView,
                       let layoutManager = textView.layoutManager,
                       let textContainer = textView.textContainer {

                        // Get current mouse location in window coordinates
                        let mouseLocationInWindow = window.mouseLocationOutsideOfEventStream

                        // Convert to text view coordinates
                        let mouseLocationInTextView = textView.convert(mouseLocationInWindow, from: nil)

                        // Get character index at mouse point
                        let glyphIndex = layoutManager.glyphIndex(for: mouseLocationInTextView, in: textContainer)
                        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

                        // Set cursor at that position
                        textView.setSelectedRange(NSRange(location: characterIndex, length: 0))
                    }
                }
            }
        }
    }

    private func handleTextBoxSelect(location: CGPoint) {
        // Store click location for cursor positioning
        clickLocation = location

        for unifiedObj in document.unifiedObjects {
            guard case .text(let shape) = unifiedObj.objectType,
                  shape.id != viewModel.textObject.id,
                  shape.isEditing == true else { continue }

            document.setTextEditingInUnified(id: shape.id, isEditing: false)
        }

        switch textBoxState {
        case .gray:
            textBoxState = .green
            document.viewState.selectedObjectIDs = [viewModel.textObject.id]

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

            if let window = NSApp.keyWindow {
                window.makeFirstResponder(nil)
            }

            return .handled
        }

        return .ignored
    }
}
