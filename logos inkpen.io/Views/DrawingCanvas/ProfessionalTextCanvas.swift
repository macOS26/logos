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
    
    init(document: VectorDocument, textObjectID: UUID) {
        self.document = document
        self.textObjectID = textObjectID
        
        // Create view model ONCE and reuse it
        if let textObject = document.textObjects.first(where: { $0.id == textObjectID }) {
            self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: textObject, document: document))
        } else {
            // Fallback if text object not found
            let fallbackText = VectorText(content: "Missing", typography: TypographyProperties(strokeColor: .black, fillColor: .black))
            self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: fallbackText, document: document))
        }
    }
    
    var body: some View {
        // Update view model when text object changes (without recreating it)
        ProfessionalTextCanvas(document: document, viewModel: viewModel)
            .onAppear {
                updateViewModelFromDocument()
            }
            .onChange(of: document.textObjects) { _, _ in
                updateViewModelFromDocument()
            }
            // FIXED: Use getCurrentTextHash to detect any property changes including colors
            .onChange(of: getCurrentTextHash()) { _, _ in
                updateViewModelFromDocument()
            }
            // Additional fix: Use id to force view refresh when text content changes
            .id("\(textObjectID)-\(getCurrentTextHash())")
    }
    
    private func updateViewModelFromDocument() {
        // Find current text object and sync view model (without recreation)
        if let currentTextObject = document.textObjects.first(where: { $0.id == textObjectID }) {
            viewModel.syncFromVectorText(currentTextObject)
        }
    }
    
    private func getCurrentTextHash() -> String {
        if let currentTextObject = document.textObjects.first(where: { $0.id == textObjectID }) {
            // PROFESSIONAL UX: Stable view while font tool is active
            if document.currentTool == .font {
                // While font tool is active, exclude content to prevent view recreation during typing
                return "font-tool-\(currentTextObject.typography.fillColor)-\(currentTextObject.typography.fontSize)"
            } else {
                // When other tools are active, include content for proper updates
                return "\(currentTextObject.content)-\(currentTextObject.typography.fillColor)-\(currentTextObject.typography.fontSize)-\(currentTextObject.isEditing)"
            }
        }
        return "missing"
    }
}

// MARK: - Professional Text Canvas (Based on Working EditableTextCanvas)
struct ProfessionalTextCanvas: View {
    @ObservedObject var document: VectorDocument
    @ObservedObject var viewModel: ProfessionalTextViewModel
    @State private var isDragging = false
    @State private var isResizing = false
    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero
    @State private var textBoxState: TextBoxState = .gray
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
                onTextBoxSelect: handleTextBoxSelect,
                onTextBoxTap: handleTextBoxTap,
                onDragChanged: handleDragChanged,
                onDragEnded: handleDragEnded
            )
            
            ProfessionalTextDisplayView(
                viewModel: viewModel,
                dragOffset: dragOffset,
                textBoxState: textBoxState
            )
            
            // RESIZE HANDLE ALWAYS VISIBLE
            ProfessionalResizeHandleView(
                viewModel: viewModel,
                dragOffset: dragOffset,
                resizeOffset: resizeOffset,
                onResizeChanged: handleResizeChanged,
                onResizeEnded: handleResizeEnded
            )
        }
        // CRITICAL FIX: Apply the SAME coordinate system as all other objects
        .scaleEffect(document.zoomLevel, anchor: .topLeading)
        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        .onKeyPress(action: handleKeyPress)
        .onChange(of: document.selectedTextIDs) { _, selectedIDs in
            updateTextBoxState(selectedIDs: selectedIDs)
        }
        .onAppear {
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }
        .onChange(of: document.currentTool) { oldTool, newTool in
            // PROFESSIONAL UX: Stop editing when user switches away from font tool
            if oldTool == .font && newTool != .font && viewModel.isEditing {
                print("🔧 TOOL CHANGE: Stopping text editing (switched from \(oldTool.rawValue) to \(newTool.rawValue))")
                viewModel.stopEditing()
                
                // Update document editing state
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == viewModel.textObject.id }) {
                    document.textObjects[textIndex].isEditing = false
                }
                
                textBoxState = .gray
            }
        }
    }
    
    // MARK: - State Management (From Working Code)
    
    private func updateTextBoxState(selectedIDs: Set<UUID>) {
        let oldState = textBoxState
        
        // PROFESSIONAL UX: Keep editing active while font tool is selected
        let isTextToolActive = document.currentTool == .font
        let hasTextViewFocus = NSApp.keyWindow?.firstResponder is NSTextView
        let isThisTextSelected = selectedIDs.contains(viewModel.textObject.id)
        
        if (viewModel.isEditing || hasTextViewFocus) && isTextToolActive {
            textBoxState = .blue
        } else if isThisTextSelected && isTextToolActive {
            textBoxState = .green
        } else if isThisTextSelected {
            textBoxState = .green
        } else {
            textBoxState = .gray
        }
        
        if oldState != textBoxState {
            print("🎯 TEXT BOX STATE CHANGE: \(oldState) → \(textBoxState) for text: '\(viewModel.text)' (tool: \(document.currentTool.rawValue), focus: \(hasTextViewFocus))")
        }
    }
    
    // MARK: - Event Handlers (Exact from Working Code)
    
    private func handleTextBoxSelect(location: CGPoint) {
        // SINGLE CLICK: Only allowed when GRAY
        if textBoxState == .gray {
            textBoxState = .green
            // Update document selection
            document.selectedTextIDs = [viewModel.textObject.id]
            document.selectedShapeIDs.removeAll()
        }
    }
    
    private func handleTextBoxTap(location: CGPoint) {
        // DOUBLE CLICK: Start editing if font tool is active
        if textBoxState == .green && document.currentTool == .font {
            textBoxState = .blue
            viewModel.startEditing()
            // Update document editing state
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == viewModel.textObject.id }) {
                document.textObjects[textIndex].isEditing = true
            }
        } else if document.currentTool == .font {
            // If font tool is active but not selected, select first then start editing
            document.selectedTextIDs = [viewModel.textObject.id]
            document.selectedShapeIDs.removeAll()
            textBoxState = .blue
            viewModel.startEditing()
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == viewModel.textObject.id }) {
                document.textObjects[textIndex].isEditing = true
            }
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
            // Update document position
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == viewModel.textObject.id }) {
                document.textObjects[textIndex].position = CGPoint(x: newFrame.minX, y: newFrame.minY)
            }
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
            x: viewModel.textBoxFrame.minX,  // DON'T move position when resizing
            y: viewModel.textBoxFrame.minY,  // DON'T move position when resizing
            width: max(100, viewModel.textBoxFrame.width + resizeOffset.width),
            height: max(50, viewModel.textBoxFrame.height + resizeOffset.height)
        )
        
        print("🔄 RESIZE ENDED: Old frame: \(viewModel.textBoxFrame), New frame: \(newFrame)")
        
        viewModel.updateTextBoxFrame(newFrame)
        resizeOffset = .zero
        dragOffset = .zero
        isResizing = false
        isDragging = false
    }
    
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard viewModel.isEditing else { return .ignored }
        
        // ESC key exits editing mode
        if keyPress.key == .escape {
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
    let onTextBoxSelect: (CGPoint) -> Void
    let onTextBoxTap: (CGPoint) -> Void
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
            .frame(
                width: viewModel.textBoxFrame.width + resizeOffset.width,
                height: viewModel.textBoxFrame.height + resizeOffset.height
            )
            .position(
                x: viewModel.textBoxFrame.minX + dragOffset.width + (viewModel.textBoxFrame.width + resizeOffset.width) / 2,
                y: viewModel.textBoxFrame.minY + dragOffset.height + (viewModel.textBoxFrame.height + resizeOffset.height) / 2
            )
            .highPriorityGesture(
                TapGesture(count: 2)
                    .onEnded { 
                        onTextBoxTap(CGPoint.zero)
                    }
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged(onDragChanged)
                    .onEnded { _ in onDragEnded() }
            )
            .onTapGesture(count: 1) { location in
                onTextBoxSelect(location)
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
        if textBoxState == .blue {
            // BLUE STATE: Use NSTextView for editing - LOCK WIDTH, ALLOW HEIGHT TO EXPAND
            ProfessionalUniversalTextView(viewModel: viewModel)
                .frame(
                    width: viewModel.textBoxFrame.width,     // FIXED WIDTH - NEVER CHANGES
                    height: viewModel.textBoxFrame.height,   // CURRENT HEIGHT (will auto-expand)
                    alignment: .topLeading
                )
                .clipped()  // CRITICAL: Clip any overflow to prevent horizontal expansion
        } else {
            // GRAY/GREEN STATE: Use SwiftUI Text (allows gestures to pass through)
            ProfessionalSwiftUITextView(viewModel: viewModel)
                .frame(
                    width: viewModel.textBoxFrame.width,     // FIXED WIDTH - NEVER CHANGES
                    height: viewModel.textBoxFrame.height,   // CURRENT HEIGHT
                    alignment: .topLeading
                )
                .clipped()  // CRITICAL: Clip any overflow to prevent horizontal expansion
        }
    }
}

// MARK: - Professional SwiftUI Text View (Based on Working SwiftUITextView)
struct ProfessionalSwiftUITextView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    
    private var swiftUIAlignment: HorizontalAlignment {
        switch viewModel.textAlignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        case .justified: return .leading
        default: return .leading
        }
    }
    
    var body: some View {
        VStack(alignment: swiftUIAlignment, spacing: 0) {
            Text(viewModel.text)
                .font(Font.custom(viewModel.selectedFont.fontName, size: viewModel.fontSize))
                .foregroundColor(viewModel.textObject.typography.fillColor.color) // Use VectorColor
                .lineSpacing(viewModel.lineSpacing)
                .multilineTextAlignment(
                    viewModel.textAlignment == .justified ? .leading :
                    (viewModel.textAlignment == .left ? .leading :
                     viewModel.textAlignment == .center ? .center : .trailing)
                )
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: swiftUIAlignment, vertical: .top))
            Spacer()
        }
        .allowsHitTesting(false) // CRITICAL: allows gestures to pass through!
    }
}

// MARK: - Professional Universal Text View (Based on Working UniversalTextView)
struct ProfessionalUniversalTextView: NSViewRepresentable {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    @State var isUpdatingFromTyping: Bool = false  // Prevents NSTextView reset during typing
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        
        // CRITICAL: Configure NSTextView to NEVER grow horizontally, only wrap text
        textView.isEditable = viewModel.isEditing
        textView.isSelectable = true
        textView.backgroundColor = NSColor.clear
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        
                // CRITICAL: Configure for FIXED WIDTH, VERTICAL EXPANSION ONLY
        let fixedWidth = viewModel.textBoxFrame.width
        
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
            height: viewModel.textBoxFrame.height
        )
        
        // CRITICAL: Force word wrapping at fixed width
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.maxSize = NSSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: fixedWidth, height: 50)
        
        print("📏 NSTextView CONFIGURED: Fixed width=\(fixedWidth)pt for text: '\(viewModel.text)'")
        
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        textView.delegate = context.coordinator  // CRITICAL: Set delegate to capture text changes
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        
        // CRITICAL FIX: Set initial text and appearance directly on NSTextView
        textView.string = viewModel.text
        textView.insertionPointColor = NSColor(viewModel.textObject.typography.fillColor.color)
        textView.font = viewModel.selectedFont
        textView.textColor = NSColor(viewModel.textObject.typography.fillColor.color)
        
        // First responder will be set in updateNSView when needed
        
        return textView
    }
    

    
    func updateNSView(_ nsView: NSTextView, context: Context) {
        // CRITICAL: Preserve cursor position using coordinator pattern
        let coordinator = context.coordinator
        
        // CRITICAL FIX: Only update NSTextView text when NOT actively typing
        // This prevents cursor jumping and text resets during typing
        if !isUpdatingFromTyping && nsView.string != viewModel.text {
            nsView.string = viewModel.text
        }
        
        // ALWAYS update font and color directly on NSTextView (this is visible immediately)
        nsView.font = viewModel.selectedFont
        nsView.textColor = NSColor(viewModel.textObject.typography.fillColor.color)
        nsView.insertionPointColor = NSColor(viewModel.textObject.typography.fillColor.color)
        
        // CRITICAL: Restore selection ONLY if coordinator has stored ranges
        if coordinator.selectedRanges.count > 0 {
            nsView.selectedRanges = coordinator.selectedRanges
        }
        
        // Configure text view properties
        nsView.isEditable = viewModel.isEditing
        
        // CRITICAL FIX: Always set solid insertion point color and ensure visibility
        let textColor = NSColor(viewModel.textObject.typography.fillColor.color)
        nsView.insertionPointColor = textColor
        
        // Force cursor to be visible if text view is first responder
        if nsView.window?.firstResponder == nsView {
            nsView.setNeedsDisplay(nsView.visibleRect)
        }
        
        // Set frame constraints
        nsView.frame = CGRect(
            x: 0, y: 0,
            width: viewModel.textBoxFrame.width,
            height: max(viewModel.textBoxFrame.height, 100)
        )
        
        nsView.maxSize = NSSize(
            width: viewModel.textBoxFrame.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        nsView.minSize = NSSize(
            width: viewModel.textBoxFrame.width,
            height: 30
        )
        
        // AGGRESSIVE: Ensure NSTextView maintains first responder during editing
        if viewModel.isEditing {
            if nsView.window?.firstResponder != nsView {
                nsView.window?.makeFirstResponder(nsView)
            }
            // Also ensure it can accept first responder
            if !nsView.acceptsFirstResponder {
                print("⚠️ NSTextView refusing first responder!")
            }
        }
        
        // Force layout update
        nsView.needsLayout = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ProfessionalUniversalTextView
        var selectedRanges: [NSValue] = []
        
        init(_ parent: ProfessionalUniversalTextView) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // CRITICAL: Capture selection BEFORE updating parent
            self.selectedRanges = textView.selectedRanges
            
            let newText = textView.string
            
            // Only update if text actually changed to prevent loops
            guard newText != parent.viewModel.text else {
                return
            }
            
            // CRITICAL FIX: Update both view model and document, but prevent NSTextView reset
            parent.isUpdatingFromTyping = true
            parent.viewModel.text = newText
            parent.viewModel.document.updateTextContent(parent.viewModel.textObject.id, content: newText)
            
            // Reset flag after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
                parent.isUpdatingFromTyping = false
            }
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            // Text editing began - could add additional logic here if needed
        }
        
        func textDidEndEditing(_ notification: Notification) {
            // Text editing ended - reset any flags
            parent.isUpdatingFromTyping = false
        }
    }
}

// MARK: - Professional Resize Handle (Based on Working ResizeHandleView)
struct ProfessionalResizeHandleView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    let resizeOffset: CGSize
    let onResizeChanged: (DragGesture.Value) -> Void
    let onResizeEnded: () -> Void
    
    var body: some View {
        Circle()
            .fill(Color.blue)
            .stroke(Color.white, lineWidth: 1)
            .frame(width: 12, height: 12) // Made slightly bigger and more visible
            .position(
                x: viewModel.textBoxFrame.maxX + dragOffset.width + resizeOffset.width,
                y: viewModel.textBoxFrame.maxY + dragOffset.height + resizeOffset.height
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        print("🔵 RESIZE HANDLE DRAG: \(value.translation)")
                        onResizeChanged(value)
                    }
                    .onEnded { _ in 
                        print("🔵 RESIZE HANDLE ENDED")
                        onResizeEnded() 
                    }
            )
            .onAppear {
                print("🔵 RESIZE HANDLE VISIBLE at: \(viewModel.textBoxFrame.maxX), \(viewModel.textBoxFrame.maxY)")
            }
    }
}

// MARK: - Professional Text View Model (Based on Working TextEditorViewModel)
class ProfessionalTextViewModel: ObservableObject {
    @Published var text: String = "Text" {
        didSet {
            // NO AUTO-RESIZE: User controls text box size manually like rectangle tool
            // Text content changes don't affect size - only user drag resizing
            print("📝 TEXT CONTENT CHANGED: '\(oldValue)' → '\(text)' - no auto-resize")
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
    @Published var lineSpacing: CGFloat = 0.0 {
        didSet {
            scheduleAutoResize()
        }
    }
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
    
    init(textObject: VectorText, document: VectorDocument) {
        self.textObject = textObject
        self.document = document
        
        print("🔧 INIT ProfessionalTextViewModel for text: '\(textObject.content)' - autoExpandVertically: \(autoExpandVertically)")
        
        // Sync from VectorText
        syncFromVectorText()
        
        // Listen for FontPanel updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VectorTextUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔔 FONT PANEL UPDATE: Syncing text properties")
            self?.syncFromVectorText()
            // Force SwiftUI update to refresh NSTextView
            self?.objectWillChange.send()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func syncFromVectorText() {
        guard let currentTextObject = document.textObjects.first(where: { $0.id == textObject.id }) else { return }
        
        // SELECTIVE BLOCKING: Only block content changes during auto-resize, allow other updates
        if isAutoResizing && currentTextObject.content == self.text {
            print("🚫 SYNC PARTIAL BLOCK: Auto-resize in progress, only syncing non-content properties")
            // Still sync other properties like colors, fonts, etc.
            self.fontSize = CGFloat(currentTextObject.typography.fontSize)
            self.selectedFont = currentTextObject.typography.nsFont
            self.isEditing = currentTextObject.isEditing
            self.textAlignment = currentTextObject.typography.alignment.nsTextAlignment
            self.lineSpacing = CGFloat(currentTextObject.typography.lineHeight - currentTextObject.typography.fontSize)
            return
        }

        self.text = currentTextObject.content
        self.fontSize = CGFloat(currentTextObject.typography.fontSize)
        self.selectedFont = currentTextObject.typography.nsFont

        // CRITICAL FIX: NEVER sync size from VectorText - ONLY sync position and ONLY if not manually positioned
        // The text box frame is ENTIRELY managed by the view model after creation
        if textBoxFrame.width == 0 && textBoxFrame.height == 0 {
            // INITIAL CREATION ONLY - use VectorText bounds (user-defined size)
            self.textBoxFrame = CGRect(
                x: currentTextObject.position.x,
                y: currentTextObject.position.y,
                width: max(currentTextObject.bounds.width, 50),   // User-defined width or minimum
                height: max(currentTextObject.bounds.height, 30)  // User-defined height or minimum
            )
            print("📦 TEXT BOX INITIAL CREATION: Using VectorText bounds \(self.textBoxFrame)")
        } else {
            // EXISTING TEXT BOX: ONLY sync position, NEVER size
            self.textBoxFrame = CGRect(
                x: currentTextObject.position.x,
                y: currentTextObject.position.y,
                width: textBoxFrame.width,   // PRESERVE USER'S WIDTH
                height: textBoxFrame.height  // PRESERVE USER'S HEIGHT
            )
            print("📦 TEXT BOX SYNC: Preserved user size, only updated position")
        }

        self.isEditing = currentTextObject.isEditing
        self.textAlignment = currentTextObject.typography.alignment.nsTextAlignment
        self.lineSpacing = CGFloat(currentTextObject.typography.lineHeight - currentTextObject.typography.fontSize)
    }
    
    // MARK: - PUBLIC method for external syncing
    public func syncFromVectorText(_ textObject: VectorText) {
        // SELECTIVE BLOCKING: Only block content changes during auto-resize, allow color/font updates
        if isAutoResizing && textObject.content == self.text {
            print("🚫 SYNC PARTIAL BLOCK: Auto-resize in progress, only syncing non-content properties")
            
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
            self.lineSpacing = CGFloat(textObject.typography.lineHeight - textObject.typography.fontSize)
            
            // Force SwiftUI update when colors change
            if colorChanged {
                print("🎨 COLOR CHANGED during auto-resize: Forcing view refresh")
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
            return
        }
        
        // CRITICAL: Don't sync if content hasn't actually changed (BUT always sync colors)
        let contentChanged = self.text != textObject.content
        let fontChanged = self.fontSize != CGFloat(textObject.typography.fontSize)
        let editingChanged = self.isEditing != textObject.isEditing
        let colorChanged = self.textObject.typography.fillColor != textObject.typography.fillColor
        
        if !contentChanged && !fontChanged && !editingChanged && !colorChanged {
            return // No changes, skip sync
        }
        
        print("🔄 SYNCING from VectorText: '\(textObject.content)' (was: '\(self.text)') - Color changed: \(colorChanged)")
        
        // Disable auto-resize during sync to prevent loops
        let wasAutoResizing = isAutoResizing
        isAutoResizing = true
        defer { isAutoResizing = wasAutoResizing }
        
        // CRITICAL FIX: Update the textObject reference so SwiftUI Text gets new colors
        self.textObject = textObject
        
        self.text = textObject.content
        self.fontSize = CGFloat(textObject.typography.fontSize)
        self.selectedFont = textObject.typography.nsFont
        
        // CRITICAL FIX: Don't reset editing state during active typing
        // Only sync isEditing if we're not currently editing to prevent focus loss
        if !self.isEditing {
            self.isEditing = textObject.isEditing
        }
        
        self.textAlignment = textObject.typography.alignment.nsTextAlignment
        self.lineSpacing = CGFloat(textObject.typography.lineHeight - textObject.typography.fontSize)
        
        // CRITICAL FIX: Force SwiftUI update when colors change
        if colorChanged {
            print("🎨 COLOR CHANGED: Forcing view refresh for color update")
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
        
        print("📦 EXTERNAL SYNC: Preserved user text box size, only updated position")
    }
    
    // MARK: - USER MANUAL RESIZE SUPPORT
    
    public func updateTextBoxSize(to newFrame: CGRect) {
        print("👤 USER MANUAL RESIZE: \(textBoxFrame) → \(newFrame)")
        
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
            
            print("📋 UPDATED VECTORTEXT to match manual resize: bounds=\(document.textObjects[textIndex].bounds), position=\(document.textObjects[textIndex].position)")
            
            // Force document update
            document.objectWillChange.send()
        }
    }
    
    // MARK: - Working Auto-Resize Logic (FIXED with debouncing)
    
    public var isAutoResizing = false  // Prevent infinite loops
    private var autoResizeWorkItem: DispatchWorkItem?  // DEBOUNCING
    
    public func scheduleAutoResize() {
        guard autoExpandVertically && !isAutoResizing else { 
            print("🚫 AUTO-RESIZE BLOCKED: autoExpandVertically=\(autoExpandVertically), isAutoResizing=\(isAutoResizing)")
            return 
        }
        
        print("⏰ SCHEDULING AUTO-RESIZE for text: '\(text)' (length: \(text.count))")
        
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
            print("🚫 AUTO-RESIZE HEIGHT BLOCKED: autoExpandVertically=\(autoExpandVertically), isAutoResizing=\(isAutoResizing)")
            return 
        }
        
        isAutoResizing = true
        defer { isAutoResizing = false }
        
        let requiredHeight = calculateRequiredHeight()
        let newHeight = max(minTextBoxHeight, requiredHeight)
        
        print("📐 AUTO-RESIZE: Current height: \(textBoxFrame.height)pt, Required: \(requiredHeight)pt, New: \(newHeight)pt")
        
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
            
            print("✅ AUTO-RESIZE VERTICAL: Text box height adjusted from \(oldHeight)pt to \(newHeight)pt (WIDTH PRESERVED: \(textBoxFrame.width)pt)")
            
            // CRITICAL FIX: Update VectorText bounds to match the actual text box size
            // This ensures the document knows the real size for operations like convert to paths
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
                document.textObjects[textIndex].bounds = CGRect(
                    x: 0, y: 0,
                    width: textBoxFrame.width,  // ACTUAL WIDTH matches text box
                    height: newHeight          // ACTUAL HEIGHT matches text box
                )
                print("📋 UPDATED VECTORTEXT BOUNDS to match text box: \(document.textObjects[textIndex].bounds)")
            }
        } else {
            print("⚡ AUTO-RESIZE: Height change too small (\(abs(textBoxFrame.height - newHeight))pt) - skipping")
        }
    }
    
    private func calculateRequiredHeight() -> CGFloat {
        guard !text.isEmpty else { return minTextBoxHeight }
        
        let fontName = selectedFont.fontName
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = lineSpacing
        
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
    }
    
    func updateTextBoxFrame(_ newFrame: CGRect) {
        // CRITICAL: Disable auto-resize during manual resize to prevent conflicts
        isAutoResizing = true
        
        textBoxFrame = newFrame
        
        // Update the document VectorText position and bounds
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
            document.textObjects[textIndex].position = CGPoint(x: newFrame.minX, y: newFrame.minY)
            document.textObjects[textIndex].bounds = CGRect(
                x: 0, y: 0, 
                width: newFrame.width, 
                height: newFrame.height
            )
        }
        
        print("🔄 MANUAL RESIZE: Updated text box frame to \(newFrame)")
        
        // Re-enable auto-resize after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isAutoResizing = false
        }
    }
    
    // MARK: - Convert to Core Text Path (ORIGINAL WORKING CODE)
    
    private func convertToCoreTextPath() {
        let fontName = selectedFont.fontName
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        
        // Create paragraph style with alignment and line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = lineSpacing
        
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
            print("❌ CONVERT TO OUTLINES: Cannot convert empty text")
            return 
        }
        
        print("🎯 CONVERTING TO OUTLINES: Using ORIGINAL WORKING Core Text conversion")
        
        document.saveToUndoStack()
        
        // Call the working Core Text conversion
        convertToCoreTextPath()
        
        guard let cgPath = textPath else {
            print("❌ CONVERT TO OUTLINES FAILED: No path created")
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
        
        // Add to the current layer
        if let layerIndex = document.selectedLayerIndex {
            document.layers[layerIndex].addShape(outlineShape)
            
            print("✅ MULTILINE TEXT CONVERSION COMPLETE: Using original working method")
            
            // Select the converted shape
            document.selectedShapeIDs = [outlineShape.id]
            document.selectedTextIDs.removeAll()
            
            // Remove original text object
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
                document.textObjects.remove(at: textIndex)
                print("🗑️ REMOVED ORIGINAL TEXT OBJECT")
            }
        }
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
} 
