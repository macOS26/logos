import SwiftUI
import Combine

struct ProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    @StateObject private var viewModel: ProfessionalTextViewModel
    let textObjectID: UUID
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let viewMode: ViewMode

    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero
    @State private var textBoxState: TextBoxState = .gray
    @State private var isResizeHandleActive = false
    @State private var clickLocation: CGPoint? = nil

    init(document: VectorDocument, textObjectID: UUID, dragPreviewDelta: CGPoint = .zero, dragPreviewTrigger: Bool = false, viewMode: ViewMode = .color) {
        self.document = document
        self.textObjectID = textObjectID
        self.dragPreviewDelta = dragPreviewDelta
        self.dragPreviewTrigger = dragPreviewTrigger
        self.viewMode = viewMode

        let actualText = document.findText(by: textObjectID) ?? VectorText(content: "", typography: TypographyProperties(strokeColor: .black, fillColor: .black))
        self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: actualText, document: document))
    }

    enum TextBoxState {
        case gray
        case green
        case blue
    }

    var body: some View {
        let bounds = viewModel.textObject.bounds
        let position = viewModel.textObject.position
        let shouldAllowHitTesting = textBoxState == .blue

        ProfessionalUniversalTextView(
            viewModel: viewModel,
            textBoxState: textBoxState,
            viewMode: viewMode
        )
        .allowsHitTesting(shouldAllowHitTesting)
        .frame(
            width: bounds.width,
            height: bounds.height,
            alignment: .topLeading
        )
        .position(
            x: position.x + dragOffset.width + bounds.width / 2,
            y: position.y + dragOffset.height + bounds.height / 2
        )
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
            updateViewModelFromDocument()
            updateTextBoxState(selectedIDs: document.viewState.selectedObjectIDs)
            viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
        }
        .onReceive(document.objectWillChange) { _ in
            if let currentTextObject = document.findText(by: textObjectID) {
                viewModel.syncFromDocument(currentTextObject)
            }
        }
        .onChange(of: dragPreviewTrigger) { _, _ in
            if let currentTextObject = document.findText(by: textObjectID) {
                viewModel.syncFromDocument(currentTextObject)
            }
        }
        .onChange(of: document.viewState.currentTool) { oldTool, newTool in
            print("🟢 ProfessionalTextCanvas.onChange currentTool: \(oldTool.rawValue) -> \(newTool.rawValue) for text \(textObjectID)")
            handleToolChange(oldTool: oldTool, newTool: newTool)
        }
    }

    private func updateViewModelFromDocument() {
        if let currentTextObject = document.findText(by: textObjectID) {
            if viewModel.textObject.id != textObjectID {
                viewModel.textObject = currentTextObject
                viewModel.text = currentTextObject.content
                viewModel.fontSize = CGFloat(currentTextObject.typography.fontSize)
                viewModel.selectedFont = currentTextObject.typography.nsFont
                viewModel.textAlignment = currentTextObject.typography.alignment.nsTextAlignment

                let width = currentTextObject.areaSize?.width ?? (currentTextObject.bounds.width > 1 ? currentTextObject.bounds.width : 200.0)
                let height = currentTextObject.areaSize?.height ?? (currentTextObject.bounds.height > 1 ? currentTextObject.bounds.height : 50.0)

                viewModel.textBoxFrame = CGRect(
                    x: currentTextObject.position.x,
                    y: currentTextObject.position.y,
                    width: width,
                    height: height
                )
            } else {
                viewModel.syncFromDocument(currentTextObject)
            }
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
        // When switching to font tool, find first text object in selection and edit it
        if oldTool != .font && newTool == .font {
            print("🔵 Tool changed to .font, textObjectID: \(textObjectID)")
            print("🔵 selectedObjectIDs: \(document.viewState.selectedObjectIDs)")

            // Find first text object in selectedObjectIDs
            var firstTextID: UUID? = nil
            for selectedID in document.viewState.selectedObjectIDs {
                if let obj = document.findObject(by: selectedID),
                   case .text = obj.objectType {
                    firstTextID = selectedID
                    print("🔵 Found text in selection: \(selectedID)")
                    break
                }
            }

            print("🔵 firstTextID: \(String(describing: firstTextID)), matches this? \(firstTextID == textObjectID)")

            // If this text is the first one selected, enter edit mode
            if let firstTextID = firstTextID, firstTextID == textObjectID {
                print("🔵 Entering edit mode for text \(textObjectID)")

                // Stop editing other text objects using snapshot
                for (_, obj) in document.snapshot.objects {
                    guard case .text(let shape) = obj.objectType,
                          shape.id != viewModel.textObject.id,
                          shape.isEditing == true else { continue }

                    document.setTextEditingInUnified(id: shape.id, isEditing: false)
                }

                viewModel.startEditing()

                document.setTextEditingInUnified(id: viewModel.textObject.id, isEditing: true)

                textBoxState = .blue

                updateTextBoxState(selectedIDs: document.viewState.selectedObjectIDs)
            }
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

        print("🔴 updateTextBoxState for \(textObjectID): isTextToolActive=\(isTextToolActive), isThisTextSelected=\(isThisTextSelected)")

        if isTextToolActive && isThisTextSelected {
            print("🔴 Setting textBoxState to .blue")
            textBoxState = .blue
        } else if isThisTextSelected {
            print("🔴 Setting textBoxState to .green")
            textBoxState = .green
        } else {
            print("🔴 Setting textBoxState to .gray")
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

        // Stop editing other text objects using snapshot
        for (_, obj) in document.snapshot.objects {
            guard case .text(let shape) = obj.objectType,
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
