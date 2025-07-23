//
//  ProfessionalTextCanvas.swift
//  logos inkpen.io
//
//  Professional text editing using the proven working NewTextBoxFontTool approach
//  Adapted for VectorText and VectorColor systems with existing FontPanel integration
//

import SwiftUI
import CoreText

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
    }
    
    // MARK: - State Management (From Working Code)
    
    private func updateTextBoxState(selectedIDs: Set<UUID>) {
        let oldState = textBoxState
        if viewModel.textObject.isEditing {
            textBoxState = .blue
        } else if selectedIDs.contains(viewModel.textObject.id) {
            textBoxState = .green
        } else {
            textBoxState = .gray
        }
        
        if oldState != textBoxState {
            print("🎯 TEXT BOX STATE CHANGE: \(oldState) → \(textBoxState) for text: '\(viewModel.text)'")
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
        // DOUBLE CLICK: Only allowed when GREEN
        if textBoxState == .green {
            textBoxState = .blue
            viewModel.startEditing()
            // Update document editing state
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
        
        context.coordinator.textView = textView
        textView.delegate = context.coordinator  // CRITICAL: Set delegate to capture text changes
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        
        return textView
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
        // CRITICAL: Don't interfere with cursor when user is actively editing
        let isFirstResponder = nsView.window?.firstResponder == nsView
        let userIsTyping = viewModel.isEditing && isFirstResponder
        
        // Control text input and selection based on editing state
        nsView.isEditable = viewModel.isEditing
        nsView.isSelectable = viewModel.isEditing  // Only selectable when editing
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = viewModel.textAlignment
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
        
        // CRITICAL: Convert VectorColor to NSColor for NSTextView
        let textColor = NSColor(viewModel.textObject.typography.fillColor.color)
        print("🎨 FONT COLOR UPDATE: VectorColor -> NSColor: \(textColor)")
        
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: viewModel.selectedFont.fontName, size: viewModel.fontSize) ?? NSFont.systemFont(ofSize: viewModel.fontSize),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        // For justified text, add word spacing control
        if viewModel.textAlignment == .justified {
            // Limit expansion to prevent excessive word spacing
            attributes[.expansion] = 0.0 // No character expansion
        }
        
        // CRITICAL: Always update text attributes to reflect color/font changes
        let currentSelection = nsView.selectedRange()
        
        if nsView.string != viewModel.text && !userIsTyping {
            let attributedString = NSAttributedString(string: viewModel.text, attributes: attributes)
            nsView.textStorage?.setAttributedString(attributedString)
        } else {
            // ALWAYS update attributes to reflect color/font changes
            let range = NSRange(location: 0, length: nsView.string.count)
            nsView.textStorage?.setAttributes(attributes, range: range)
        }
        
        // RESTORE cursor position after attribute updates
        if !userIsTyping && currentSelection.location <= nsView.string.count {
            nsView.setSelectedRange(currentSelection)
        }
        
        // CRITICAL: Enforce fixed width, unlimited height for text flow
        nsView.textContainer?.containerSize = NSSize(
            width: viewModel.textBoxFrame.width,     // FIXED WIDTH - NEVER CHANGES
            height: CGFloat.greatestFiniteMagnitude  // UNLIMITED HEIGHT for wrapping
        )
        
        // CRITICAL: Enforce frame constraints to prevent horizontal expansion
        nsView.frame = CGRect(
            x: 0, y: 0,
            width: viewModel.textBoxFrame.width,     // FIXED WIDTH - NEVER CHANGES
            height: viewModel.textBoxFrame.height    // Current height
        )
        
        // CRITICAL: Enforce size constraints
        nsView.maxSize = NSSize(
            width: viewModel.textBoxFrame.width,     // MAX WIDTH = FIXED WIDTH
            height: CGFloat.greatestFiniteMagnitude  // UNLIMITED HEIGHT
        )
        nsView.minSize = NSSize(
            width: viewModel.textBoxFrame.width,     // MIN WIDTH = FIXED WIDTH
            height: 50                              // MIN HEIGHT
        )
        
        // For justified text, ensure proper layout manager settings
        if viewModel.textAlignment == .justified {
            nsView.layoutManager?.allowsNonContiguousLayout = false // Force sequential layout for better justification
        }
        
        // DIRECT STATE MONITORING - ONLY when user is typing
        // Check if text changed and update viewModel directly (but only if user is actively typing)
        if nsView.string != viewModel.text && userIsTyping {
            // NSTextView text changed by user typing - update our state
            let newText = nsView.string
            
            print("📝 TEXT CHANGED in NSTextView: '\(newText)' (was: '\(viewModel.text)')")
            
            // Update viewModel.text FIRST to trigger auto-resize
            viewModel.text = newText
            
            // Update document
            viewModel.document.updateTextContent(viewModel.textObject.id, content: newText)
            
            // DON'T restore cursor - let NSTextView manage it naturally
        }
        
        // Force layout update
        nsView.layoutManager?.ensureLayout(for: nsView.textContainer!)
        
        // Ensure the text view becomes first responder when editing starts (but don't interfere if already active)
        if viewModel.isEditing && !isFirstResponder {
            // Only become first responder if we're not already
            nsView.window?.makeFirstResponder(nsView)
        }
        
        // Update cursor color if text color changed (preserve cursor position)
        let newCursorColor = NSColor(viewModel.textObject.typography.fillColor.color)
        if nsView.insertionPointColor != newCursorColor {
            // PRESERVE cursor position when updating color
            let currentSelection = nsView.selectedRange()
            nsView.insertionPointColor = newCursorColor
            // Restore cursor position after color change
            if userIsTyping && currentSelection.location <= nsView.string.count {
                nsView.setSelectedRange(currentSelection)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ProfessionalUniversalTextView
        weak var textView: NSTextView?
        
        init(_ parent: ProfessionalUniversalTextView) {
            self.parent = parent
        }
        
        // CRITICAL: Capture text changes immediately for auto-resize
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { 
                print("❌ textDidChange: Not an NSTextView")
                return 
            }
            let newText = textView.string
            
            print("📝 TEXT DID CHANGE (Delegate): '\(newText)' (was: '\(parent.viewModel.text)')")
            
            // YOUR BRILLIANT IDEA: Monitor NSTextView height and make text box that height
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? CGRect.zero
            let requiredHeight = usedRect.height
            let newHeight = max(50, requiredHeight + 20) // Add padding
            
            print("📏 NSTextView MEASUREMENTS:")
            print("   - Used Rect: \(usedRect)")
            print("   - Required Height: \(requiredHeight)pt")
            print("   - New Height (with padding): \(newHeight)pt")
            print("   - Current Frame: \(parent.viewModel.textBoxFrame)")
            
            // Update viewModel immediately
            DispatchQueue.main.async {
                // Prevent auto-resize conflicts during manual changes
                self.parent.viewModel.isAutoResizing = true
                
                self.parent.viewModel.text = newText
                
                // Update text box height based on NSTextView's actual height
                let currentFrame = self.parent.viewModel.textBoxFrame
                let newFrame = CGRect(
                    x: currentFrame.minX,
                    y: currentFrame.minY,
                    width: currentFrame.width,  // Keep width fixed
                    height: newHeight          // Use NSTextView's required height
                )
                
                print("📐 UPDATING FRAME: \(currentFrame) → \(newFrame)")
                self.parent.viewModel.textBoxFrame = newFrame
                
                // Update document
                self.parent.viewModel.document.updateTextContent(self.parent.viewModel.textObject.id, content: newText)
                
                // Update document bounds
                if let textIndex = self.parent.viewModel.document.textObjects.firstIndex(where: { $0.id == self.parent.viewModel.textObject.id }) {
                    self.parent.viewModel.document.textObjects[textIndex].bounds = CGRect(
                        x: 0, y: 0, 
                        width: currentFrame.width, 
                        height: newHeight
                    )
                    print("📋 UPDATED DOCUMENT BOUNDS: \(self.parent.viewModel.document.textObjects[textIndex].bounds)")
                }
                
                // Re-enable auto-resize after changes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.parent.viewModel.isAutoResizing = false
                }
            }
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
            // CRITICAL: Only auto-resize if text actually changed and auto-expand is enabled
            if oldValue != text && autoExpandVertically && !isAutoResizing {
                scheduleAutoResize()
            }
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
    @Published var textBoxFrame: CGRect = CGRect(x: 50, y: 50, width: 300, height: 100)
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
    @Published var autoExpandVertically: Bool = true
    
    let textObject: VectorText
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
        
        // CRITICAL: Don't sync during auto-resize to prevent height conflicts
        guard !isAutoResizing else { return }
        
        self.text = currentTextObject.content
        self.fontSize = CGFloat(currentTextObject.typography.fontSize)
        self.selectedFont = currentTextObject.typography.nsFont
        
        // CRITICAL: Text boxes have FIXED width, and we manage height separately
        let fixedWidth: CGFloat = 300  // DEFAULT FIXED WIDTH FOR TEXT BOXES
        
        // ONLY sync height if we don't have a current height (initial setup)
        let currentHeight = textBoxFrame.height > 0 ? textBoxFrame.height : max(currentTextObject.bounds.height, 100)
        
        self.textBoxFrame = CGRect(
            x: currentTextObject.position.x,
            y: currentTextObject.position.y,
            width: fixedWidth,    // ALWAYS FIXED WIDTH
            height: currentHeight // PRESERVE CURRENT HEIGHT - don't sync from VectorText
        )
        
        self.isEditing = currentTextObject.isEditing
        self.textAlignment = currentTextObject.typography.alignment.nsTextAlignment
        self.lineSpacing = CGFloat(currentTextObject.typography.lineHeight - currentTextObject.typography.fontSize)
    }
    
    // MARK: - Working Auto-Resize Logic (Exact from Working Code)
    
    public var isAutoResizing = false  // Prevent infinite loops
    
    private func scheduleAutoResize() {
        guard autoExpandVertically && !isAutoResizing else { 
            print("🚫 AUTO-RESIZE BLOCKED: autoExpandVertically=\(autoExpandVertically), isAutoResizing=\(isAutoResizing)")
            return 
        }
        
        print("⏰ SCHEDULING AUTO-RESIZE for text: '\(text)' (length: \(text.count))")
        
        // Debounce multiple resize requests
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.autoResizeTextBoxHeight()
        }
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
                width: textBoxFrame.width,  // FIXED WIDTH - NEVER CHANGES
                height: newHeight          // ONLY HEIGHT CHANGES
            )
            textBoxFrame = newFrame
            
            print("✅ AUTO-RESIZE VERTICAL: Text box height adjusted from \(oldHeight)pt to \(newHeight)pt (WIDTH STAYS: \(textBoxFrame.width)pt)")
            
            // Update document bounds - use minimal width for VectorText, height for layout
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
                document.textObjects[textIndex].bounds = CGRect(
                    x: 0, y: 0,
                    width: 100,               // MINIMAL WIDTH for VectorText (text box manages actual width)
                    height: newHeight         // ACTUAL HEIGHT for layout
                )
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
    
        // MARK: - Convert to Outlines (YOUR EXACT MULTI-LINE CORE TEXT IMPLEMENTATION)
    
    func convertToPath() {
        guard !text.isEmpty else { 
            print("❌ CONVERT TO OUTLINES: Cannot convert empty text")
            return 
        }
        
        print("🎯 CONVERTING TO OUTLINES: Using YOUR multi-line Core Text implementation")
        
        // YOUR EXACT WORKING IMPLEMENTATION FROM TextEditorViewModel
        let path = convertToCoreTextPath()
        
        if let cgPath = path {
            document.saveToUndoStack()
            
            // Convert the CGPath to VectorShape using your exact logic
            let vectorPath = convertCGPathToVectorPath(cgPath)
            let outlineShape = VectorShape(
                name: "Text Outline: \(text)",
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
                    
                    // CRITICAL FIX: Perform UNION operation to normalize path and make handles visible
                    // This fixes the issue where text conversion creates complex paths without visible handles
                    print("🔧 NORMALIZING PATH: Performing UNION operation to make bezier handles visible")
                    
                    // Select the shape and perform union with itself
                    document.selectedShapeIDs = [outlineShape.id]
                    document.performUnion()
                    
                    // Remove the original text object
                    if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
                        document.textObjects.remove(at: textIndex)
                    }
                    document.selectedTextIDs.removeAll()
                    
                    print("✅ CONVERTED TO OUTLINES: Created multi-line vector outlines with visible bezier handles")
                    print("🎯 HANDLES NOW VISIBLE: Use Direct Selection Tool (A) to edit individual points and curves")
                }
        } else {
            print("❌ CONVERT TO OUTLINES FAILED: Could not create Core Text path")
        }
    }
    
    // YOUR EXACT WORKING CORE TEXT IMPLEMENTATION FROM TextEditorViewModel
    public func convertToCoreTextPath() -> CGPath? {
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
                        // YOUR EXACT POSITIONING LOGIC
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
        
        return path
    }
    
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