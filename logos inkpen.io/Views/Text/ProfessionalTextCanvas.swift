import SwiftUI
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
    let letterSpacingDelta: Double?
    let lineHeightDelta: Double?
    let fontSizeDelta: Double?
    let lineSpacingDelta: Double?

    init(document: VectorDocument, textObjectID: UUID, zoomLevel: Double, canvasOffset: CGPoint, dragPreviewDelta: CGPoint = .zero, dragPreviewTrigger: Bool = false, viewMode: ViewMode = .color, letterSpacingDelta: Double? = nil, lineHeightDelta: Double? = nil, fontSizeDelta: Double? = nil, lineSpacingDelta: Double? = nil) {
        self.document = document
        self.textObjectID = textObjectID
        self.zoomLevel = zoomLevel
        self.canvasOffset = canvasOffset
        self.dragPreviewDelta = dragPreviewDelta
        self.dragPreviewTrigger = dragPreviewTrigger
        self.viewMode = viewMode
        self.letterSpacingDelta = letterSpacingDelta
        self.lineHeightDelta = lineHeightDelta
        self.fontSizeDelta = fontSizeDelta
        self.lineSpacingDelta = lineSpacingDelta

        let actualText = document.findText(by: textObjectID) ?? VectorText(content: "", typography: TypographyProperties(strokeColor: .black, fillColor: .black))
        self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: actualText, document: document))
    }

    var body: some View {
        // Read from document directly, not viewModel
        let textObject = document.findText(by: textObjectID) ?? viewModel.textObject
        let bounds = textObject.bounds
        let position = textObject.position

        // SECRET FORMULA: Apply deltas with proportional line height
        let fontSize = fontSizeDelta ?? textObject.typography.fontSize

        // Line height: explicit delta overrides proportional (ternary to avoid control flow in body)
        let lineHeight = lineHeightDelta != nil
            ? CGFloat(lineHeightDelta!)
            : (fontSizeDelta != nil
                ? (CGFloat(fontSizeDelta!) * (textObject.typography.lineHeight / textObject.typography.fontSize))
                : textObject.typography.lineHeight)

        let letterSpacing = letterSpacingDelta ?? textObject.typography.letterSpacing
        let lineSpacing = lineSpacingDelta ?? textObject.typography.lineSpacing

        // Read font directly from document, not viewModel!
        let fontFamily = textObject.typography.fontFamily
        let fontVariant = textObject.typography.fontVariant

        return TextViewRepresentable(
            viewModel: viewModel,
            viewMode: viewMode,
            letterSpacing: letterSpacing,
            lineHeight: lineHeight,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            fontFamily: fontFamily,
            fontVariant: fontVariant
        )
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
        .position(x: position.x + bounds.width / 2, y: position.y + bounds.height / 2)
        .scaleEffect(zoomLevel, anchor: .topLeading)
        .offset(x: canvasOffset.x, y: canvasOffset.y)
        .offset(x: shouldApplyDragPreview() ? dragPreviewDelta.x * zoomLevel : 0,
                y: shouldApplyDragPreview() ? dragPreviewDelta.y * zoomLevel : 0)
        .id(dragPreviewTrigger)
        .onKeyPress(action: handleKeyPress)
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
        let letterSpacing: CGFloat  // Direct value, not from @ObservedObject
        let lineHeight: CGFloat
        let fontSize: CGFloat
        let lineSpacing: CGFloat
        let fontFamily: String
        let fontVariant: String?

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
            // Use SAME font logic as CTLine rendering
            let liveFont: NSFont = {
                if let variant = fontVariant {
                    let fontManager = NSFontManager.shared
                    let members = fontManager.availableMembers(ofFontFamily: fontFamily) ?? []

                    for member in members {
                        if let postScriptName = member[0] as? String,
                           let displayName = member[1] as? String,
                           displayName == variant {
                            if let font = NSFont(name: postScriptName, size: fontSize) {
                                return font
                            }
                        }
                    }
                }

                return NSFont(name: fontFamily, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
            }()
            textView.font = liveFont
            textView.textColor = NSColor.systemPink  // DEBUG: Change to .clear to hide NSTextView
            textView.allowsInteraction = true
            textView.shouldShowCursor = true

            // Set text first
            textView.string = viewModel.text

            // Now apply letter spacing to all text
            if !viewModel.text.isEmpty {
                let range = NSRange(location: 0, length: viewModel.text.count)
                textView.textStorage?.beginEditing()
                textView.textStorage?.addAttribute(.kern, value: letterSpacing, range: range)
                textView.textStorage?.endEditing()

                // Invalidate layout to force redraw with kern attribute
                textView.layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            }

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


            // Always apply font (comparing NSFont objects doesn't work reliably)
            // Use SAME font logic as CTLine rendering
            let liveFont: NSFont = {
                if let variant = fontVariant {
                    let fontManager = NSFontManager.shared
                    let members = fontManager.availableMembers(ofFontFamily: fontFamily) ?? []

                    for member in members {
                        if let postScriptName = member[0] as? String,
                           let displayName = member[1] as? String,
                           displayName == variant {
                            if let font = NSFont(name: postScriptName, size: fontSize) {
                                return font
                            }
                        }
                    }
                }

                return NSFont(name: fontFamily, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
            }()
            nsView.font = liveFont
            if nsView.string.count > 0 {
                let range = NSRange(location: 0, length: nsView.string.count)
                nsView.textStorage?.beginEditing()
                nsView.textStorage?.addAttribute(.font, value: liveFont, range: range)
                nsView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemPink, range: range)  // DEBUG: Change to .clear
                nsView.textStorage?.addAttribute(.kern, value: letterSpacing, range: range)
                nsView.textStorage?.endEditing()

                if let textContainer = nsView.textContainer {
                    nsView.layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                    nsView.layoutManager?.ensureLayout(for: textContainer)
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
            paragraphStyle.lineSpacing = max(0, lineSpacing)
            paragraphStyle.minimumLineHeight = lineHeight
            paragraphStyle.maximumLineHeight = lineHeight
            textView.defaultParagraphStyle = paragraphStyle

            // Use SAME font logic as CTLine rendering
            let liveFont: NSFont = {
                if let variant = fontVariant {
                    let fontManager = NSFontManager.shared
                    let members = fontManager.availableMembers(ofFontFamily: fontFamily) ?? []

                    for member in members {
                        if let postScriptName = member[0] as? String,
                           let displayName = member[1] as? String,
                           displayName == variant {
                            if let font = NSFont(name: postScriptName, size: fontSize) {
                                return font
                            }
                        }
                    }
                }

                return NSFont(name: fontFamily, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
            }()
            textView.typingAttributes = [
                .font: textView.font ?? liveFont,
                .foregroundColor: NSColor.systemPink,  // DEBUG: Change to .clear to hide NSTextView
                .paragraphStyle: paragraphStyle,
                .kern: letterSpacing
            ]

            if textView.string.count > 0 {
                let range = NSRange(location: 0, length: textView.string.count)
                textView.textStorage?.beginEditing()
                textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemPink, range: range)  // DEBUG: Change to .clear
                textView.textStorage?.addAttribute(.kern, value: letterSpacing, range: range)
                textView.textStorage?.endEditing()

                // Force immediate layout update
                if let textContainer = textView.textContainer {
                    textView.layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                    textView.layoutManager?.ensureLayout(for: textContainer)
                }
            }

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
