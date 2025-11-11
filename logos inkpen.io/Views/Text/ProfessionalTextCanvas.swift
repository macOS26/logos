import SwiftUI
import Combine
import AppKit

struct ProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    @StateObject private var viewModel: ProfessionalTextViewModel
    let textObjectID: UUID
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let viewMode: ViewMode

    init(document: VectorDocument, textObjectID: UUID, zoomLevel: Double, canvasOffset: CGPoint, dragPreviewDelta: CGPoint = .zero, dragPreviewTrigger: Bool = false, viewMode: ViewMode = .color) {
        self.document = document
        self.textObjectID = textObjectID
        self.zoomLevel = zoomLevel
        self.canvasOffset = canvasOffset
        self.dragPreviewDelta = dragPreviewDelta
        self.dragPreviewTrigger = dragPreviewTrigger
        self.viewMode = viewMode

        let actualText = document.findText(by: textObjectID) ?? VectorText(content: "", typography: TypographyProperties(strokeColor: .black, fillColor: .black))
        self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: actualText, document: document))
    }

    var body: some View {
        let bounds = viewModel.textObject.bounds
        let position = viewModel.textObject.position

        TextViewRepresentable(
            viewModel: viewModel,
            viewMode: viewMode
        )
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
        .position(x: position.x + bounds.width / 2, y: position.y + bounds.height / 2)
        .scaleEffect(zoomLevel, anchor: .topLeading)
        .offset(x: canvasOffset.x, y: canvasOffset.y)
        .offset(x: shouldApplyDragPreview() ? dragPreviewDelta.x * zoomLevel : 0,
                y: shouldApplyDragPreview() ? dragPreviewDelta.y * zoomLevel : 0)
        .id(dragPreviewTrigger)
        .onKeyPress(action: handleKeyPress)
        .onAppear {
            if let currentTextObject = document.findText(by: textObjectID) {
                viewModel.syncFromDocument(currentTextObject)
            }
        }
        .onReceive(document.objectWillChange) { _ in
            if let currentTextObject = document.findText(by: textObjectID) {
                viewModel.syncFromDocument(currentTextObject)
            }
        }
        .onChange(of: viewModel.textObject.isEditing) { _, newValue in
            viewModel.isEditing = newValue
        }
    }

    private func shouldApplyDragPreview() -> Bool {
        if document.viewState.selectedObjectIDs.contains(textObjectID) {
            return true
        }

        for selectedID in document.viewState.selectedObjectIDs {
            if let selectedObject = document.findObject(by: selectedID) {
                switch selectedObject.objectType {
                case .group(let selectedShape), .clipGroup(let selectedShape):
                    if selectedShape.isGroupContainer && selectedShape.groupedShapes.contains(where: { $0.id == textObjectID }) {
                        return true
                    }
                default:
                    continue
                }
            }
        }

        return false
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard viewModel.isEditing && keyPress.key == .escape else { return .ignored }

        viewModel.document.updateTextContent(viewModel.textObject.id, content: viewModel.text)
        viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
        viewModel.stopEditing()
        document.setTextEditingInUnified(id: viewModel.textObject.id, isEditing: false)
        NSApp.keyWindow?.makeFirstResponder(nil)

        return .handled
    }

    // MARK: - NSViewRepresentable

    struct TextViewRepresentable: NSViewRepresentable {
        @ObservedObject var viewModel: ProfessionalTextViewModel
        @State var isUpdatingFromTyping: Bool = false
        let viewMode: ViewMode

        func makeNSView(context: Context) -> DisabledContextMenuTextView {
            let textView = DisabledContextMenuTextView()
            let width = viewModel.textObject.areaSize?.width ?? viewModel.textObject.bounds.width
            let height = viewModel.textObject.areaSize?.height ?? viewModel.textObject.bounds.height

            textView.isEditable = true
            textView.isSelectable = true
            textView.backgroundColor = NSColor.clear
            textView.textContainerInset = NSSize(width: 0, height: 0)
            textView.textContainer?.lineFragmentPadding = 0
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.heightTracksTextView = false
            textView.isVerticallyResizable = false
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = []
            textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.lineBreakMode = .byWordWrapping
            textView.frame = CGRect(x: 0, y: 0, width: width, height: height)
            textView.maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.minSize = NSSize(width: width, height: 50)
            textView.allowsUndo = true
            textView.usesFindPanel = true
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.menu = nil
            textView.delegate = context.coordinator
            textView.font = viewModel.selectedFont
            textView.textColor = NSColor.systemPink
            textView.allowsInteraction = true
            textView.shouldShowCursor = true

            // Apply text with letter spacing via attributed string
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = viewModel.textAlignment
            paragraphStyle.lineSpacing = max(0, viewModel.textObject.typography.lineSpacing)
            paragraphStyle.minimumLineHeight = viewModel.textObject.typography.lineHeight
            paragraphStyle.maximumLineHeight = viewModel.textObject.typography.lineHeight

            let attributes: [NSAttributedString.Key: Any] = [
                .font: viewModel.selectedFont,
                .foregroundColor: NSColor.systemPink,
                .paragraphStyle: paragraphStyle,
                .kern: viewModel.textObject.typography.letterSpacing
            ]

            let attributedString = NSAttributedString(string: viewModel.text, attributes: attributes)
            textView.textStorage?.setAttributedString(attributedString)

            context.coordinator.textView = textView

            // Set initial cursor position from textObject
            let initialCursorPosition = viewModel.textObject.cursorPosition
            let validPosition = min(max(0, initialCursorPosition), textView.string.count)
            textView.setSelectedRange(NSRange(location: validPosition, length: 0))

            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }

            return textView
        }

        func updateNSView(_ nsView: DisabledContextMenuTextView, context: Context) {
            let coordinator = context.coordinator

            if !isUpdatingFromTyping {
                coordinator.isRestoringSelection = true
                DispatchQueue.main.async { coordinator.isRestoringSelection = false }
            }

            let now = Date()
            if isUpdatingFromTyping && now.timeIntervalSince(coordinator.lastUpdateTime) < 0.1 {
                return
            }
            coordinator.lastUpdateTime = now

            if !isUpdatingFromTyping && nsView.string != viewModel.text {
                nsView.string = viewModel.text
            }

            if nsView.font != viewModel.selectedFont {
                nsView.font = viewModel.selectedFont
                if nsView.string.count > 0 {
                    let range = NSRange(location: 0, length: nsView.string.count)
                    nsView.textStorage?.addAttribute(.font, value: viewModel.selectedFont, range: range)
                    nsView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemPink, range: range)
                    nsView.textStorage?.addAttribute(.kern, value: viewModel.textObject.typography.letterSpacing, range: range)
                    if let textContainer = nsView.textContainer {
                        nsView.layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                        nsView.layoutManager?.ensureLayout(for: textContainer)
                    }
                }
            }

            let width = viewModel.textObject.areaSize?.width ?? viewModel.textObject.bounds.width
            let height = viewModel.textObject.areaSize?.height ?? viewModel.textObject.bounds.height
            let currentWidth = nsView.textContainer?.containerSize.width ?? 0

            if abs(currentWidth - width) > 1.0 {
                nsView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
                nsView.frame = CGRect(x: 0, y: 0, width: width, height: height)
                nsView.maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
                nsView.minSize = NSSize(width: width, height: 50)
                nsView.textContainer.flatMap { nsView.layoutManager?.ensureLayout(for: $0) }
            }

            applyStyle(to: nsView)

            DispatchQueue.main.async {
                if nsView.window?.firstResponder != nsView {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        }

        private func applyStyle(to textView: NSTextView) {
            let cursorColor: NSColor = if viewMode == .keyline {
                NSColor.black
            } else {
                NSColor(viewModel.textObject.typography.fillColor.color)
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
                .foregroundColor: NSColor.systemPink,
                .paragraphStyle: paragraphStyle,
                .kern: viewModel.textObject.typography.letterSpacing
            ]

            if textView.string.count > 0 {
                let range = NSRange(location: 0, length: textView.string.count)
                textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemPink, range: range)
                textView.textStorage?.addAttribute(.kern, value: viewModel.textObject.typography.letterSpacing, range: range)
            }

            textView.textContainer.flatMap { textView.layoutManager?.ensureLayout(for: $0) }
            textView.needsDisplay = true
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
            }

            func textDidChange(_ notification: Notification) {
                guard let textView = notification.object as? NSTextView, textView.isEditable else { return }
                let newText = textView.string
                guard newText != parent.viewModel.text else { return }

                parent.isUpdatingFromTyping = true

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.parent.viewModel.text = newText
                    self.parent.viewModel.updateLastTypingTime()
                    self.parent.viewModel.document.updateTextContent(self.parent.viewModel.textObject.id, content: newText)
                    // Disable -1 workaround after first typing
                    self.parent.viewModel.document.viewState.shouldApplyCursorWorkaround = false
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.parent.isUpdatingFromTyping = false
                }
            }

            func textViewDidChangeSelection(_ notification: Notification) {
                guard !isRestoringSelection, let textView = notification.object as? NSTextView else { return }
                let selectedRange = textView.selectedRange()

                // Update typing attributes to include kern at current cursor position
                if textView.string.count > 0, selectedRange.location > 0 {
                    let location = min(selectedRange.location - 1, textView.string.count - 1)
                    if let attrs = textView.textStorage?.attributes(at: location, effectiveRange: nil) {
                        textView.typingAttributes = attrs
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let oldPosition = self.parent.viewModel.userInitiatedCursorPosition
                    let newPosition = selectedRange.location

                    // Only apply -1 workaround when transitioning from Arrow to Font tool via double-click
                    if self.parent.viewModel.document.viewState.shouldApplyCursorWorkaround && newPosition == oldPosition - 1 {
                        self.isRestoringSelection = true
                        textView.setSelectedRange(NSRange(location: oldPosition, length: 0))
                        self.isRestoringSelection = false
                        self.parent.viewModel.document.viewState.shouldApplyCursorWorkaround = false
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
        }
    }
}
