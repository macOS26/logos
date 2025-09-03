//
//  ProfessionalTextCanvas.swift
//  logos inkpen.io
//
//  Professional text editing using the proven working NewTextBoxFontTool approach
//  Adapted for VectorText and VectorColor systems with existing FontPanel integration
//

import SwiftUI
import CoreText

// MARK: - Stable Text Canvas Wrapper (Prevents ViewModel Recreation)
struct StableProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    let textObjectID: UUID
    @StateObject private var viewModel: ProfessionalTextViewModel
    
    // NEW: Drag preview parameters for live preview during dragging
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    
    init(document: VectorDocument, textObjectID: UUID, dragPreviewDelta: CGPoint = .zero, dragPreviewTrigger: Bool = false) {
        self.document = document
        self.textObjectID = textObjectID
        self.dragPreviewDelta = dragPreviewDelta
        self.dragPreviewTrigger = dragPreviewTrigger
        
        // Create view model ONCE and reuse it
        if let textObject = document.allTextObjects.first(where: { $0.id == textObjectID }) {
            self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: textObject, document: document))
        } else {
            // MIGRATION FIX: Create fallback text with proper content
            let fallbackText = VectorText(content: "Text", typography: TypographyProperties(strokeColor: .black, fillColor: .black))
            self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: fallbackText, document: document))
        }
    }
    
    var body: some View {
        // Update view model when text object changes (without recreating it)
        ProfessionalTextCanvas(
            document: document, 
            viewModel: viewModel, 
            textObjectID: textObjectID,
            dragPreviewDelta: dragPreviewDelta,
            dragPreviewTrigger: dragPreviewTrigger
        )
            .onAppear {
                updateViewModelFromDocument()
            }
            .onChange(of: document.textObjects) { _, _ in
                updateViewModelFromDocument()
            }
            // Additional fix: Use id to force view refresh when text content changes
            .id("\(textObjectID)-\(getDocumentMode())")

    }
    
    private func updateViewModelFromDocument() {
        // MIGRATION FIX: Find text object in textObjects array (legacy system still used for editing)
        if let currentTextObject = document.allTextObjects.first(where: { $0.id == textObjectID }) {
            viewModel.syncFromVectorText(currentTextObject)
            Log.fileOperation("✅ TEXT CANVAS: Found text object \(textObjectID.uuidString.prefix(8)) content: '\(currentTextObject.content)'", level: .info)
        } else {
            // FALLBACK: If text object missing from textObjects, log issue with debugging info
            Log.fileOperation("⚠️ TEXT CANVAS: Text object \(textObjectID.uuidString.prefix(8)) not found in textObjects array", level: .info)
            Log.fileOperation("🔍 DEBUG: Available text object IDs: \(document.allTextObjects.map { $0.id.uuidString.prefix(8) })", level: .info)
            Log.fileOperation("🔍 DEBUG: Total text objects: \(document.allTextObjects.count)", level: .info)
        }
    }
    
    private func getDocumentMode() -> String {
        if let currentTextObject = document.allTextObjects.first(where: { $0.id == textObjectID }) {
            // PROFESSIONAL UX: Stable view while font tool is active
            // Create compact typography hash to avoid super long strings
            
            if document.currentTool == .font {
                // While font tool is active, exclude content to prevent view recreation during typing
                return "font-tool"
            } else {
                // When other tools are active, include content for proper updates
                return "\(currentTextObject.content)-\(currentTextObject.isEditing)"
            }
        }
        return "text-missing"
    }
}

// MARK: - Professional Text Canvas (Based on Working EditableTextCanvas)
struct ProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let textObjectID: UUID // Store the text object ID for reliable state checking
    
    // NEW: Drag preview parameters for live preview during dragging
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    
    @State private var isDragging = false
    @State private var isResizing = false
    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero
    @State private var textBoxState: TextBoxState = .gray
    @State private var isResizeHandleActive = false  // NEW: Track resize handle state
    // REMOVED: @FocusState - We use our own 3-state system
    
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
                // REMOVED: onDragChanged and onDragEnded - arrow tool handles all dragging
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
        .offset(x: document.selectedTextIDs.contains(textObjectID) ? dragPreviewDelta.x * document.zoomLevel : 0, 
                y: document.selectedTextIDs.contains(textObjectID) ? dragPreviewDelta.y * document.zoomLevel : 0)
        .id(dragPreviewTrigger) // Force efficient re-render when trigger changes
        .onKeyPress(action: handleKeyPress)
        .onChange(of: document.selectedTextIDs) { _, selectedIDs in
            Log.fileOperation("🔄 SELECTED TEXT IDs CHANGED: \(selectedIDs.map { $0.uuidString.prefix(8) }) for textID \(viewModel.textObject.id.uuidString.prefix(8))", level: .info)
            updateTextBoxState(selectedIDs: selectedIDs)
        }
        .onChange(of: viewModel.isEditing) { _, isEditing in
            Log.fileOperation("🔧 VIEW MODEL EDITING CHANGED: \(isEditing) for text '\(viewModel.text)'", level: .info)
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }
        .onChange(of: viewModel.textObject.isEditing) { _, isEditing in
            Log.fileOperation("🔧 DOCUMENT TEXT EDITING CHANGED: \(isEditing) for text '\(viewModel.text)'", level: .info)
            // Sync view model with document
            viewModel.isEditing = isEditing
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }
        // CRITICAL FIX: Monitor document text objects for editing state changes
        .onChange(of: document.allTextObjects.map { $0.isEditing }) { _, _ in
            Log.fileOperation("🔧 ANY TEXT EDITING STATE CHANGED - refreshing state", level: .info)
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }
        .onAppear {
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
            
            // CRITICAL FIX: Ensure VectorText bounds match text canvas on initial appearance
            // This fixes the selection box when text is first created
            viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
        }
        .onChange(of: document.currentTool) { oldTool, newTool in
            // NEW: When user selects type tool and this text box is GREEN (selected), change to BLUE (editing)
            if oldTool != .font && newTool == .font && textBoxState == .green {
                Log.fileOperation("🔧 TOOL CHANGE: Type tool selected with GREEN text box - switching to BLUE (editing)", level: .info)
                
                // CRITICAL: Ensure only one text box can be edited at a time
                // Stop editing on all other text boxes first
                for textIndex in document.allTextObjects.indices {
                    if document.textObjects[textIndex].id != viewModel.textObject.id && document.textObjects[textIndex].isEditing {
                        document.textObjects[textIndex].isEditing = false
                        Log.fileOperation("🔄 STOPPING EDIT: Text box \(document.textObjects[textIndex].id.uuidString.prefix(8)) was in edit mode", level: .info)
                    }
                }
                
                // Start editing this text box
                viewModel.startEditing()
                
                // Update document editing state
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == viewModel.textObject.id }) {
                    document.textObjects[textIndex].isEditing = true
                }
                
                // CRITICAL FIX: Force immediate state update and sync
                textBoxState = .blue
                Log.info("🔵 FORCED STATE CHANGE: GREEN → BLUE due to type tool selection", category: .general)
                
                DispatchQueue.main.async {
                    updateTextBoxState(selectedIDs: document.selectedTextIDs)
                }
            }
            
            // PROFESSIONAL UX: Stop editing when user switches away from font tool
            if oldTool == .font && newTool != .font && viewModel.isEditing {
                Log.fileOperation("🔧 TOOL CHANGE: Stopping text editing (switched from \(oldTool.rawValue) to \(newTool.rawValue))", level: .info)
                viewModel.stopEditing()
                
                // Update document editing state
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == viewModel.textObject.id }) {
                    document.textObjects[textIndex].isEditing = false
                }
                
                textBoxState = .gray
            }
            
            // CRITICAL FIX: Update bounds when switching away from font tool
            // This ensures selection box is correct when using arrow tool
            if oldTool == .font && newTool != .font {
                viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
                Log.fileOperation("🔧 TOOL CHANGE: Updated VectorText bounds for selection tool", level: .info)
            }
        }
    }
    
    // MARK: - State Management (From Working Code)
    
    private func updateTextBoxState(selectedIDs: Set<UUID>) {
        let oldState = textBoxState
        
        // CRITICAL FIX: Always use current document text object, not potentially stale view model reference
        guard let currentTextObject = document.allTextObjects.first(where: { $0.id == textObjectID }) else {
            textBoxState = .gray
            Log.info("  → GRAY (text object not found in document)", category: .general)
            return
        }
        
        // PROFESSIONAL UX: Keep editing active while font tool is selected
        let isTextToolActive = document.currentTool == .font
        let hasTextViewFocus = NSApp.keyWindow?.firstResponder is NSTextView
        let isThisTextSelected = selectedIDs.contains(currentTextObject.id) // Use current document object
        
        // State check - reduced logging for performance
        
        // FIXED: Prioritize editing state correctly
        if currentTextObject.isEditing {
            textBoxState = .blue
            Log.info("  → BLUE (editing mode) - isEditing=\(currentTextObject.isEditing), fontTool=\(isTextToolActive)", category: .general)
        } else if hasTextViewFocus && isTextToolActive {
            textBoxState = .blue
            Log.info("  → BLUE (NSTextView focus) - focus=\(hasTextViewFocus), fontTool=\(isTextToolActive)", category: .general)
        } else if isThisTextSelected && isTextToolActive {
            textBoxState = .green
            Log.info("  → GREEN (selected with font tool) - selected=\(isThisTextSelected), fontTool=\(isTextToolActive)", category: .general)
        } else if isThisTextSelected {
            textBoxState = .green
            Log.info("  → GREEN (selected) - selected=\(isThisTextSelected)", category: .general)
        } else {
            textBoxState = .gray
            Log.info("  → GRAY (unselected)", category: .general)
        }
        
        if oldState != textBoxState {
            // Text box state changed - reduced logging for performance
            
            // VECTOR APP OPTIMIZATION: Save text to document when exiting editing mode
            if oldState == .blue && (textBoxState == .green || textBoxState == .gray) {
                // Save final text content and bounds to document
                viewModel.document.updateTextContent(viewModel.textObject.id, content: viewModel.text)
                viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
                Log.info("💾 SAVED TEXT TO DOCUMENT: Blue → \(textBoxState == .green ? "Green" : "Gray")", category: .fileOperations)
                
            }
        }
    }
    
    // MARK: - Event Handlers (Exact from Working Code)
    
    private func handleTextBoxSelect(location: CGPoint) {
        // SINGLE CLICK: Handle different states appropriately
        switch textBoxState {
        case .gray:
            // Select the text box
            textBoxState = .green
            document.selectedTextIDs = [viewModel.textObject.id]
            document.selectedShapeIDs.removeAll()
            Log.info("🎯 TEXT BOX SELECT: GRAY → GREEN", category: .general)
            
        case .green:
            // Already selected - no change needed
            Log.info("🎯 TEXT BOX SELECT: Already GREEN", category: .general)
            
        case .blue:
            // In editing mode - let NSTextView handle the click for text editing
            Log.info("🎯 TEXT BOX SELECT: BLUE mode - letting NSTextView handle click", category: .general)
        }
    }
    

    
    // REMOVED: handleDragChanged and handleDragEnded functions
    // Arrow tool now handles all text box dragging with its built-in system
    
    // NEW: Track when resize starts
    private func handleResizeStarted() {
        isResizeHandleActive = true
        Log.info("🔵 RESIZE HANDLE ACTIVATED", category: .general)
    }
    
    private func handleResizeChanged(value: DragGesture.Value) {
        isResizing = true
        resizeOffset = value.translation
        Log.info("🔵 TEXT BOX RESIZE: \(value.translation)", category: .general)
    }
    
    private func handleResizeEnded() {
        let newFrame = CGRect(
            x: viewModel.textBoxFrame.minX,  // DON'T move position when resizing
            y: viewModel.textBoxFrame.minY,  // DON'T move position when resizing
            width: max(100, viewModel.textBoxFrame.width + resizeOffset.width),
            height: max(50, viewModel.textBoxFrame.height + resizeOffset.height)
        )
        
        Log.fileOperation("🔄 RESIZE ENDED: Old frame: \(viewModel.textBoxFrame), New frame: \(newFrame)", level: .info)
        
        viewModel.updateTextBoxFrame(newFrame)
        resizeOffset = .zero
        dragOffset = .zero
        isResizing = false
        isDragging = false
        isResizeHandleActive = false  // NEW: Reset resize handle state
        Log.info("✅ TEXT BOX RESIZE COMPLETED", category: .fileOperations)
    }
    
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard viewModel.isEditing else { return .ignored }
        
        // ESC key exits editing mode
        if keyPress.key == .escape {
            // VECTOR APP OPTIMIZATION: Save text to document before exiting editing mode
            viewModel.document.updateTextContent(viewModel.textObject.id, content: viewModel.text)
            viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
            Log.info("💾 SAVED TEXT TO DOCUMENT: ESC key pressed", category: .fileOperations)
            
            textBoxState = .green
            viewModel.stopEditing()
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == viewModel.textObject.id }) {
                document.textObjects[textIndex].isEditing = false
            }
            return .handled
        }
        
        // Let NSTextView handle all other key events
        return .ignored
    }
}

// MARK: - Professional Text Box View (Based on Working TextBoxView)
struct ProfessionalTextBoxView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    let resizeOffset: CGSize
    let textBoxState: ProfessionalTextCanvas.TextBoxState
    let isResizeHandleActive: Bool  // NEW: Track resize handle state
    let onTextBoxSelect: (CGPoint) -> Void
    let zoomLevel: CGFloat
    // REMOVED: onDragChanged and onDragEnded - arrow tool handles all dragging
    
    private func getBorderColor() -> Color {
        switch textBoxState {
        case .gray: return Color.gray
        case .green: return Color.green
        case .blue: return Color.blue
        }
    }
    
    var body: some View {
        ZStack {
            // Main text box rectangle with clear background
            Rectangle()
                .fill(Color.clear) // Clear background - arrow tool handles hit detection
                .stroke(getBorderColor(), lineWidth: 1.0 / max(zoomLevel, 0.0001)) // Always ~1px on screen
                .frame(
                    width: viewModel.textBoxFrame.width + resizeOffset.width,
                    height: viewModel.textBoxFrame.height + resizeOffset.height
                )
                .position(
                    x: viewModel.textBoxFrame.minX + dragOffset.width + (viewModel.textBoxFrame.width + resizeOffset.width) / 2,
                    y: viewModel.textBoxFrame.minY + dragOffset.height + (viewModel.textBoxFrame.height + resizeOffset.height) / 2
                )
                .onTapGesture(count: 1) { location in
                    onTextBoxSelect(location)
                }
                .onTapGesture(count: 2) { location in
                    // Double-click: call the proper interaction handler
                    Log.info("🔧 DOUBLE-CLICK DETECTED on text box", category: .general)
                    viewModel.handleTextBoxInteraction(textID: viewModel.textObject.id, isDoubleClick: true)
                }
                // REMOVED: Explicit drag gesture - let arrow tool handle all dragging naturally
                // FIXED: Allow hit testing in all modes so arrow tool can select and move text objects
                .allowsHitTesting(true)
            
            // REMOVED: Red corner circles were jumping around and awful
        }
    }
    

}



// MARK: - Professional Text Display (Based on Working TextDisplayView)
struct ProfessionalTextDisplayView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    let textBoxState: ProfessionalTextCanvas.TextBoxState
    
    var body: some View {
        Group {
            ProfessionalTextContentView(
                viewModel: viewModel,
                textBoxState: textBoxState
            )
            .position(
                x: viewModel.textBoxFrame.minX + dragOffset.width + viewModel.textBoxFrame.width / 2,
                y: viewModel.textBoxFrame.minY + dragOffset.height + viewModel.textBoxFrame.height / 2
            )
        }
    }
}

// MARK: - Professional Text Content (Based on Working TextContentView)
struct ProfessionalTextContentView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let textBoxState: ProfessionalTextCanvas.TextBoxState
    
    var body: some View {
        // ALWAYS USE NSTextView for consistent rendering - just control editing state
        // CRITICAL FIX: Allow selection in both BLUE (editing) and GREEN (selected) states for drag operations
        let isSelectable = textBoxState == .blue || textBoxState == .green
        // FIXED: Allow hit testing when in BLUE (editing) mode so NSTextView can receive clicks for text editing
        let shouldAllowHitTesting = textBoxState == .blue
        ProfessionalUniversalTextView(viewModel: viewModel, isEditingAllowed: textBoxState == .blue, isSelectable: isSelectable)
            .allowsHitTesting(shouldAllowHitTesting) // FIXED: Allow hit testing in BLUE mode for text editing
            .frame(
                width: viewModel.textBoxFrame.width,     // FIXED WIDTH - NEVER CHANGES
                height: viewModel.textBoxFrame.height,   // CURRENT HEIGHT
                alignment: .topLeading
            )
            .clipped()  // CRITICAL: Clip any overflow to prevent horizontal expansion
            .onAppear {
                // Text view appeared - no need for verbose logging
            }
    }
}



// MARK: - Professional Universal Text View (Based on Working UniversalTextView)
struct ProfessionalUniversalTextView: NSViewRepresentable {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    @State var isUpdatingFromTyping: Bool = false  // Prevents NSTextView reset during typing
    let isEditingAllowed: Bool // New parameter to control editing
    let isSelectable: Bool // New parameter to control selection
    
    init(viewModel: ProfessionalTextViewModel, isEditingAllowed: Bool = true, isSelectable: Bool = true) {
        self.viewModel = viewModel
        self.isEditingAllowed = isEditingAllowed
        self.isSelectable = isSelectable
    }
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = DisabledContextMenuTextView()
        
        // CRITICAL: Configure NSTextView to NEVER grow horizontally, only wrap text
        textView.isEditable = viewModel.isEditing && isEditingAllowed
        textView.isSelectable = isSelectable // CRITICAL: Allow selection in both BLUE and GREEN modes for drag operations
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
        
        textView.allowsUndo = isEditingAllowed
        textView.usesFindPanel = isSelectable
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        // Disable system contextual menu for this NSTextView
        textView.menu = nil
        
        textView.delegate = context.coordinator  // CRITICAL: Set delegate to capture text changes
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        
        // CRITICAL FIX: Set initial text and appearance directly on NSTextView
        textView.string = viewModel.text
        textView.font = viewModel.selectedFont
        
        // FIXED: Use proper color conversion
        let textColor = NSColor(viewModel.textObject.typography.fillColor.color)
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        
        // Set initial paragraph style for line height and spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = viewModel.textAlignment
        paragraphStyle.lineSpacing = max(0, viewModel.textObject.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = viewModel.textObject.typography.lineHeight
        paragraphStyle.maximumLineHeight = viewModel.textObject.typography.lineHeight
        textView.defaultParagraphStyle = paragraphStyle
        
        // First responder will be set in updateNSView when needed
        
        return textView
    }
    

    
    func updateNSView(_ nsView: NSTextView, context: Context) {
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
            nsView.font = newFont
            needsFormatUpdate = true
            Log.fileOperation("🔤 FONT CHANGED: \(newFont.fontName) \(newFont.pointSize)pt", level: .info)
        }
        
        // FIXED: Proper color handling
        let newTextColor = NSColor(viewModel.textObject.typography.fillColor.color)
        let currentColor = nsView.textColor ?? NSColor.black
        
        // Simple color comparison - check if colors are different
        if currentColor != newTextColor {
            nsView.textColor = newTextColor
            nsView.insertionPointColor = newTextColor
            needsFormatUpdate = true
            Log.fileOperation("🎨 COLOR CHANGED: \(currentColor) → \(newTextColor)", level: .info)
        }
        
        // FIXED: Always update paragraph style to ensure line height and spacing are preserved
        let newAlignment = viewModel.textAlignment
        let newLineSpacing = max(0, viewModel.textObject.typography.lineSpacing)
        let newLineHeight = viewModel.textObject.typography.lineHeight
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = newAlignment
        paragraphStyle.lineSpacing = newLineSpacing
        paragraphStyle.minimumLineHeight = newLineHeight
        paragraphStyle.maximumLineHeight = newLineHeight
        
        // Apply paragraph style to all text
        if nsView.string.count > 0 {
            let range = NSRange(location: 0, length: nsView.string.count)
            nsView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }
        
        nsView.defaultParagraphStyle = paragraphStyle
        needsFormatUpdate = true
        
        // CRITICAL FIX: Update text container width when text box is resized
        let currentContainerWidth = nsView.textContainer?.containerSize.width ?? 0
        // CRITICAL FIX: Always preserve exact text box dimensions (no minimum size restrictions)
        let newWidth = viewModel.textBoxFrame.width
        let newHeight = viewModel.textBoxFrame.height
        
        if abs(currentContainerWidth - newWidth) > 1.0 { // Only update if significantly different
            print("📏 UPDATING TEXT CONTAINER WIDTH: \(String(format: "%.1f", currentContainerWidth))pt → \(String(format: "%.1f", newWidth))pt")
            
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
            nsView.layoutManager?.ensureLayout(for: nsView.textContainer!)
            
            Log.info("📏 TEXT REFLOW: Container updated, text should now wrap to new width", category: .general)
        }
        
        // CRITICAL FIX: Only restore cursor position when text content changes, not font changes
        // This prevents the I-beam from falling behind when switching fonts
        let textContentChanged = !isUpdatingFromTyping && nsView.string != viewModel.text
        let needsCursorRestore = textContentChanged && viewModel.isEditing && isEditingAllowed
        
        if needsCursorRestore {
            // Use the trusted source of truth from the view model
            let savedCursorPosition = viewModel.userInitiatedCursorPosition
            let savedSelectionLength = viewModel.userInitiatedSelectionLength

            // Ensure cursor position is within text bounds
            let textLength = nsView.string.count
            let safePosition = min(savedCursorPosition, textLength)
            let safeLength = min(savedSelectionLength, textLength - safePosition)
            let newRange = NSRange(location: safePosition, length: safeLength)
            
            // Only update if the range is different to avoid cursor jumping
            if nsView.selectedRange() != newRange {
                nsView.setSelectedRange(newRange)
                Log.fileOperation("🎯 RESTORED CURSOR: position=\(safePosition) length=\(safeLength)", level: .info)
                nsView.scrollRangeToVisible(newRange)
            }
        } else if viewModel.isEditing && isEditingAllowed && needsFormatUpdate {
            // When only font/formatting changes, preserve current cursor position
            // but ensure it's still valid within the text bounds
            let currentRange = nsView.selectedRange()
            let textLength = nsView.string.count
            
            if currentRange.location > textLength {
                // Cursor is beyond text bounds, move it to end
                let newRange = NSRange(location: textLength, length: 0)
                nsView.setSelectedRange(newRange)
                Log.fileOperation("🎯 ADJUSTED CURSOR: Moved from \(currentRange.location) to end (\(textLength)) due to font change", level: .info)
            } else if currentRange.location + currentRange.length > textLength {
                // Selection extends beyond text bounds, adjust it
                let newRange = NSRange(location: currentRange.location, length: textLength - currentRange.location)
                nsView.setSelectedRange(newRange)
                Log.fileOperation("🎯 ADJUSTED SELECTION: Adjusted length from \(currentRange.length) to \(newRange.length) due to font change", level: .info)
            }
        }
        
        // PERFORMANCE: Only update editing properties if they actually changed
        let newIsEditable = viewModel.isEditing && isEditingAllowed
        let newIsSelectable = isSelectable
        
        nsView.isEditable = viewModel.isEditing && isEditingAllowed
        nsView.isSelectable = isSelectable // CRITICAL: Allow selection in both BLUE and GREEN modes for drag operations
        
        Log.fileOperation("🔧 UPDATE NSTextView: textID=\(viewModel.textObject.id.uuidString.prefix(8)) isEditing=\(viewModel.isEditing) isEditingAllowed=\(isEditingAllowed) isSelectable=\(isSelectable) → isEditable=\(nsView.isEditable), isSelectable=\(nsView.isSelectable)", level: .info)
        
        
        if nsView.isEditable != newIsEditable {
            nsView.isEditable = newIsEditable
        }
        
        if nsView.isSelectable != newIsSelectable {
            nsView.isSelectable = newIsSelectable
        }
        
        // PERFORMANCE: Only force display update if format changed and view is first responder
        if needsFormatUpdate && nsView.window?.firstResponder == nsView {
            nsView.setNeedsDisplay(nsView.visibleRect)
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
        
        // FIXED: Ensure text view gets focus when editing is active
        let shouldBeFirstResponder = viewModel.isEditing && isEditingAllowed
        let isCurrentlyFirstResponder = nsView.window?.firstResponder == nsView
        
        if shouldBeFirstResponder && !isCurrentlyFirstResponder {
            Log.fileOperation("🎯 MAKING FIRST RESPONDER: textID=\(viewModel.textObject.id.uuidString.prefix(8))", level: .info)
            nsView.window?.makeFirstResponder(nsView)
        } else if !shouldBeFirstResponder && isCurrentlyFirstResponder {
            Log.fileOperation("🎯 REMOVING FIRST RESPONDER: textID=\(viewModel.textObject.id.uuidString.prefix(8))", level: .info)
            nsView.window?.makeFirstResponder(nil)
        }
        
        // PERFORMANCE: Only force layout update if formatting or size changed
        if needsFormatUpdate || abs(currentContainerWidth - newWidth) > 1.0 {
            nsView.needsLayout = true
        }
    }
    
    // HELPER: Reliable color comparison using color components
    private func colorsAreEqual(_ color1: NSColor, _ color2: NSColor) -> Bool {
        // Convert to RGB color space for reliable comparison
        guard let rgb1 = color1.usingColorSpace(.sRGB),
              let rgb2 = color2.usingColorSpace(.sRGB) else {
            return false
        }
        
        return abs(rgb1.redComponent - rgb2.redComponent) < 0.001 &&
               abs(rgb1.greenComponent - rgb2.greenComponent) < 0.001 &&
               abs(rgb1.blueComponent - rgb2.blueComponent) < 0.001 &&
               abs(rgb1.alphaComponent - rgb2.alphaComponent) < 0.001
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ProfessionalUniversalTextView
        var lastUpdateTime: Date = Date() // Performance optimization: track update frequency
        var isRestoringSelection: Bool = false // Prevents saving programmatic selection changes

        init(_ parent: ProfessionalUniversalTextView) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // SIMPLIFIED: Trust NSTextView's isEditable property instead of double-checking
            // The NSTextView isEditable is already set correctly based on editing mode
            guard textView.isEditable else {
                Log.info("🚫 TEXT VIEW NOT EDITABLE: Change ignored", category: .general)
                return
            }
            
            let newText = textView.string
            
            // Only update if text actually changed to prevent loops
            guard newText != parent.viewModel.text else {
                return
            }
            
            // CRITICAL FIX: Update both view model AND document immediately to prevent data loss
            parent.isUpdatingFromTyping = true
            parent.viewModel.text = newText
            
            // SAVE TO DOCUMENT IMMEDIATELY to prevent losing text content
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
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
                Log.info("🚫 COORDINATOR BLOCKED SAVE: Programmatic restore in progress", category: .general)
                return
            }
            guard let textView = notification.object as? NSTextView else { return }
            let selectedRange = textView.selectedRange()
            
            // Save to the new source of truth in the view model
            parent.viewModel.userInitiatedCursorPosition = selectedRange.location
            parent.viewModel.userInitiatedSelectionLength = selectedRange.length
            Log.info("💾 COORDINATOR SAVED CURSOR: position=\(selectedRange.location) length=\(selectedRange.length)", category: .general)
        }

        func textDidBeginEditing(_ notification: Notification) {
            Log.info("✅ TEXT EDITING BEGAN", category: .fileOperations)
        }
        
        func textDidEndEditing(_ notification: Notification) {
            Log.info("✅ TEXT EDITING ENDED", category: .fileOperations)
            
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
    }
}

// MARK: - Professional Resize Handle (Based on Working ResizeHandleView)
struct ProfessionalResizeHandleView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    let resizeOffset: CGSize
    let zoomLevel: CGFloat
    let onResizeChanged: (DragGesture.Value) -> Void
    let onResizeEnded: () -> Void
    let onResizeStarted: () -> Void // NEW: Track when resize starts
    
    @State private var hasResizeStarted = false  // Track if resize has been initiated
    
    var body: some View {
        Circle()
            .fill(Color.blue)
            .stroke(Color.white, lineWidth: 1.0) // Fixed stroke width - does not scale with zoom
            .frame(width: 8, height: 8) // Fixed UI size - does not scale with artwork (same as other handles)
            .position(
                x: viewModel.textBoxFrame.maxX + dragOffset.width + resizeOffset.width,
                y: viewModel.textBoxFrame.maxY + dragOffset.height + resizeOffset.height
            )
            .gesture(
                DragGesture(minimumDistance: 1)  // IMPROVED: Lower threshold for immediate response
                    .onChanged { value in
                        // IMPROVED: Call onResizeStarted only once when drag first begins
                        if !hasResizeStarted {
                            hasResizeStarted = true
                            onResizeStarted()
                            Log.info("🔵 RESIZE HANDLE STARTED", category: .general)
                        }
                        // RESIZE HANDLE DRAG: \(value.translation)
                        onResizeChanged(value)
                    }
                    .onEnded { _ in 
                        Log.info("🔵 RESIZE HANDLE ENDED", category: .general)
                        hasResizeStarted = false  // Reset for next resize operation
                        onResizeEnded() 
                    }
            )
            .onAppear {
                Log.info("🔵 RESIZE HANDLE VISIBLE at: \(viewModel.textBoxFrame.maxX), \(viewModel.textBoxFrame.maxY)", category: .general)
            }
    }
}

// MARK: - Professional Text View Model (Based on Working TextEditorViewModel)
class ProfessionalTextViewModel: ObservableObject {
    @Published var text: String = "" {
        didSet {
            // NO AUTO-RESIZE: User controls text box size manually like rectangle tool
            // Text content changes don't affect size - only user drag resizing
            // Log.fileOperation("📝 TEXT CONTENT CHANGED: '\(oldValue)' → '\(text)' - no auto-resize", level: .info)
        }
    }
    @Published var fontSize: CGFloat = 24 {
        didSet {
            guard !isUpdatingProperties else { return }
            isUpdatingProperties = true
            
            if selectedFont.pointSize != fontSize {
                let fontName = selectedFont.fontName
                selectedFont = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
            }
            
            isUpdatingProperties = false
            scheduleAutoResize()
        }
    }
    @Published var selectedFont: NSFont = NSFont.systemFont(ofSize: 24) {
        didSet {
            guard !isUpdatingProperties else { return }
            isUpdatingProperties = true
            
            if fontSize != selectedFont.pointSize {
                fontSize = selectedFont.pointSize
            }
            
            isUpdatingProperties = false
            scheduleAutoResize()
        }
    }
    @Published var textBoxFrame: CGRect = CGRect.zero  // FIXED: Start at zero so user-drawn size is used
    @Published var isEditing: Bool = false
    @Published var textAlignment: NSTextAlignment = .left {
        didSet {
            scheduleAutoResize()
        }
    }
    // Line spacing now handled via textObject.typography.lineSpacing
    @Published var autoExpandVertically: Bool = false  // DISABLED: User controls size manually like rectangle tool
    
    // ORIGINAL WORKING PROPERTIES FOR CORE TEXT PATH
    @Published var textPath: CGPath?
    @Published var showPath: Bool = false
    
    var textObject: VectorText {
        didSet {
            // CRITICAL: Force SwiftUI update when textObject changes
            objectWillChange.send()
        }
    }
    let document: VectorDocument
    
    // Flags and properties from working code
    private var isUpdatingProperties: Bool = false
    private var minTextBoxHeight: CGFloat = 50
    
    // THE SOURCE OF TRUTH for cursor position, only updated by user input
    var userInitiatedCursorPosition: Int = 0
    var userInitiatedSelectionLength: Int = 0

    init(textObject: VectorText, document: VectorDocument) {
        self.textObject = textObject
        self.document = document
        
        Log.fileOperation("🔧 INIT ProfessionalTextViewModel for text: '\(textObject.content)' - autoExpandVertically: \(autoExpandVertically)", level: .info)
        
        // Direct initialization from VectorText
        self.text = textObject.content
        self.fontSize = CGFloat(textObject.typography.fontSize)
        self.selectedFont = textObject.typography.nsFont
        self.isEditing = textObject.isEditing
        self.textAlignment = textObject.typography.alignment.nsTextAlignment
        
        // Initialize text box frame with proper bounds
        // CRITICAL FIX: For SVG text (with meaningful bounds), preserve original dimensions
        // For native text (with default bounds), ensure minimum dimensions
        let hasReasonableBounds = textObject.bounds.width > 50 && textObject.bounds.height > 20
        let useMinimum = !hasReasonableBounds // Only use minimum for native text with small bounds
        
        self.textBoxFrame = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: useMinimum ? max(textObject.bounds.width, 200) : textObject.bounds.width,   // Preserve SVG width
            height: useMinimum ? max(textObject.bounds.height, 50) : textObject.bounds.height   // Preserve SVG height
        )
        
        Log.info("📦 TEXT BOX INITIALIZATION: Frame = \(self.textBoxFrame)", category: .general)
        
        // No longer using notifications - font panel updates via document.textObjects changes
    }
    
    // No longer using notifications - cleanup not needed
    
    private func syncFromVectorText() {
        guard let currentTextObject = document.allTextObjects.first(where: { $0.id == textObject.id }) else { return }
        
        // SELECTIVE BLOCKING: Only block content changes during auto-resize, allow other updates
        if isAutoResizing && currentTextObject.content == self.text {
            Log.info("🚫 SYNC PARTIAL BLOCK: Auto-resize in progress, only syncing non-content properties", category: .general)
            // Still sync other properties like colors, fonts, etc.
            self.fontSize = CGFloat(currentTextObject.typography.fontSize)
            self.selectedFont = currentTextObject.typography.nsFont
            self.isEditing = currentTextObject.isEditing
            self.textAlignment = currentTextObject.typography.alignment.nsTextAlignment
            // Line spacing is now handled separately in the typography properties
            return
        }

        self.text = currentTextObject.content
        self.fontSize = CGFloat(currentTextObject.typography.fontSize)
        self.selectedFont = currentTextObject.typography.nsFont

        // CRITICAL FIX: Smart text box frame management
        if textBoxFrame.width == 0 && textBoxFrame.height == 0 {
            // INITIAL CREATION ONLY - use VectorText bounds (user-defined size)
            self.textBoxFrame = CGRect(
                x: currentTextObject.position.x,
                y: currentTextObject.position.y,
                width: max(currentTextObject.bounds.width, 50),   // User-defined width or minimum
                height: max(currentTextObject.bounds.height, 30)  // User-defined height or minimum
            )
            Log.info("📦 TEXT BOX INITIAL CREATION: Using VectorText bounds \(self.textBoxFrame)", category: .general)
        } else {
            // EXISTING TEXT BOX: Sync position, preserve size, but update VectorText bounds to match
            let oldFrame = self.textBoxFrame
            self.textBoxFrame = CGRect(
                x: currentTextObject.position.x,
                y: currentTextObject.position.y,
                width: textBoxFrame.width,   // PRESERVE USER'S WIDTH
                height: textBoxFrame.height  // PRESERVE USER'S HEIGHT
            )
            
            // CRITICAL FIX: If text box frame differs from VectorText bounds, update VectorText
            if oldFrame.width != currentTextObject.bounds.width || oldFrame.height != currentTextObject.bounds.height {
                updateDocumentTextBounds(self.textBoxFrame)
                Log.info("📦 TEXT BOX SYNC: Updated VectorText bounds to match text canvas", category: .general)
            }
        }

        self.isEditing = currentTextObject.isEditing
        self.textAlignment = currentTextObject.typography.alignment.nsTextAlignment
        // Line spacing is now handled separately in the typography properties
    }
    
    // MARK: - PUBLIC method for external syncing
    public func syncFromVectorText(_ textObject: VectorText) {
            // CURSOR PRESERVATION: Prevent text resets that move cursor to end
        
        // SELECTIVE BLOCKING: Only block content changes during auto-resize, allow color/font updates
        if isAutoResizing && textObject.content == self.text {
            Log.info("🚫 SYNC PARTIAL BLOCK: Auto-resize in progress, only syncing non-content properties", category: .general)
            
            // Still sync colors, fonts, and other properties during auto-resize
            let colorChanged = self.textObject.typography.fillColor != textObject.typography.fillColor
            
            self.textObject = textObject  // Update for color changes
            self.fontSize = CGFloat(textObject.typography.fontSize)
            self.selectedFont = textObject.typography.nsFont
            
            // CRITICAL FIX: Don't reset editing state during active typing
            if !self.isEditing {
                self.isEditing = textObject.isEditing
            }
            
            self.textAlignment = textObject.typography.alignment.nsTextAlignment
            // Line spacing is now handled separately in the typography properties
            
            // Force SwiftUI update when colors change
            if colorChanged {
                Log.fileOperation("🎨 COLOR CHANGED during auto-resize: Forcing view refresh", level: .info)
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
            return
        }
        
        // VECTOR APP OPTIMIZATION: Prevent overwriting typed text with empty document text
        let contentChanged = self.text != textObject.content
        let documentContentEmpty = textObject.content.isEmpty
        let viewModelContentNotEmpty = !self.text.isEmpty
        
        // Don't sync content if document is empty but view model has content (user is typing)
        let shouldSyncContent = contentChanged && !(documentContentEmpty && viewModelContentNotEmpty)
        
        let fontChanged = self.fontSize != CGFloat(textObject.typography.fontSize)
        let editingChanged = self.isEditing != textObject.isEditing
        let colorChanged = self.textObject.typography.fillColor != textObject.typography.fillColor
        // Group all typography changes for cleaner code (with precision handling for line height)
        let typographyChanged = (
            self.textObject.typography.alignment != textObject.typography.alignment ||
            self.textObject.typography.fontFamily != textObject.typography.fontFamily ||
            self.textObject.typography.fontWeight != textObject.typography.fontWeight ||
            self.textObject.typography.fontStyle != textObject.typography.fontStyle ||
            abs(self.textObject.typography.lineHeight - textObject.typography.lineHeight) > 0.01 ||
            abs(self.textObject.typography.lineSpacing - textObject.typography.lineSpacing) > 0.01
        )
        
        if !shouldSyncContent && !fontChanged && !editingChanged && !colorChanged && !typographyChanged {
            return // No changes, skip sync
        }
        
        if shouldSyncContent {
            Log.fileOperation("🔄 SYNCING from VectorText: '\(textObject.content)' (was: '\(self.text)') - Color changed: \(colorChanged)", level: .info)
        } else {
            Log.fileOperation("🔄 SYNCING from VectorText: CONTENT SKIPPED (protecting typed text) - Color changed: \(colorChanged)", level: .info)
        }
        
        // Disable auto-resize during sync to prevent loops
        let wasAutoResizing = isAutoResizing
        isAutoResizing = true
        defer { isAutoResizing = wasAutoResizing }
        
        // CRITICAL FIX: Update the textObject reference so SwiftUI Text gets new colors
        self.textObject = textObject
        
        // VECTOR APP OPTIMIZATION: Only update text if content should be synced (protect typed text)
        if shouldSyncContent {
            self.text = textObject.content
            Log.fileOperation("📝 TEXT CONTENT UPDATED: Cursor may be affected", level: .info)
        } else {
            Log.fileOperation("📝 TEXT CONTENT UNCHANGED: Preserving cursor position", level: .info)
        }
        
        self.fontSize = CGFloat(textObject.typography.fontSize)
        self.selectedFont = textObject.typography.nsFont
        
        // CRITICAL FIX: Don't reset editing state during active typing
        // Only sync isEditing if we're not currently editing to prevent focus loss
        if !self.isEditing {
            self.isEditing = textObject.isEditing
        }
        
        // CURSOR POSITIONING: Sync cursor position from VectorText
        if textObject.isEditing && textObject.cursorPosition != self.userInitiatedCursorPosition {
            self.userInitiatedCursorPosition = textObject.cursorPosition
            self.userInitiatedSelectionLength = 0
            Log.info("🎯 CURSOR SYNC: Set userInitiatedCursorPosition = \(textObject.cursorPosition)", category: .general)
        }
        
        self.textAlignment = textObject.typography.alignment.nsTextAlignment
        // Line spacing is now handled separately in the typography properties
        
        // CRITICAL FIX: Force SwiftUI update when any visual properties change
        if colorChanged || typographyChanged {
            let changes = [
                colorChanged ? "color" : nil,
                typographyChanged ? "typography" : nil
            ].compactMap { $0 }.joined(separator: ", ")
            
            Log.fileOperation("🎨 VISUAL PROPERTIES CHANGED: \(changes) - forcing view refresh", level: .info)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        
        // CRITICAL FIX: NEVER override user's manual resize - ONLY sync position
        // Text box size is ENTIRELY controlled by user manual resize and auto-resize
        self.textBoxFrame = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: self.textBoxFrame.width,   // PRESERVE USER'S WIDTH
            height: self.textBoxFrame.height  // PRESERVE USER'S HEIGHT
        )
        
        Log.info("📦 EXTERNAL SYNC: Preserved user text box size, only updated position", category: .general)
    }
    
    // MARK: - USER MANUAL RESIZE SUPPORT
    
    public func updateTextBoxSize(to newFrame: CGRect) {
        Log.info("👤 USER MANUAL RESIZE: \(textBoxFrame) → \(newFrame)", category: .general)
        
        // Update our text box frame
        textBoxFrame = newFrame
        
        // CRITICAL: Update VectorText bounds to match user's manual resize
        // This ensures operations like convert to paths use the actual size
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
            document.textObjects[textIndex].bounds = CGRect(
                x: 0, y: 0,
                width: newFrame.width,
                height: newFrame.height
            )
            
            // Also update position if changed
            document.textObjects[textIndex].position = CGPoint(x: newFrame.origin.x, y: newFrame.origin.y)
            
            Log.fileOperation("📋 UPDATED VECTORTEXT to match manual resize: bounds=\(document.textObjects[textIndex].bounds), position=\(document.textObjects[textIndex].position)", level: .info)
            
            // Force document update
            document.objectWillChange.send()
        }
    }
    
    // MARK: - Working Auto-Resize Logic (FIXED with debouncing)
    
    public var isAutoResizing = false  // Prevent infinite loops
    private var autoResizeWorkItem: DispatchWorkItem?  // DEBOUNCING
    
    public func scheduleAutoResize() {
        guard autoExpandVertically && !isAutoResizing else { 
            Log.info("🚫 AUTO-RESIZE BLOCKED: autoExpandVertically=\(autoExpandVertically), isAutoResizing=\(isAutoResizing)", category: .general)
            return 
        }
        
        Log.info("⏰ SCHEDULING AUTO-RESIZE for text: '\(text)' (length: \(text.count))", category: .general)
        
        // CRITICAL FIX: Cancel previous work item to prevent queue buildup
        autoResizeWorkItem?.cancel()
        
        // Create new work item with debouncing
        let workItem = DispatchWorkItem { [weak self] in
            self?.autoResizeTextBoxHeight()
        }
        autoResizeWorkItem = workItem
        
        // Schedule with debouncing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    private func autoResizeTextBoxHeight() {
        guard autoExpandVertically && !isAutoResizing else { 
            Log.info("🚫 AUTO-RESIZE HEIGHT BLOCKED: autoExpandVertically=\(autoExpandVertically), isAutoResizing=\(isAutoResizing)", category: .general)
            return 
        }
        
        isAutoResizing = true
        defer { isAutoResizing = false }
        
        let requiredHeight = calculateRequiredHeight()
        let newHeight = max(minTextBoxHeight, requiredHeight)
        
        Log.fileOperation("📐 AUTO-RESIZE: Current height: \(textBoxFrame.height)pt, Required: \(requiredHeight)pt, New: \(newHeight)pt", level: .info)
        
        // Only update if height needs to change (using original working threshold)
        if abs(textBoxFrame.height - newHeight) > 0.1 {
            let oldHeight = textBoxFrame.height
            let newFrame = CGRect(
                x: textBoxFrame.minX,
                y: textBoxFrame.minY,
                width: textBoxFrame.width,  // PRESERVE USER'S WIDTH - NEVER CHANGE
                height: newHeight          // ONLY HEIGHT CHANGES
            )
            textBoxFrame = newFrame
            
            Log.info("✅ AUTO-RESIZE VERTICAL: Text box height adjusted from \(oldHeight)pt to \(newHeight)pt (WIDTH PRESERVED: \(textBoxFrame.width)pt)", category: .fileOperations)
            
            // CRITICAL FIX: Update VectorText bounds to match the actual text box size
            // This ensures the document knows the real size for operations like convert to paths
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
                document.textObjects[textIndex].bounds = CGRect(
                    x: 0, y: 0,
                    width: textBoxFrame.width,  // ACTUAL WIDTH matches text box
                    height: newHeight          // ACTUAL HEIGHT matches text box
                )
                Log.fileOperation("📋 UPDATED VECTORTEXT BOUNDS to match text box: \(document.textObjects[textIndex].bounds)", level: .info)
            }
        } else {
            Log.info("⚡ AUTO-RESIZE: Height change too small (\(abs(textBoxFrame.height - newHeight))pt) - skipping", category: .general)
        }
    }
    

    
    private func calculateRequiredHeight() -> CGFloat {
        guard !text.isEmpty else { return minTextBoxHeight }
        
        let fontName = selectedFont.fontName
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = max(0, textObject.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = textObject.typography.lineHeight
        paragraphStyle.maximumLineHeight = textObject.typography.lineHeight
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        let textWidth = textBoxFrame.width
        
        // Use Core Text to get the actual required size
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, 0),
            nil,
            CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
            nil
        )
        
        // Add padding to ensure text fits properly
        return suggestedSize.height + 20
    }
    
    // MARK: - Working Methods from Original
    
    func startEditing() {
        isEditing = true
    }
    
    func stopEditing() {
        isEditing = false
        
        // CRITICAL FIX: Update VectorText bounds when editing finishes
        // This ensures the selection box matches the text canvas when switching to arrow tool
        updateDocumentTextBounds(textBoxFrame)
        Log.fileOperation("🔄 STOP EDITING: Updated VectorText bounds to match text canvas", level: .info)
    }
    
    func updateTextBoxFrame(_ newFrame: CGRect) {
        // CRITICAL: Disable auto-resize during manual resize to prevent conflicts
        isAutoResizing = true
        
        textBoxFrame = newFrame
        
        // CRITICAL FIX: Update VectorText bounds to match actual text box size
        // This ensures the main selection system (blue/red rectangle) matches the text canvas
        updateDocumentTextBounds(newFrame)
        
        Log.fileOperation("🔄 MANUAL RESIZE: Updated text box frame to \(newFrame)", level: .info)
        
        // Re-enable auto-resize after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isAutoResizing = false
        }
    }
    
    public func updateDocumentTextBounds(_ frame: CGRect) {
        // Update the document VectorText position and bounds to match actual text canvas
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
            document.textObjects[textIndex].position = CGPoint(x: frame.minX, y: frame.minY)
            document.textObjects[textIndex].bounds = CGRect(
                x: 0, y: 0, 
                width: frame.width, 
                height: frame.height
            )
            Log.fileOperation("📐 UPDATED VECTORTEXT BOUNDS: position=\(document.textObjects[textIndex].position), bounds=\(document.textObjects[textIndex].bounds)", level: .info)
        }
    }
    
    // MARK: - Convert to Core Text Path (ORIGINAL WORKING CODE)
    
    private func convertToCoreTextPath() {
        let fontName = selectedFont.fontName
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = max(0, textObject.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = textObject.typography.lineHeight
        paragraphStyle.maximumLineHeight = textObject.typography.lineHeight
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Calculate the actual required height to prevent truncation
        let textWidth = textBoxFrame.width
        
        // First, get the suggested height for the text
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, 
            CFRangeMake(0, 0), 
            nil, 
            CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude), 
            nil
        )
        
        // Use the larger of the text box height or the required height to prevent truncation
        let frameHeight = max(textBoxFrame.height, suggestedSize.height + 20)
        
        let frameRect = CGRect(
            x: 0, 
            y: 0, 
            width: textWidth, 
            height: frameHeight
        )
        let framePath = CGPath(rect: frameRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), framePath, nil)
        
        let path = CGMutablePath()
        let lines = CTFrameGetLines(frame)
        let lineCount = CFArrayGetCount(lines)
        
        // Get line origins - CRITICAL for correct positioning
        var lineOrigins = Array<CGPoint>(repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, lineCount), &lineOrigins)
        
        for lineIndex in 0..<lineCount {
            let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex), to: CTLine.self)
            let lineOrigin = lineOrigins[lineIndex]
            
            let runs = CTLineGetGlyphRuns(line)
            let runCount = CFArrayGetCount(runs)
            
            for runIndex in 0..<runCount {
                let run = unsafeBitCast(CFArrayGetValueAtIndex(runs, runIndex), to: CTRun.self)
                let glyphCount = CTRunGetGlyphCount(run)
                
                for glyphIndex in 0..<glyphCount {
                    var glyph = CGGlyph()
                    var position = CGPoint()
                    
                    CTRunGetGlyphs(run, CFRangeMake(glyphIndex, 1), &glyph)
                    CTRunGetPositions(run, CFRangeMake(glyphIndex, 1), &position)
                    
                    if let glyphPath = CTFontCreatePathForGlyph(font, glyph, nil) {
                        // Use EXACT Core Text positioning - no manual line height calculation
                        let glyphX = position.x + lineOrigin.x + textBoxFrame.minX
                        let glyphY = textBoxFrame.minY + (frameRect.height - lineOrigin.y)
                        
                        // Create transform that fixes the upside-down issue
                        var transform = CGAffineTransform(scaleX: 1.0, y: -1.0) // Flip Y axis
                        transform = transform.translatedBy(x: glyphX, y: -glyphY)
                        
                        path.addPath(glyphPath, transform: transform)
                    }
                }
            }
        }
        
        textPath = path
        showPath = true
    }
    
    // PUBLIC method for document conversion - calls the working Core Text method
    func convertToPath() {
        guard !text.isEmpty else { 
            Log.error("❌ CONVERT TO OUTLINES: Cannot convert empty text", category: .error)
            return 
        }
        
        Log.fileOperation("🎯 CONVERTING TO OUTLINES: Using ORIGINAL WORKING Core Text conversion", level: .info)
        
        document.saveToUndoStack()
        
        // Call the working Core Text conversion
        convertToCoreTextPath()
        
        guard let cgPath = textPath else {
            Log.error("❌ CONVERT TO OUTLINES FAILED: No path created", category: .error)
            return
        }
        
        // Convert to VectorShape
        let vectorPath = convertCGPathToVectorPath(cgPath)
        let outlineShape = VectorShape(
            name: "Text Outline: \(text.prefix(20))...",
            path: vectorPath,
            strokeStyle: nil,  // NO STROKES as requested
            fillStyle: FillStyle(
                color: textObject.typography.fillColor,
                opacity: textObject.typography.fillOpacity
            ),
            transform: .identity,
            isGroup: false
        )
        
        // CRITICAL FIX: Handle case where no layer is selected
        let targetLayerIndex: Int
        if let selectedLayerIndex = document.selectedLayerIndex {
            targetLayerIndex = selectedLayerIndex
            Log.fileOperation("🎯 USING SELECTED LAYER: Index \(targetLayerIndex) ('\(document.layers[targetLayerIndex].name)')", level: .info)
        } else {
            // Fallback to first available working layer (skip pasteboard and canvas layers)
            if document.layers.count > 2 {
                targetLayerIndex = 2 // First working layer (index 2)
                document.selectedLayerIndex = targetLayerIndex
                Log.fileOperation("🎯 NO LAYER SELECTED: Using fallback layer index \(targetLayerIndex) ('\(document.layers[targetLayerIndex].name)')", level: .info)
            } else {
                Log.error("❌ CONVERT TO OUTLINES FAILED: No suitable layer available", category: .error)
                return
            }
        }
        
        // Check if target layer is locked
        if document.layers[targetLayerIndex].isLocked {
            Log.error("❌ CONVERT TO OUTLINES FAILED: Target layer '\(document.layers[targetLayerIndex].name)' is locked", category: .error)
            return
        }
        
        // Add to the target layer with unified system support
        document.addShape(outlineShape, to: targetLayerIndex)
        
        Log.info("✅ MULTILINE TEXT CONVERSION COMPLETE: Using original working method", category: .fileOperations)
        Log.fileOperation("🎯 ADDED OUTLINE SHAPE: '\(outlineShape.name)' to layer '\(document.layers[targetLayerIndex].name)'", level: .info)
        
        // Select the converted shape
        document.selectedShapeIDs = [outlineShape.id]
        document.selectedTextIDs.removeAll()
        
        // Remove original text object
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
            let removedText = document.textObjects.remove(at: textIndex)
            Log.info("🗑️ REMOVED ORIGINAL TEXT OBJECT: '\(removedText.content)' (ID: \(removedText.id.uuidString.prefix(8)))", category: .general)
            
            // CRITICAL: Also remove from unified objects system
            document.unifiedObjects.removeAll { unifiedObject in
                if case .shape(let shape) = unifiedObject.objectType, shape.isTextObject {
                    return shape.id == textObject.id
                }
                return false
            }
            Log.info("🗑️ REMOVED FROM UNIFIED OBJECTS: Text object \(textObject.id.uuidString.prefix(8))", category: .general)
        } else {
            Log.error("❌ TEXT REMOVAL FAILED: Could not find text object with ID \(textObject.id.uuidString.prefix(8))", category: .error)
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    // MARK: - Core Graphics Path Conversion Helper
    public func convertCGPathToVectorPath(_ cgPath: CGPath) -> VectorPath {
        var elements: [PathElement] = []
        
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            
            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(Double(point.x), Double(point.y))))
                
            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(Double(point.x), Double(point.y))))
                
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let point = element.points[1]
                elements.append(.quadCurve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control: VectorPoint(Double(control.x), Double(control.y))
                ))
                
            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let point = element.points[2]
                elements.append(.curve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control1: VectorPoint(Double(control1.x), Double(control1.y)),
                    control2: VectorPoint(Double(control2.x), Double(control2.y))
                ))
                
            case .closeSubpath:
                elements.append(.close)
                
            @unknown default:
                break
            }
        }
        
        return VectorPath(elements: elements, isClosed: false)
    }
    
    // MARK: - Text Box Interaction Handler
    func handleTextBoxInteraction(textID: UUID, isDoubleClick: Bool = false, isCornerClick: Bool = false) {
        Log.fileOperation("🎯 TEXT BOX INTERACTION: textID=\(textID.uuidString.prefix(8)), doubleClick=\(isDoubleClick), cornerClick=\(isCornerClick)", level: .info)
        
        guard let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else {
            Log.error("❌ TEXT NOT FOUND: ID \(textID)", category: .error)
            return
        }
        
        let textObject = document.textObjects[textIndex]
        let currentState = textObject.getState(in: document)
        
        Log.fileOperation("📊 CURRENT STATE: \(currentState.description)", level: .info)
        Log.fileOperation("📊 CURRENT TOOL: \(document.currentTool.rawValue)", level: .info)
        
        // Check if text is locked
        if textObject.isLocked {
            Log.info("🚫 TEXT LOCKED: Cannot interact with locked text", category: .general)
            return
        }
        
        // Handle different interaction types
        if isDoubleClick || isCornerClick {
            // Double-click or corner click behavior
            switch currentState {
            case .unselected: // GRAY
                // First select the text
                document.selectedTextIDs = [textID]
                document.selectedShapeIDs.removeAll()
                Log.fileOperation("🎯 SELECTED TEXT: GRAY → GREEN", level: .info)
                
                // If font tool is active and this is a corner click, also start editing
                if document.currentTool == .font && isCornerClick {
                    startEditingText(textID: textID)
                    Log.fileOperation("🎯 CORNER CLICK WITH FONT TOOL: GRAY → GREEN → BLUE", level: .info)
                }
                
            case .selected: // GREEN
                // Double-click on green text field: switch to font tool and start editing
                if isDoubleClick {
                    // Switch to font tool
                    document.currentTool = .font
                    Log.fileOperation("🔧 DOUBLE-CLICK: Switched to font tool", level: .info)
                    
                    // Start editing the text
                    startEditingText(textID: textID)
                    Log.fileOperation("🎯 DOUBLE-CLICK: GREEN → BLUE (switched to font tool)", level: .info)
                } else if document.currentTool == .font {
                    // Single click with font tool active - start editing
                    startEditingText(textID: textID)
                    Log.fileOperation("🎯 START EDITING: GREEN → BLUE", level: .info)
                } else {
                    Log.fileOperation("🎯 FONT TOOL NOT ACTIVE: Staying GREEN", level: .info)
                }
                
            case .editing: // BLUE
                // Already editing - do nothing
                Log.fileOperation("🎯 ALREADY EDITING: Staying BLUE", level: .info)
            }
        } else {
            // Single click behavior
            switch currentState {
            case .unselected: // GRAY
                // Select the text
                document.selectedTextIDs = [textID]
                document.selectedShapeIDs.removeAll()
                Log.fileOperation("🎯 SINGLE CLICK: GRAY → GREEN", level: .info)
                
            case .selected: // GREEN
                // Already selected - no change on single click
                Log.fileOperation("🎯 SINGLE CLICK: Staying GREEN", level: .info)
                
            case .editing: // BLUE
                // Let NSTextView handle clicks during editing
                Log.fileOperation("🎯 SINGLE CLICK: Staying BLUE (NSTextView handles)", level: .info)
            }
        }
    }
    
    // MARK: - Start Editing Helper
    private func startEditingText(textID: UUID, at location: CGPoint = .zero) {
        Log.fileOperation("✏️ STARTING EDIT MODE for textID: \(textID.uuidString.prefix(8)) at location: \(location)", level: .info)
        
        // Stop editing any other text boxes first
        var editingCount = 0
        for textIndex in document.allTextObjects.indices {
            if document.textObjects[textIndex].isEditing {
                document.textObjects[textIndex].isEditing = false
                editingCount += 1
            }
        }
        
        if editingCount > 0 {
            Log.fileOperation("🔄 STOPPED \(editingCount) text box(es) that were in edit mode", level: .info)
        }
        
        // Find and start editing the target text
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
            let textObject = document.textObjects[textIndex]
            
            Log.info("✏️ STARTING EDIT MODE:", category: .general)
            Log.info("  - Text: '\(textObject.content)'", category: .general)
            Log.info("  - Font: \(textObject.typography.fontFamily) \(textObject.typography.fontSize)pt", category: .general)
            Log.info("  - State: GRAY/GREEN → BLUE (editing)", category: .general)
            Log.info("  - Click location: (\(String(format: "%.1f", location.x)), \(String(format: "%.1f", location.y)))", category: .general)
            
            // CRITICAL: Set editing state BEFORE updating selection
            document.textObjects[textIndex].isEditing = true
            
            // Clear other selections and select this text
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs = [textID]
            
            // Calculate cursor position at click location if provided
            if location != .zero {
                let cursorPosition = calculateCursorPosition(in: textObject, at: location)
                
                // CRITICAL: Update the VectorText's cursor position directly
                document.textObjects[textIndex].cursorPosition = cursorPosition
                
                Log.info("🎯 CURSOR POSITIONING: Set cursor position \(cursorPosition) for click at (\(String(format: "%.1f", location.x)), \(String(format: "%.1f", location.y)))", category: .general)
                Log.info("🎯 CURSOR POSITIONING: Updated VectorText.cursorPosition = \(cursorPosition)", category: .general)
            }
            
            Log.info("✅ TEXT EDITING STARTED: Text box \(textID.uuidString.prefix(8)) is now in BLUE (edit) mode", category: .fileOperations)
        } else {
            Log.error("❌ TEXT NOT FOUND: Could not find text with ID \(textID)", category: .error)
        }
    }
    
    // MARK: - Cursor Position Calculation
    private func calculateCursorPosition(in textObj: VectorText, at tapLocation: CGPoint) -> Int {
        // Convert tap location to text-relative coordinates
        let relativePoint = CGPoint(
            x: tapLocation.x - textObj.position.x,
            y: tapLocation.y - textObj.position.y
        )
        
        Log.info("🎯 CURSOR CALC: Tap at (\(String(format: "%.1f", tapLocation.x)), \(String(format: "%.1f", tapLocation.y))), relative (\(String(format: "%.1f", relativePoint.x)), \(String(format: "%.1f", relativePoint.y)))", category: .general)
        
        // Simple cursor positioning: place cursor at the beginning for now
        // This can be enhanced later with more sophisticated text layout analysis
        return 0
    }
}

// MARK: - Custom NSTextView with Disabled Context Menu
class DisabledContextMenuTextView: NSTextView {
    override func menu(for event: NSEvent) -> NSMenu? {
        // Return nil to completely disable the context menu
        return nil
    }
    
    override func rightMouseDown(with event: NSEvent) {
        // Consume right mouse events to prevent context menu
        // Don't call super to prevent the default context menu
    }
}
