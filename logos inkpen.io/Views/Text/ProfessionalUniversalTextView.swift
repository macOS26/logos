//
//  ProfessionalUniversalTextView.swift
//  logos inkpen.io
//
//  NSViewRepresentable for text editing with NSTextView
//

import SwiftUI
import AppKit

// MARK: - Professional Universal Text View (Based on Working UniversalTextView)
struct ProfessionalUniversalTextView: NSViewRepresentable {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    @State var isUpdatingFromTyping: Bool = false  // Prevents NSTextView reset during typing
    let textBoxState: ProfessionalTextCanvas.TextBoxState  // Pass text box state to control editability

    init(viewModel: ProfessionalTextViewModel, textBoxState: ProfessionalTextCanvas.TextBoxState = .gray) {
        self.viewModel = viewModel
        self.textBoxState = textBoxState
    }
    
    func makeNSView(context: Context) -> DisabledContextMenuTextView {
        let textView = DisabledContextMenuTextView()

        // CRITICAL: Keep NSTextView COMPLETELY STATIC to prevent ANY layout shifts
        // Always editable, always selectable, always the same
        textView.isEditable = true
        textView.isSelectable = true

        // Control ONLY visual feedback, not actual state
        let isEditingMode = (textBoxState == .blue)
        textView.allowsInteraction = isEditingMode
        textView.shouldShowCursor = isEditingMode
        textView.backgroundColor = NSColor.clear
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        
                // CRITICAL: Configure for FIXED WIDTH, VERTICAL EXPANSION ONLY
        // CRITICAL FIX: Always preserve exact text box dimensions (no minimum size restrictions)
        let fixedWidth = viewModel.textBoxFrame.width
        let fixedHeight = viewModel.textBoxFrame.height
        
        textView.textContainer?.widthTracksTextView = false  
        textView.textContainer?.heightTracksTextView = false 
        textView.isVerticallyResizable = false    
        textView.isHorizontallyResizable = false  
        textView.autoresizingMask = []           
        
        // CRITICAL: Fixed container width for text wrapping
        textView.textContainer?.containerSize = NSSize(
            width: fixedWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        // CRITICAL: Fixed frame width
        textView.frame = CGRect(
            x: 0, y: 0,
            width: fixedWidth,
            height: fixedHeight
        )
        
        // CRITICAL: Force word wrapping at fixed width
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.maxSize = NSSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: fixedWidth, height: 50)
        
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        // Disable system contextual menu for this NSTextView
        textView.menu = nil
        
        textView.delegate = context.coordinator  // CRITICAL: Set delegate to capture text changes
        if let textContainer = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: textContainer)
        }
        
        // CRITICAL FIX: Set initial text and appearance directly on NSTextView
        textView.string = viewModel.text
        textView.font = viewModel.selectedFont
        
        // FIXED: Use proper color conversion with opacity applied
        let baseColor = NSColor(viewModel.textObject.typography.fillColor.color)
        let textColor = baseColor.withAlphaComponent(viewModel.textObject.typography.fillOpacity)
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        
        // Set initial paragraph style for line height and spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = viewModel.textAlignment
        paragraphStyle.lineSpacing = max(0, viewModel.textObject.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = viewModel.textObject.typography.lineHeight
        paragraphStyle.maximumLineHeight = viewModel.textObject.typography.lineHeight
        textView.defaultParagraphStyle = paragraphStyle

        // DON'T make first responder on init - let the mode control it later

        // CRITICAL FIX: Apply paragraph style to existing text immediately
        if textView.string.count > 0 {
            let range = NSRange(location: 0, length: textView.string.count)
            textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }
        
        // First responder will be set in updateNSView when needed

        // Listen for live preview updates
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleTextPreviewUpdate(_:)),
            name: Notification.Name("TextPreviewUpdate"),
            object: nil
        )
        
        // Store the text view reference in the coordinator for direct access
        context.coordinator.textView = textView

        return textView
    }
    

    
    func updateNSView(_ nsView: DisabledContextMenuTextView, context: Context) {
        let coordinator = context.coordinator
        
        // CRITICAL FIX: Always preserve exact text box dimensions without size restrictions

        // CRITICAL: Lock the coordinator during non-typing updates to prevent saving programmatic selection changes.
        if !isUpdatingFromTyping {
            coordinator.isRestoringSelection = true
            // Use async to release the lock after the current runloop cycle,
            // ensuring all programmatic selection changes have settled.
            DispatchQueue.main.async {
                coordinator.isRestoringSelection = false
            }
        }

        // PERFORMANCE OPTIMIZATION: Track what actually changed to avoid expensive updates during typing
        
        // PERFORMANCE OPTIMIZATION: Skip rapid updates during active typing (< 100ms apart)
        let now = Date()
        if isUpdatingFromTyping && now.timeIntervalSince(coordinator.lastUpdateTime) < 0.1 {
            return // Skip this update - too frequent during typing
        }
        coordinator.lastUpdateTime = now
        
        // CRITICAL FIX: Only update NSTextView text when NOT actively typing
        // This prevents cursor jumping and text resets during typing
        if !isUpdatingFromTyping && nsView.string != viewModel.text {
            nsView.string = viewModel.text
        }
        
        // PERFORMANCE: Only update font/color if they actually changed (avoid expensive operations during typing)
        let newFont = viewModel.selectedFont
        
        var needsFormatUpdate = false
        
        if nsView.font != newFont {
            DispatchQueue.main.async {
                nsView.font = newFont
            }
            needsFormatUpdate = true
        }
        
        // FIXED: Proper color handling with opacity
        let baseColor = NSColor(viewModel.textObject.typography.fillColor.color)
        let newTextColor = baseColor.withAlphaComponent(viewModel.textObject.typography.fillOpacity)
        let currentColor = nsView.textColor ?? NSColor.black

        // Simple color comparison - check if colors are different (including opacity)
        if currentColor != newTextColor {
            nsView.textColor = newTextColor
            nsView.insertionPointColor = newTextColor
            needsFormatUpdate = true
        }
        
        // CRITICAL FIX: ALWAYS update paragraph style consistently regardless of editing state
        let newAlignment = viewModel.textAlignment
        let newLineSpacing = max(0, viewModel.textObject.typography.lineSpacing)
        let newLineHeight = viewModel.textObject.typography.lineHeight

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = newAlignment
        paragraphStyle.lineSpacing = newLineSpacing
        paragraphStyle.minimumLineHeight = newLineHeight
        paragraphStyle.maximumLineHeight = newLineHeight

        // CRITICAL: Set default style first for new text
        DispatchQueue.main.async {
            nsView.defaultParagraphStyle = paragraphStyle
        }

        // CRITICAL: Always apply paragraph style to ALL existing text
        // This ensures consistent rendering between editing and non-editing states
        if nsView.string.count > 0 {
            let range = NSRange(location: 0, length: nsView.string.count)
            DispatchQueue.main.async {
                nsView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                // Force immediate layout update for consistent display
                if let textContainer = nsView.textContainer {
                    nsView.layoutManager?.ensureLayout(for: textContainer)
                }
                nsView.needsDisplay = true
            }
        }

        needsFormatUpdate = true
        
        // CRITICAL FIX: Update text container width when text box is resized
        let currentContainerWidth = nsView.textContainer?.containerSize.width ?? 0
        // CRITICAL FIX: Always preserve exact text box dimensions (no minimum size restrictions)
        let newWidth = viewModel.textBoxFrame.width
        let newHeight = viewModel.textBoxFrame.height
        
        if abs(currentContainerWidth - newWidth) > 1.0 { // Only update if significantly different
            
            // Update text container size for proper text reflow
            nsView.textContainer?.containerSize = NSSize(
                width: newWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
            
            // Update frame to match new width
            nsView.frame = CGRect(
                x: 0, y: 0,
                width: newWidth,
                height: newHeight
            )
            
            // Update max/min sizes
            nsView.maxSize = NSSize(width: newWidth, height: CGFloat.greatestFiniteMagnitude)
            nsView.minSize = NSSize(width: newWidth, height: 50)
            
            // Force layout refresh for immediate text reflow
            if let textContainer = nsView.textContainer {
                nsView.layoutManager?.ensureLayout(for: textContainer)
            }
            
        }
        
        // CRITICAL: Keep NSTextView COMPLETELY STATIC to prevent ANY layout shifts
        // Do NOT change any properties that could affect layout
        nsView.isEditable = true
        nsView.isSelectable = true

        // Control ONLY visual feedback, not actual state
        let isEditingMode = (textBoxState == .blue)
        nsView.allowsInteraction = isEditingMode
        nsView.shouldShowCursor = isEditingMode

        // Update insertion point color to be transparent when not editing
        // This keeps cursor space but makes it invisible
        if !isEditingMode {
            nsView.insertionPointColor = NSColor.clear
        } else {
            // Restore normal cursor color when editing
            let baseColor = NSColor(viewModel.textObject.typography.fillColor.color)
            let textColor = baseColor.withAlphaComponent(viewModel.textObject.typography.fillOpacity)
            nsView.insertionPointColor = textColor
        }


        // DON'T force frame - let SwiftUI handle positioning
        // Just ensure we're not changing first responder status which affects layout

        // CRITICAL: Keep text view state EXACTLY THE SAME in all modes
        // Don't change first responder - it causes layout shifts
        nsView.textContainerInset = NSSize(width: 0, height: 0)
        nsView.textContainer?.lineFragmentPadding = 0
        
        // PERFORMANCE: Only force display update if format changed and view is first responder
        if needsFormatUpdate && nsView.window?.firstResponder == nsView {
            DispatchQueue.main.async {
                nsView.setNeedsDisplay(nsView.visibleRect)
            }
        }
        
        // PERFORMANCE: Only update frame constraints if size actually changed
        // CRITICAL FIX: Always preserve exact text box dimensions (no minimum size restrictions)
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
        
        // REMOVED: First responder changes can cause text position shifts
        // Let the system handle first responder naturally through user interaction
        
        // PERFORMANCE: Only force layout update if formatting or size changed
        if needsFormatUpdate || abs(currentContainerWidth - newWidth) > 1.0 {
            nsView.needsLayout = true
        }
        
        // Update coordinator's text view reference
        coordinator.textView = nsView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ProfessionalUniversalTextView
        var lastUpdateTime: Date = Date() // Performance optimization: track update frequency
        var isRestoringSelection: Bool = false // Prevents saving programmatic selection changes
        weak var textView: DisabledContextMenuTextView? // Store reference to the actual text view

        init(_ parent: ProfessionalUniversalTextView) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // SIMPLIFIED: Trust NSTextView's isEditable property instead of double-checking
            // The NSTextView isEditable is already set correctly based on editing mode
            guard textView.isEditable else {
                return
            }
            
            let newText = textView.string
            
            // Only update if text actually changed to prevent loops
            guard newText != parent.viewModel.text else {
                return
            }
            
            // CRITICAL FIX: Update both view model AND document immediately to prevent data loss
            parent.isUpdatingFromTyping = true

            // Use async to avoid publishing changes during view updates
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.viewModel.text = newText

                // Update lastTypingTime to prevent sync during active typing
                self.parent.viewModel.updateLastTypingTime()

                // SAVE TO DOCUMENT IMMEDIATELY to prevent losing text content
                self.parent.viewModel.document.updateTextContent(
                    self.parent.viewModel.textObject.id,
                    content: newText
                )
            }
            
            // Reset flag after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.parent.isUpdatingFromTyping = false
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            // CRITICAL: Do not save selection changes that happen during programmatic updates
            guard !isRestoringSelection else {
                return
            }
            guard let textView = notification.object as? NSTextView else { return }
            let selectedRange = textView.selectedRange()

            // Save to the new source of truth in the view model
            // Use async to avoid publishing changes during view updates
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.viewModel.userInitiatedCursorPosition = selectedRange.location
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
        }
        
        func textDidEndEditing(_ notification: Notification) {

            // VECTOR APP OPTIMIZATION: Save to document ONLY when editing ends
            let finalText = parent.viewModel.text
            let textFrame = parent.viewModel.textBoxFrame
            let textObjectId = parent.viewModel.textObject.id

            // Use async to avoid modifying @Published properties during view update
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

            // FIX: Use the stored text view reference directly instead of searching through windows
            guard let textView = self.textView else { return }

            // Apply typography changes directly to NSTextView for smooth preview
            DispatchQueue.main.async {
                // Update font
                let newFont = typography.nsFont
                if textView.font != newFont {
                    textView.font = newFont
                }

                // Update paragraph style for line spacing and height
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = typography.alignment.nsTextAlignment
                paragraphStyle.lineSpacing = max(0, typography.lineSpacing)
                paragraphStyle.minimumLineHeight = typography.lineHeight
                paragraphStyle.maximumLineHeight = typography.lineHeight

                textView.defaultParagraphStyle = paragraphStyle

                // Apply to existing text
                if textView.string.count > 0 {
                    let range = NSRange(location: 0, length: textView.string.count)
                    textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                    textView.textStorage?.addAttribute(.font, value: newFont, range: range)
                }

                // Force immediate layout update for smooth preview
                if let textContainer = textView.textContainer {
                    textView.layoutManager?.ensureLayout(for: textContainer)
                }
                textView.needsDisplay = true
            }
        }
    }
}