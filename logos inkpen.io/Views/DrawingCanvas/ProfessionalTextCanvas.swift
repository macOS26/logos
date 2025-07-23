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
    @FocusState private var isFocused: Bool
    
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
            
            ProfessionalResizeHandleView(
                viewModel: viewModel,
                dragOffset: dragOffset,
                resizeOffset: resizeOffset,
                onResizeChanged: handleResizeChanged,
                onResizeEnded: handleResizeEnded
            )
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
        .onChange(of: document.selectedTextIDs) { _, selectedIDs in
            updateTextBoxState(selectedIDs: selectedIDs)
        }
        .onAppear {
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }
    }
    
    // MARK: - State Management (From Working Code)
    
    private func updateTextBoxState(selectedIDs: Set<UUID>) {
        if viewModel.textObject.isEditing {
            textBoxState = .blue
        } else if selectedIDs.contains(viewModel.textObject.id) {
            textBoxState = .green
        } else {
            textBoxState = .gray
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
            isFocused = true
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
        
        // CRITICAL: These settings prevent horizontal growth
        textView.textContainer?.widthTracksTextView = false  // Width NEVER tracks view
        textView.textContainer?.heightTracksTextView = false // Height NEVER tracks view
        textView.isVerticallyResizable = false    // No vertical auto-resize by NSTextView
        textView.isHorizontallyResizable = false  // No horizontal auto-resize by NSTextView
        textView.autoresizingMask = []           // No auto-resizing masks
        
        // FORCE text wrapping within container bounds
        textView.textContainer?.containerSize = NSSize(
            width: viewModel.textBoxFrame.width,     // FIXED WIDTH
            height: CGFloat.greatestFiniteMagnitude  // UNLIMITED HEIGHT for wrapping
        )
        
        // CRITICAL: Set the actual frame to prevent expansion
        textView.frame = CGRect(
            x: 0, y: 0,
            width: viewModel.textBoxFrame.width,     // FIXED WIDTH - NEVER CHANGES
            height: viewModel.textBoxFrame.height    // Current height
        )
        
        // CRITICAL: Disable all forms of automatic sizing
        textView.textContainer?.lineBreakMode = .byWordWrapping  // Force word wrapping
        textView.maxSize = NSSize(
            width: viewModel.textBoxFrame.width,     // MAX WIDTH = FIXED WIDTH
            height: CGFloat.greatestFiniteMagnitude  // UNLIMITED HEIGHT
        )
        textView.minSize = NSSize(
            width: viewModel.textBoxFrame.width,     // MIN WIDTH = FIXED WIDTH  
            height: 50                              // MIN HEIGHT
        )
        
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        context.coordinator.textView = textView
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        
        return textView
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
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
        
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: viewModel.selectedFont.fontName, size: viewModel.fontSize) ?? NSFont.systemFont(ofSize: viewModel.fontSize),
            .foregroundColor: NSColor(viewModel.textObject.typography.fillColor.color),
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
        
        // DIRECT STATE MONITORING - NO NOTIFICATIONS
        // Check if text changed and update viewModel directly
        if nsView.string != viewModel.text {
            // NSTextView text changed - update our state
            print("🔄 TEXT CHANGED: '\(viewModel.text)' → '\(nsView.string)'")
            viewModel.text = nsView.string
            // Update document
            viewModel.document.updateTextContent(viewModel.textObject.id, content: nsView.string)
            print("📏 AUTO-RESIZE: Triggered by text change")
        }
        
        // Force layout update
        nsView.layoutManager?.ensureLayout(for: nsView.textContainer!)
        
        // Ensure the text view becomes first responder when editing starts
        if viewModel.isEditing {
            // Force first responder status immediately for I-beam cursor
            if nsView.window?.firstResponder != nsView {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
        
        // Update cursor color if text color changed
        if nsView.insertionPointColor != NSColor(viewModel.textObject.typography.fillColor.color) {
            nsView.insertionPointColor = NSColor(viewModel.textObject.typography.fillColor.color)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ProfessionalUniversalTextView
        weak var textView: NSTextView?
        
        init(_ parent: ProfessionalUniversalTextView) {
            self.parent = parent
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
            .frame(width: 10, height: 10)
            .position(
                x: viewModel.textBoxFrame.maxX + dragOffset.width + resizeOffset.width,
                y: viewModel.textBoxFrame.maxY + dragOffset.height + resizeOffset.height
            )
            .gesture(
                DragGesture()
                    .onChanged(onResizeChanged)
                    .onEnded { _ in onResizeEnded() }
            )
    }
}

// MARK: - Professional Text View Model (Based on Working TextEditorViewModel)
class ProfessionalTextViewModel: ObservableObject {
    @Published var text: String = "Text" {
        didSet {
            // CRITICAL: Only auto-resize if text actually changed and we're editing
            if oldValue != text && isEditing {
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
        
        // Sync from VectorText
        syncFromVectorText()
        
        // Listen for FontPanel updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VectorTextUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncFromVectorText()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func syncFromVectorText() {
        guard let currentTextObject = document.textObjects.first(where: { $0.id == textObject.id }) else { return }
        
        self.text = currentTextObject.content
        self.fontSize = CGFloat(currentTextObject.typography.fontSize)
        self.selectedFont = currentTextObject.typography.nsFont
        // CRITICAL: Text boxes have FIXED width, calculated height
        // Don't use VectorText.bounds.width as it expands with text content
        let fixedWidth: CGFloat = 300  // DEFAULT FIXED WIDTH FOR TEXT BOXES
        let calculatedHeight = max(currentTextObject.bounds.height, 100)
        
        self.textBoxFrame = CGRect(
            x: currentTextObject.position.x,
            y: currentTextObject.position.y,
            width: fixedWidth,    // ALWAYS FIXED WIDTH
            height: calculatedHeight
        )
        
        print("🔒 TEXT BOX WIDTH LOCKED: \(fixedWidth)pt (ignoring VectorText.bounds.width: \(currentTextObject.bounds.width)pt)")
        self.isEditing = currentTextObject.isEditing
        self.textAlignment = currentTextObject.typography.alignment.nsTextAlignment
        self.lineSpacing = CGFloat(currentTextObject.typography.lineHeight - currentTextObject.typography.fontSize)
    }
    
    // MARK: - Working Auto-Resize Logic (Exact from Working Code)
    
    private var isAutoResizing = false  // Prevent infinite loops
    
    private func scheduleAutoResize() {
        guard autoExpandVertically && !isAutoResizing else { 
            return 
        }
        
        // Debounce multiple resize requests
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.autoResizeTextBoxHeight()
        }
    }
    
    private func autoResizeTextBoxHeight() {
        guard autoExpandVertically && !isAutoResizing else { return }
        
        isAutoResizing = true
        defer { isAutoResizing = false }
        
        let requiredHeight = calculateRequiredHeight()
        let newHeight = max(minTextBoxHeight, requiredHeight)
        
        // Only update if height needs to change significantly
        if abs(textBoxFrame.height - newHeight) > 5.0 {
            let newFrame = CGRect(
                x: textBoxFrame.minX,
                y: textBoxFrame.minY,
                width: textBoxFrame.width,  // FIXED WIDTH - NEVER CHANGES
                height: newHeight          // ONLY HEIGHT CHANGES
            )
            
            // Update without triggering more auto-resizes
            let oldAutoExpand = autoExpandVertically
            autoExpandVertically = false
            textBoxFrame = newFrame
            autoExpandVertically = oldAutoExpand
            
            // Update document bounds - use minimal width for VectorText, height for layout
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
                document.textObjects[textIndex].bounds = CGRect(
                    x: 0, y: 0,
                    width: 100,               // MINIMAL WIDTH for VectorText (text box manages actual width)
                    height: newHeight         // ACTUAL HEIGHT for layout
                )
            }
            
            print("✅ AUTO-RESIZE: Height \(textBoxFrame.height) → \(newHeight) (WIDTH LOCKED: \(textBoxFrame.width))")
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
        textBoxFrame = newFrame
        scheduleAutoResize()
    }
} 