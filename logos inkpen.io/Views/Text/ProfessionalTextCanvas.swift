import SwiftUI
import Combine
import AppKit

struct ProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    @StateObject private var viewModel: ProfessionalTextViewModel
    let textObjectID: UUID
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let viewMode: ViewMode

    @State private var textBoxState: TextBoxState = .gray

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

        TextViewRepresentable(
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
            x: position.x + bounds.width / 2,
            y: position.y + bounds.height / 2
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

    // MARK: - NSViewRepresentable for NSTextView

    struct TextViewRepresentable: NSViewRepresentable {
        @ObservedObject var viewModel: ProfessionalTextViewModel
        @State var isUpdatingFromTyping: Bool = false
        let textBoxState: TextBoxState
        let viewMode: ViewMode

        func makeNSView(context: Context) -> DisabledContextMenuTextView {
            let textView = DisabledContextMenuTextView()

            textView.isEditable = true
            textView.isSelectable = true

            let isEditingMode = (textBoxState == .blue)
            textView.allowsInteraction = isEditingMode
            textView.shouldShowCursor = isEditingMode
            textView.backgroundColor = NSColor.clear
            textView.textContainerInset = NSSize(width: 0, height: 0)
            textView.textContainer?.lineFragmentPadding = 0

            if isEditingMode {
                DispatchQueue.main.async {
                    textView.window?.makeFirstResponder(textView)
                }
            }

            textView.wantsLayer = true
            textView.layer?.masksToBounds = false

            let fixedWidth = viewModel.textObject.areaSize?.width ?? viewModel.textObject.bounds.width
            let fixedHeight = viewModel.textObject.areaSize?.height ?? viewModel.textObject.bounds.height

            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.heightTracksTextView = false
            textView.isVerticallyResizable = false
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = []

            textView.textContainer?.containerSize = NSSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude)
            textView.frame = CGRect(x: 0, y: 0, width: fixedWidth, height: fixedHeight)
            textView.textContainer?.lineBreakMode = .byWordWrapping
            textView.maxSize = NSSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude)
            textView.minSize = NSSize(width: fixedWidth, height: 50)

            textView.allowsUndo = true
            textView.usesFindPanel = true
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.menu = nil

            textView.delegate = context.coordinator
            if let textContainer = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: textContainer)
            }

            textView.string = viewModel.text
            textView.font = viewModel.selectedFont
            textView.textColor = NSColor.clear

            let cursorColor: NSColor
            if viewMode == .keyline {
                cursorColor = NSColor.black
            } else {
                let baseColor = NSColor(viewModel.textObject.typography.fillColor.color)
                cursorColor = baseColor.withAlphaComponent(viewModel.textObject.typography.fillOpacity)
            }
            textView.insertionPointColor = cursorColor

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = viewModel.textAlignment
            paragraphStyle.lineSpacing = max(0, viewModel.textObject.typography.lineSpacing)
            paragraphStyle.minimumLineHeight = viewModel.textObject.typography.lineHeight
            paragraphStyle.maximumLineHeight = viewModel.textObject.typography.lineHeight
            textView.defaultParagraphStyle = paragraphStyle

            textView.typingAttributes = [
                .font: textView.font ?? viewModel.selectedFont,
                .foregroundColor: NSColor.clear,
                .paragraphStyle: paragraphStyle
            ]

            if textView.string.count > 0 {
                let range = NSRange(location: 0, length: textView.string.count)
                textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            }

            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.handleTextPreviewUpdate(_:)),
                name: Notification.Name("TextPreviewUpdate"),
                object: nil
            )

            context.coordinator.textView = textView
            return textView
        }

        func updateNSView(_ nsView: DisabledContextMenuTextView, context: Context) {
            let coordinator = context.coordinator

            if !isUpdatingFromTyping {
                coordinator.isRestoringSelection = true
                DispatchQueue.main.async {
                    coordinator.isRestoringSelection = false
                }
            }

            let now = Date()
            if isUpdatingFromTyping && now.timeIntervalSince(coordinator.lastUpdateTime) < 0.1 {
                return
            }
            coordinator.lastUpdateTime = now

            if !isUpdatingFromTyping && nsView.string != viewModel.text {
                nsView.string = viewModel.text
            }

            let newFont = viewModel.selectedFont
            var needsFormatUpdate = false

            if nsView.font != newFont {
                nsView.font = newFont

                if nsView.string.count > 0 {
                    let range = NSRange(location: 0, length: nsView.string.count)
                    nsView.textStorage?.addAttribute(.font, value: newFont, range: range)
                    nsView.textStorage?.addAttribute(.foregroundColor, value: NSColor.clear, range: range)

                    if let textContainer = nsView.textContainer {
                        nsView.layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                        nsView.layoutManager?.ensureLayout(for: textContainer)
                    }
                    nsView.needsDisplay = true
                }
                needsFormatUpdate = true
            }

            let currentColor = nsView.textColor ?? NSColor.clear
            if currentColor != NSColor.clear {
                nsView.textColor = NSColor.clear
                needsFormatUpdate = true
            }

            let newCursorColor: NSColor
            if viewMode == .keyline {
                newCursorColor = NSColor.black
            } else {
                let baseColor = NSColor(viewModel.textObject.typography.fillColor.color)
                newCursorColor = baseColor.withAlphaComponent(viewModel.textObject.typography.fillOpacity)
            }
            if nsView.insertionPointColor != newCursorColor {
                nsView.insertionPointColor = newCursorColor
            }

            let newLineSpacing = max(0, viewModel.textObject.typography.lineSpacing)
            let newLineHeight = viewModel.textObject.typography.lineHeight
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = viewModel.textAlignment
            paragraphStyle.lineSpacing = newLineSpacing
            paragraphStyle.minimumLineHeight = newLineHeight
            paragraphStyle.maximumLineHeight = newLineHeight

            DispatchQueue.main.async {
                nsView.defaultParagraphStyle = paragraphStyle
                nsView.typingAttributes = [
                    .font: nsView.font ?? newFont,
                    .foregroundColor: NSColor.clear,
                    .paragraphStyle: paragraphStyle
                ]
            }

            DispatchQueue.main.async {
                guard nsView.string.count > 0 else { return }
                let safeRange = NSRange(location: 0, length: nsView.string.count)

                if let textStorage = nsView.textStorage,
                   safeRange.location >= 0,
                   safeRange.location + safeRange.length <= textStorage.length {
                    textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: safeRange)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: safeRange)

                    if let textContainer = nsView.textContainer {
                        nsView.layoutManager?.ensureLayout(for: textContainer)
                    }
                    nsView.needsDisplay = true
                }
            }

            needsFormatUpdate = true

            let currentContainerWidth = nsView.textContainer?.containerSize.width ?? 0
            let newWidth = viewModel.textObject.areaSize?.width ?? viewModel.textObject.bounds.width
            let newHeight = viewModel.textObject.areaSize?.height ?? viewModel.textObject.bounds.height

            if abs(currentContainerWidth - newWidth) > 1.0 {
                nsView.textContainer?.containerSize = NSSize(width: newWidth, height: CGFloat.greatestFiniteMagnitude)
                nsView.frame = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
                nsView.maxSize = NSSize(width: newWidth, height: CGFloat.greatestFiniteMagnitude)
                nsView.minSize = NSSize(width: newWidth, height: 50)

                if let textContainer = nsView.textContainer {
                    nsView.layoutManager?.ensureLayout(for: textContainer)
                }
            }

            nsView.isEditable = true
            nsView.isSelectable = true

            let isEditingMode = (textBoxState == .blue)
            nsView.allowsInteraction = isEditingMode
            nsView.shouldShowCursor = isEditingMode

            if !isEditingMode {
                nsView.insertionPointColor = NSColor.clear
            } else {
                let textColor: NSColor
                if viewMode == .keyline {
                    textColor = NSColor.black
                } else {
                    let baseColor = NSColor(viewModel.textObject.typography.fillColor.color)
                    textColor = baseColor.withAlphaComponent(viewModel.textObject.typography.fillOpacity)
                }
                nsView.insertionPointColor = textColor

                DispatchQueue.main.async {
                    if nsView.window?.firstResponder != nsView {
                        nsView.window?.makeFirstResponder(nsView)
                    }
                }
            }

            nsView.textContainerInset = NSSize(width: 0, height: 0)
            nsView.textContainer?.lineFragmentPadding = 0

            if needsFormatUpdate && nsView.window?.firstResponder == nsView {
                DispatchQueue.main.async {
                    nsView.setNeedsDisplay(nsView.visibleRect)
                }
            }

            coordinator.textView = nsView
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, NSTextViewDelegate {
            var parent: TextViewRepresentable
            var lastUpdateTime: Date = Date()
            var isRestoringSelection: Bool = false
            weak var textView: DisabledContextMenuTextView?

            init(_ parent: TextViewRepresentable) {
                self.parent = parent
                super.init()
            }

            func textDidChange(_ notification: Notification) {
                guard let textView = notification.object as? NSTextView else { return }
                guard textView.isEditable else { return }

                let newText = textView.string
                guard newText != parent.viewModel.text else { return }

                parent.isUpdatingFromTyping = true

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.parent.viewModel.text = newText
                    self.parent.viewModel.updateLastTypingTime()
                    self.parent.viewModel.document.updateTextContent(
                        self.parent.viewModel.textObject.id,
                        content: newText
                    )
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.parent.isUpdatingFromTyping = false
                }
            }

            func textViewDidChangeSelection(_ notification: Notification) {
                guard !isRestoringSelection else { return }
                guard let textView = notification.object as? NSTextView else { return }
                let selectedRange = textView.selectedRange()

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let oldPosition = self.parent.viewModel.userInitiatedCursorPosition
                    let newPosition = selectedRange.location

                    if newPosition == oldPosition - 1 {
                        self.isRestoringSelection = true
                        textView.setSelectedRange(NSRange(location: oldPosition, length: 0))
                        self.isRestoringSelection = false
                        return
                    }

                    self.parent.viewModel.userInitiatedCursorPosition = selectedRange.location
                }
            }

            func textDidEndEditing(_ notification: Notification) {
                let finalText = parent.viewModel.text
                let textFrame = parent.viewModel.textBoxFrame
                let textObjectId = parent.viewModel.textObject.id

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.parent.viewModel.document.updateTextContent(textObjectId, content: finalText)
                    self.parent.viewModel.updateDocumentTextBounds(textFrame)
                    self.parent.isUpdatingFromTyping = false
                }
            }

            @objc func handleTextPreviewUpdate(_ notification: Notification) {
                guard let userInfo = notification.userInfo,
                      let textID = userInfo["textID"] as? UUID,
                      let typography = userInfo["typography"] as? TypographyProperties,
                      parent.viewModel.textObject.id == textID else { return }

                guard let textView = self.textView else { return }

                DispatchQueue.main.async {
                    let newFont = typography.nsFont
                    if textView.font != newFont {
                        textView.font = newFont
                    }

                    textView.textColor = NSColor.clear

                    let cursorColor: NSColor
                    if self.parent.viewMode == .keyline {
                        cursorColor = NSColor.black
                    } else {
                        let baseColor = NSColor(typography.fillColor.color)
                        cursorColor = baseColor.withAlphaComponent(typography.fillOpacity)
                    }
                    textView.insertionPointColor = cursorColor

                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = typography.alignment.nsTextAlignment
                    paragraphStyle.lineSpacing = max(0, typography.lineSpacing)
                    paragraphStyle.minimumLineHeight = typography.lineHeight
                    paragraphStyle.maximumLineHeight = typography.lineHeight

                    textView.defaultParagraphStyle = paragraphStyle
                    textView.typingAttributes = [
                        .font: newFont,
                        .foregroundColor: NSColor.clear,
                        .paragraphStyle: paragraphStyle
                    ]

                    if textView.string.count > 0 {
                        let range = NSRange(location: 0, length: textView.string.count)
                        textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                        textView.textStorage?.addAttribute(.font, value: newFont, range: range)
                        textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
                    }

                    if let textContainer = textView.textContainer {
                        textView.layoutManager?.ensureLayout(for: textContainer)
                    }
                    textView.needsDisplay = true
                }
            }
        }
    }
}
