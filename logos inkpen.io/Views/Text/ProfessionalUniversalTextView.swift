import SwiftUI
import AppKit

struct ProfessionalUniversalTextView: NSViewRepresentable {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    @State var isUpdatingFromTyping: Bool = false
    let textBoxState: ProfessionalTextCanvas.TextBoxState
    let viewMode: ViewMode

    init(viewModel: ProfessionalTextViewModel, textBoxState: ProfessionalTextCanvas.TextBoxState = .gray, viewMode: ViewMode = .color) {
        self.viewModel = viewModel
        self.textBoxState = textBoxState
        self.viewMode = viewMode
    }

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

        // Auto-focus the text view if in editing mode
        if isEditingMode {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }

        textView.wantsLayer = true
        textView.layer?.masksToBounds = false

        let fixedWidth = viewModel.textBoxFrame.width
        let fixedHeight = viewModel.textBoxFrame.height

        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = []

        textView.textContainer?.containerSize = NSSize(
            width: fixedWidth,
            height: CGFloat.greatestFiniteMagnitude
        )

        textView.frame = CGRect(
            x: 0, y: 0,
            width: fixedWidth,
            height: fixedHeight
        )

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

        let textColor: NSColor
        if viewMode == .keyline {
            textColor = NSColor.black
        } else {
            let baseColor = NSColor(viewModel.textObject.typography.fillColor.color)
            textColor = baseColor.withAlphaComponent(viewModel.textObject.typography.fillOpacity)
        }
        textView.textColor = textColor
        textView.insertionPointColor = textColor

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = viewModel.textAlignment
        paragraphStyle.lineSpacing = max(0, viewModel.textObject.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = viewModel.textObject.typography.lineHeight
        paragraphStyle.maximumLineHeight = viewModel.textObject.typography.lineHeight
        textView.defaultParagraphStyle = paragraphStyle

        // Set typing attributes to ensure new text uses the correct alignment
        textView.typingAttributes = [
            .font: textView.font ?? viewModel.selectedFont,
            .foregroundColor: textColor,
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

            // Update font in text storage for existing text
            if nsView.string.count > 0 {
                let range = NSRange(location: 0, length: nsView.string.count)
                nsView.textStorage?.addAttribute(.font, value: newFont, range: range)

                // Force layout and display update
                if let textContainer = nsView.textContainer {
                    nsView.layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                    nsView.layoutManager?.ensureLayout(for: textContainer)
                }
                nsView.needsDisplay = true
            }
            needsFormatUpdate = true
        }

        let newTextColor: NSColor
        if viewMode == .keyline {
            newTextColor = NSColor.black
        } else {
            let baseColor = NSColor(viewModel.textObject.typography.fillColor.color)
            newTextColor = baseColor.withAlphaComponent(viewModel.textObject.typography.fillOpacity)
        }
        let currentColor = nsView.textColor ?? NSColor.black

        if currentColor != newTextColor {
            nsView.textColor = newTextColor
            nsView.insertionPointColor = newTextColor
            needsFormatUpdate = true
        }

        let newAlignment = viewModel.textAlignment
        let newLineSpacing = max(0, viewModel.textObject.typography.lineSpacing)
        let newLineHeight = viewModel.textObject.typography.lineHeight
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = newAlignment
        paragraphStyle.lineSpacing = newLineSpacing
        paragraphStyle.minimumLineHeight = newLineHeight
        paragraphStyle.maximumLineHeight = newLineHeight

        DispatchQueue.main.async {
            nsView.defaultParagraphStyle = paragraphStyle

            // Update typing attributes to ensure new text uses the correct alignment
            nsView.typingAttributes = [
                .font: nsView.font ?? newFont,
                .foregroundColor: newTextColor,
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

                if let textContainer = nsView.textContainer {
                    nsView.layoutManager?.ensureLayout(for: textContainer)
                }
                nsView.needsDisplay = true
            }
        }

        needsFormatUpdate = true

        let currentContainerWidth = nsView.textContainer?.containerSize.width ?? 0
        let newWidth = viewModel.textBoxFrame.width
        let newHeight = viewModel.textBoxFrame.height

        if abs(currentContainerWidth - newWidth) > 1.0 {

            nsView.textContainer?.containerSize = NSSize(
                width: newWidth,
                height: CGFloat.greatestFiniteMagnitude
            )

            nsView.frame = CGRect(
                x: 0, y: 0,
                width: newWidth,
                height: newHeight
            )

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

            // Auto-focus the text view when entering editing mode
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

        let safeWidth = viewModel.textBoxFrame.width
        let safeHeight = viewModel.textBoxFrame.height
        let newFrame = CGRect(
            x: 0, y: 0,
            width: safeWidth,
            height: safeHeight
        )
        let newMaxSize = NSSize(width: safeWidth, height: CGFloat.greatestFiniteMagnitude)
        let newMinSize = NSSize(width: safeWidth, height: 30)

        if nsView.frame != newFrame {
            nsView.frame = newFrame
        }

        if nsView.maxSize != newMaxSize {
            nsView.maxSize = newMaxSize
        }

        if nsView.minSize != newMinSize {
            nsView.minSize = newMinSize
        }

        if needsFormatUpdate || abs(currentContainerWidth - newWidth) > 1.0 {
            nsView.needsLayout = true
        }

        coordinator.textView = nsView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ProfessionalUniversalTextView
        var lastUpdateTime: Date = Date()
        var isRestoringSelection: Bool = false
        weak var textView: DisabledContextMenuTextView?

        init(_ parent: ProfessionalUniversalTextView) {
            self.parent = parent
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            guard textView.isEditable else {
                return
            }

            let newText = textView.string

            guard newText != parent.viewModel.text else {
                return
            }

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
            guard !isRestoringSelection else {
                return
            }
            guard let textView = notification.object as? NSTextView else { return }
            let selectedRange = textView.selectedRange()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.viewModel.userInitiatedCursorPosition = selectedRange.location
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
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

                let textColor: NSColor
                if self.parent.viewMode == .keyline {
                    textColor = NSColor.black
                } else {
                    let baseColor = NSColor(typography.fillColor.color)
                    textColor = baseColor.withAlphaComponent(typography.fillOpacity)
                }
                textView.textColor = textColor
                textView.insertionPointColor = textColor

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = typography.alignment.nsTextAlignment
                paragraphStyle.lineSpacing = max(0, typography.lineSpacing)
                paragraphStyle.minimumLineHeight = typography.lineHeight
                paragraphStyle.maximumLineHeight = typography.lineHeight

                textView.defaultParagraphStyle = paragraphStyle

                // Update typing attributes to ensure new text uses the correct alignment
                textView.typingAttributes = [
                    .font: newFont,
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle
                ]

                if textView.string.count > 0 {
                    let range = NSRange(location: 0, length: textView.string.count)
                    textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                    textView.textStorage?.addAttribute(.font, value: newFont, range: range)
                }

                if let textContainer = textView.textContainer {
                    textView.layoutManager?.ensureLayout(for: textContainer)
                }
                textView.needsDisplay = true
            }
        }
    }
}
