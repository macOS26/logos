//
//  EditableTextCanvas.swift
//  Test
//
//  Created by Todd Bruss on 7/21/25.
//

import SwiftUI
import CoreText

struct EditableTextCanvas: View {
    @ObservedObject var viewModel: TextEditorViewModel
    @State private var isDragging = false
    @State private var isResizing = false
    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero
    @State private var textBoxState: TextBoxState = .gray
    @FocusState private var isFocused: Bool
    
    enum TextBoxState {
        case gray    // Initial state - no selection, no editing
        case green   // Selected - can double-click or drag
        case blue    // Editing mode
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CanvasBackgroundView()
                    .onTapGesture { location in
                        handleCanvasTap(location: location, geometry: geometry)
                    }
                
                TextBoxView(
                    viewModel: viewModel,
                    dragOffset: dragOffset,
                    resizeOffset: resizeOffset,
                    textBoxState: textBoxState,
                    geometry: geometry,
                    onTextBoxSelect: handleTextBoxSelect,
                    onTextBoxTap: handleTextBoxTap,
                    onDragChanged: handleDragChanged,
                    onDragEnded: handleDragEnded
                )
                
                TextDisplayView(viewModel: viewModel, dragOffset: dragOffset, textBoxState: textBoxState)
                
                PathDisplayView(viewModel: viewModel)
                
                CursorView(viewModel: viewModel, dragOffset: dragOffset)
                
                ResizeHandleView(
                    viewModel: viewModel,
                    dragOffset: dragOffset,
                    resizeOffset: resizeOffset,
                    onResizeChanged: handleResizeChanged,
                    onResizeEnded: handleResizeEnded
                )
                
                // Removed EditingToggleView - using click/double-click pattern instead
            }
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(action: handleKeyPress)
        .onChange(of: viewModel.isEditing) { _, isEditing in
            if isEditing {
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
        }
        // Removed notification - using pure state machine
    }
    
    // MARK: - Helper Methods
    
    private func handleCanvasTap(location: CGPoint, geometry: GeometryProxy) {
        // Check if tap is outside the text box
        let adjustedTextBoxFrame = CGRect(
            x: viewModel.textBoxFrame.minX + dragOffset.width,
            y: viewModel.textBoxFrame.minY + dragOffset.height,
            width: viewModel.textBoxFrame.width + resizeOffset.width,
            height: viewModel.textBoxFrame.height + resizeOffset.height
        )
        
        if !adjustedTextBoxFrame.contains(location) {
            // Click outside text box - ALWAYS go back to GRAY
            textBoxState = .gray
            isFocused = false
            if viewModel.isEditing {
                viewModel.stopEditing()
            }
        }
    }
    
    private func handleTextBoxSelect(location: CGPoint, geometry: GeometryProxy) {
        // SINGLE CLICK: Only allowed when GRAY
        if textBoxState == .gray {
            textBoxState = .green
        }
    }
    
    private func handleTextBoxTap(location: CGPoint, geometry: GeometryProxy) {
        // DOUBLE CLICK: Only allowed when GREEN
        if textBoxState == .green {
            textBoxState = .blue
            isFocused = true
            viewModel.startEditing()
        }
    }
    
    private func handleDragChanged(value: DragGesture.Value) {
        // DRAG: Only allowed when GREEN
        if !isResizing && textBoxState == .green {
            isDragging = true
            dragOffset = value.translation
        }
    }
    
    private func handleDragEnded() {
        if isDragging {
            let newFrame = CGRect(
                x: viewModel.textBoxFrame.minX + dragOffset.width,
                y: viewModel.textBoxFrame.minY + dragOffset.height,
                width: viewModel.textBoxFrame.width,
                height: viewModel.textBoxFrame.height
            )
            viewModel.updateTextBoxFrame(newFrame)
            dragOffset = .zero
            isDragging = false
        }
    }
    
    private func handleResizeChanged(value: DragGesture.Value) {
        isResizing = true
        resizeOffset = value.translation
    }
    
    private func handleResizeEnded() {
        let newFrame = CGRect(
            x: viewModel.textBoxFrame.minX + dragOffset.width,
            y: viewModel.textBoxFrame.minY + dragOffset.height,
            width: max(100, viewModel.textBoxFrame.width + resizeOffset.width),
            height: max(50, viewModel.textBoxFrame.height + resizeOffset.height)
        )
        viewModel.updateTextBoxFrame(newFrame)
        resizeOffset = .zero
        dragOffset = .zero
        isResizing = false
        isDragging = false
    }
    
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard viewModel.isEditing else { return .ignored }
        
        // Let NSTextView handle all key events for all alignments
        return .ignored
    }
    
    // NSTextView handles coordinate conversion automatically, so this method is no longer needed
    
    // NSTextView handles cursor positioning automatically, so this method is no longer needed
    

}

// MARK: - Component Views

struct CanvasBackgroundView: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.01)) // Nearly transparent but can receive gestures
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TextBoxView: View {
    @ObservedObject var viewModel: TextEditorViewModel
    let dragOffset: CGSize
    let resizeOffset: CGSize
    let textBoxState: EditableTextCanvas.TextBoxState
    let geometry: GeometryProxy
    let onTextBoxSelect: (CGPoint, GeometryProxy) -> Void
    let onTextBoxTap: (CGPoint, GeometryProxy) -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void
    

    
    private func getBorderColor() -> Color {
        switch textBoxState {
        case .gray: return Color.gray
        case .green: return Color.green
        case .blue: return Color.blue
        }
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .stroke(getBorderColor(), lineWidth: 2)
            .frame(width: viewModel.textBoxFrame.width + resizeOffset.width,
                   height: viewModel.textBoxFrame.height + resizeOffset.height)
            .position(x: viewModel.textBoxFrame.minX + dragOffset.width + (viewModel.textBoxFrame.width + resizeOffset.width) / 2,
                     y: viewModel.textBoxFrame.minY + dragOffset.height + (viewModel.textBoxFrame.height + resizeOffset.height) / 2)
            .highPriorityGesture(
                TapGesture(count: 2)
                    .onEnded { 
                        // Double-click starts editing - highest priority
                        onTextBoxTap(CGPoint.zero, geometry)
                    }
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged(onDragChanged)
                    .onEnded { _ in onDragEnded() }
            )
            .onTapGesture(count: 1) { location in
                // Single click should ONLY select, not edit
                onTextBoxSelect(location, geometry)
            }
    }
}

struct TextDisplayView: View {
    @ObservedObject var viewModel: TextEditorViewModel
    let dragOffset: CGSize
    let textBoxState: EditableTextCanvas.TextBoxState
    
    var body: some View {
        Group {
            // Always show text, but make it transparent when showing paths
            TextContentView(viewModel: viewModel, textBoxState: textBoxState)
                .position(x: viewModel.textBoxFrame.minX + dragOffset.width + viewModel.textBoxFrame.width / 2,
                         y: viewModel.textBoxFrame.minY + dragOffset.height + viewModel.textBoxFrame.height / 2)
                .opacity(viewModel.showPath ? 0.3 : 1.0) // Show faintly when paths are visible
        }
    }
}

struct PathDisplayView: View {
    @ObservedObject var viewModel: TextEditorViewModel
    
    var body: some View {
        Group {
            if viewModel.showPath, let path = viewModel.textPath {
                // Simple fill only
                Path(path)
                    .fill(viewModel.textColor)
            }
        }
    }
}

struct CursorView: View {
    @ObservedObject var viewModel: TextEditorViewModel
    let dragOffset: CGSize
    
    var body: some View {
        Group {
            // NSTextView handles its own cursor for all alignments now
            // Custom cursor is no longer needed
        }
    }
}

struct ResizeHandleView: View {
    @ObservedObject var viewModel: TextEditorViewModel
    let dragOffset: CGSize
    let resizeOffset: CGSize
    let onResizeChanged: (DragGesture.Value) -> Void
    let onResizeEnded: () -> Void
    
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 10, height: 10)
            .position(x: viewModel.textBoxFrame.maxX + dragOffset.width + resizeOffset.width,
                     y: viewModel.textBoxFrame.maxY + dragOffset.height + resizeOffset.height)
            .gesture(
                DragGesture()
                    .onChanged(onResizeChanged)
                    .onEnded { _ in onResizeEnded() }
            )
    }
}

// Removed EditingToggleView - now using click/double-click interaction pattern

struct TextContentView: View {
    @ObservedObject var viewModel: TextEditorViewModel
    let textBoxState: EditableTextCanvas.TextBoxState
    
    var body: some View {
        if textBoxState == .blue {
            // BLUE STATE: Use NSTextView for editing
            UniversalTextView(viewModel: viewModel)
                .frame(width: viewModel.textBoxFrame.width, height: viewModel.textBoxFrame.height, alignment: .topLeading)
        } else {
            // GRAY/GREEN STATE: Use SwiftUI Text - allows gestures to pass through
            SwiftUITextView(viewModel: viewModel)
                .frame(width: viewModel.textBoxFrame.width, height: viewModel.textBoxFrame.height, alignment: .topLeading)
        }
    }
}

struct SwiftUITextView: View {
    @ObservedObject var viewModel: TextEditorViewModel
    
    private var swiftUIAlignment: HorizontalAlignment {
        switch viewModel.textAlignment {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        case .justified:
            return .leading // For justified, we'll handle it differently
        default:
            return .leading
        }
    }
    
    var body: some View {
        VStack(alignment: swiftUIAlignment, spacing: 0) {
            Text(viewModel.text)
                .font(Font.custom(viewModel.selectedFont.fontName, size: viewModel.fontSize))
                .foregroundColor(viewModel.textColor)
                .lineSpacing(viewModel.lineSpacing)
                .multilineTextAlignment(viewModel.textAlignment == .justified ? .leading : 
                    (viewModel.textAlignment == .left ? .leading :
                     viewModel.textAlignment == .center ? .center : .trailing))
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: swiftUIAlignment, vertical: .top))
            Spacer()
        }
        .allowsHitTesting(false) // This is key - allows gestures to pass through!
    }
}

// NSTextView wrapper for all text alignments on macOS
struct UniversalTextView: NSViewRepresentable {
    @ObservedObject var viewModel: TextEditorViewModel
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        
        // Enable editing to get proper I-beam cursor
        textView.isEditable = viewModel.isEditing
        textView.isSelectable = true
        textView.backgroundColor = NSColor.clear
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = []
        
        // Ensure proper mouse handling and cursor behavior
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        // NO DELEGATE - using direct state monitoring instead of notifications
        
        // Store reference for coordinator
        context.coordinator.textView = textView
        
        // Set up cursor color and flashing
        setupCursorFlashing(for: textView, with: viewModel)
        
        // Fix coordinate system - make sure text starts at top
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        
        return textView
    }
    
    private func setupCursorFlashing(for textView: NSTextView, with viewModel: TextEditorViewModel) {
        // Set initial cursor color
        textView.insertionPointColor = NSColor(viewModel.textColor)
        
        // Start cursor flashing animation if editing
        if viewModel.isEditing {
            startCursorFlashing(for: textView, with: viewModel)
        }
    }
    
    private func startCursorFlashing(for textView: NSTextView, with viewModel: TextEditorViewModel) {
        // Create a repeating timer for cursor flashing
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                // Toggle between text color and clear
                if textView.insertionPointColor == NSColor(viewModel.textColor) {
                    textView.insertionPointColor = NSColor.clear
                } else {
                    textView.insertionPointColor = NSColor(viewModel.textColor)
                }
            }
        }
        
        // Store timer reference in coordinator to manage lifecycle
        if let coordinator = textView.delegate as? Coordinator {
            coordinator.cursorTimer?.invalidate()
            coordinator.cursorTimer = timer
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: UniversalTextView
        weak var textView: NSTextView?
        var cursorTimer: Timer?
        
        init(_ parent: UniversalTextView) {
            self.parent = parent
        }
        
        deinit {
            cursorTimer?.invalidate()
        }
        
        // Override to handle mouse clicks properly
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            return false // Let normal text view handle it
        }
        
        // REMOVED DELEGATE METHODS - using direct state monitoring in updateNSView instead
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
        // Control text input and selection based on editing state
        nsView.isEditable = viewModel.isEditing
        nsView.isSelectable = viewModel.isEditing  // Only selectable when editing
        
        // CRITICAL: Allow drag gestures to pass through when not editing
        // The key is to make the NSTextView completely transparent to mouse events when not editing
        if !viewModel.isEditing {
            // Safely remove the NSTextView from the responder chain when not editing
            if nsView.window?.firstResponder == nsView {
                nsView.resignFirstResponder()
            }
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = viewModel.textAlignment // Use the actual alignment from view model
        paragraphStyle.lineSpacing = viewModel.lineSpacing
        
        // For justified text, control word spacing to prevent overly wide gaps
        if viewModel.textAlignment == .justified {
            // Set a maximum line height to prevent excessive stretching
            let font = NSFont(name: viewModel.selectedFont.fontName, size: viewModel.fontSize) ?? NSFont.systemFont(ofSize: viewModel.fontSize)
            let lineHeight = font.ascender - font.descender + font.leading
            paragraphStyle.maximumLineHeight = lineHeight * 1.5
            paragraphStyle.minimumLineHeight = lineHeight
            
            // Disable hyphenation for better control
            paragraphStyle.hyphenationFactor = 0.0
            
            // Allow tightening to help with justification
            paragraphStyle.allowsDefaultTighteningForTruncation = true
        }
        
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: viewModel.selectedFont.fontName, size: viewModel.fontSize) ?? NSFont.systemFont(ofSize: viewModel.fontSize),
            .foregroundColor: NSColor(viewModel.textColor),
            .paragraphStyle: paragraphStyle
        ]
        
        // For justified text, add word spacing control
        if viewModel.textAlignment == .justified {
            // Limit expansion to prevent excessive word spacing
            attributes[.expansion] = 0.0 // No character expansion
        }
        
        // Only update text if it's different to avoid cursor jumping
        if nsView.string != viewModel.text {
            let attributedString = NSAttributedString(string: viewModel.text, attributes: attributes)
            nsView.textStorage?.setAttributedString(attributedString)
        } else {
            // Just update the attributes if text is the same
            let range = NSRange(location: 0, length: nsView.string.count)
            nsView.textStorage?.addAttributes(attributes, range: range)
        }
        
        // Let NSTextView be the authoritative source for cursor position when editing
        // Only sync FROM NSTextView TO view model, not the other way around
        if viewModel.isEditing {
            // NSTextView handles cursor, we just observe
            let currentPosition = nsView.selectedRange().location
            if viewModel.cursorPosition != currentPosition {
                viewModel.cursorPosition = currentPosition
            }
        } else {
            // When not editing, set initial cursor position
            let targetPosition = min(viewModel.cursorPosition, nsView.string.count)
            if nsView.selectedRange().location != targetPosition {
                let newRange = NSRange(location: targetPosition, length: 0)
                nsView.setSelectedRange(newRange)
            }
        }
        
        // Set the text container size to match our text box exactly
        nsView.textContainer?.containerSize = NSSize(width: viewModel.textBoxFrame.width, height: viewModel.textBoxFrame.height)
        
        // For justified text, ensure proper layout manager settings
        if viewModel.textAlignment == .justified {
            nsView.layoutManager?.allowsNonContiguousLayout = false // Force sequential layout for better justification
        }
        
        // DIRECT STATE MONITORING - NO NOTIFICATIONS
        // Check if text changed and update viewModel directly
        if nsView.string != viewModel.text {
            // NSTextView text changed - update our state
            viewModel.text = nsView.string
        }
        
        // Check if cursor position changed and update viewModel directly  
        if viewModel.isEditing {
            let currentNSTextViewPosition = nsView.selectedRange().location
            if viewModel.cursorPosition != currentNSTextViewPosition {
                viewModel.cursorPosition = currentNSTextViewPosition
            }
        }
        
        // Force layout update
        nsView.layoutManager?.ensureLayout(for: nsView.textContainer!)
        
        // Ensure the text view becomes first responder when editing starts
        if viewModel.isEditing {
            // Force first responder status immediately for I-beam cursor
            if nsView.window?.firstResponder != nsView {
                nsView.window?.makeFirstResponder(nsView)
            }
            
            // Start cursor flashing if not already started
            if context.coordinator.cursorTimer == nil {
                startCursorFlashing(for: nsView, with: viewModel)
            }
        } else {
            // When not editing, resign first responder
            if nsView.window?.firstResponder == nsView {
                nsView.resignFirstResponder()
            }
            
            // Stop cursor flashing and reset to solid color
            context.coordinator.cursorTimer?.invalidate()
            context.coordinator.cursorTimer = nil
            nsView.insertionPointColor = NSColor(viewModel.textColor)
        }
        
        // Update cursor color if text color changed
        if nsView.insertionPointColor != NSColor.clear && nsView.insertionPointColor != NSColor(viewModel.textColor) {
            nsView.insertionPointColor = NSColor(viewModel.textColor)
        }
    }
}

// Extension to check if character is printable
extension Character {
    var isPrintable: Bool {
        // Exclude control characters and only allow visible characters plus space
        return !isWhitespace || self == " "
    }
}

// Extension to trim only trailing whitespace (but preserve newlines)
extension String {
    func trimmingTrailingWhitespace() -> String {
        return self.replacingOccurrences(of: "[ \\t]+$", with: "", options: .regularExpression)
    }
}

 
