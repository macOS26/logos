//
//  ProfessionalTextCanvas.swift
//  logos inkpen.io
//
//  Professional text editing component using the working NewTextBoxFontTool pattern
//  Integrates with VectorText and VectorColor systems + existing FontPanel
//

import SwiftUI
import CoreText

// MARK: - Professional Text Canvas (Adapted from working NewTextBoxFontTool)
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
            // Text Box View (border and interaction)
            ProfessionalTextBoxView(
                viewModel: viewModel,
                document: document,
                dragOffset: dragOffset,
                resizeOffset: resizeOffset,
                textBoxState: textBoxState,
                onTextBoxSelect: handleTextBoxSelect,
                onTextBoxTap: handleTextBoxTap,
                onDragChanged: handleDragChanged,
                onDragEnded: handleDragEnded
            )
            
            // Text Display View
            ProfessionalTextDisplayView(
                viewModel: viewModel,
                document: document,
                dragOffset: dragOffset,
                textBoxState: textBoxState
            )
            
            // Cursor View (when editing)
            if textBoxState == .blue {
                ProfessionalCursorView(viewModel: viewModel, dragOffset: dragOffset)
            }
            
            // Resize Handle (when selected)
            if textBoxState == .green {
                ProfessionalResizeHandleView(
                    viewModel: viewModel,
                    dragOffset: dragOffset,
                    resizeOffset: resizeOffset,
                    onResizeChanged: handleResizeChanged,
                    onResizeEnded: handleResizeEnded
                )
            }
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(action: handleKeyPress)
        .onChange(of: viewModel.isEditing) { _, isEditing in
            if isEditing {
                textBoxState = .blue
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
        }
        .onChange(of: document.selectedTextIDs) { _, selectedIDs in
            updateTextBoxState(selectedIDs: selectedIDs)
        }
        .onAppear {
            // Set initial state based on selection
            updateTextBoxState(selectedIDs: document.selectedTextIDs)
        }
    }
    
    // MARK: - State Management
    
    private func updateTextBoxState(selectedIDs: Set<UUID>) {
        if viewModel.textObject.isEditing {
            textBoxState = .blue
        } else if selectedIDs.contains(viewModel.textObject.id) {
            textBoxState = .green
        } else {
            textBoxState = .gray
        }
    }
    
    // MARK: - Event Handlers (Following working NewTextBoxFontTool pattern)
    
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
            let newPosition = CGPoint(
                x: viewModel.textBoxFrame.minX + dragOffset.width,
                y: viewModel.textBoxFrame.minY + dragOffset.height
            )
            // Update document position
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == viewModel.textObject.id }) {
                document.textObjects[textIndex].position = newPosition
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
        guard textBoxState == .blue else { return .ignored }
        
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

// MARK: - Professional Text Box View
struct ProfessionalTextBoxView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    @ObservedObject var document: VectorDocument
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
            .fill(Color.white.opacity(0.01)) // Nearly transparent but can receive gestures
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

// MARK: - Professional Text Display View
struct ProfessionalTextDisplayView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    @ObservedObject var document: VectorDocument
    let dragOffset: CGSize
    let textBoxState: ProfessionalTextCanvas.TextBoxState
    
    var body: some View {
        Group {
            if textBoxState == .blue {
                // Use NSTextView for editing with VectorColor
                ProfessionalEditingTextView(viewModel: viewModel, document: document)
            } else {
                // Use SwiftUI Text for display
                ProfessionalDisplayTextView(viewModel: viewModel, document: document)
            }
        }
        .frame(
            width: viewModel.textBoxFrame.width,
            height: viewModel.textBoxFrame.height
        )
        .position(
            x: viewModel.textBoxFrame.minX + dragOffset.width + viewModel.textBoxFrame.width / 2,
            y: viewModel.textBoxFrame.minY + dragOffset.height + viewModel.textBoxFrame.height / 2
        )
    }
}

// MARK: - Professional Display Text View (SwiftUI Text)
struct ProfessionalDisplayTextView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    @ObservedObject var document: VectorDocument
    
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
        .allowsHitTesting(false) // Allow gestures to pass through
    }
}

// MARK: - Professional Editing Text View (NSTextView)
struct ProfessionalEditingTextView: NSViewRepresentable {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    @ObservedObject var document: VectorDocument
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        
        // Configure exactly like the working NewTextBoxFontTool
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
        
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        context.coordinator.textView = textView
        
        return textView
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
        // Update editability
        nsView.isEditable = viewModel.isEditing
        nsView.isSelectable = viewModel.isEditing
        
        // Create paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = viewModel.textAlignment
        paragraphStyle.lineSpacing = viewModel.lineSpacing
        
        // Use VectorColor for text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: viewModel.selectedFont.fontName, size: viewModel.fontSize) ?? NSFont.systemFont(ofSize: viewModel.fontSize),
            .foregroundColor: NSColor(viewModel.textObject.typography.fillColor.color), // Convert VectorColor to NSColor
            .paragraphStyle: paragraphStyle
        ]
        
        // Update text content if different
        if nsView.string != viewModel.text {
            let attributedString = NSAttributedString(string: viewModel.text, attributes: attributes)
            nsView.textStorage?.setAttributedString(attributedString)
        } else {
            // Just update attributes
            let range = NSRange(location: 0, length: nsView.string.count)
            nsView.textStorage?.addAttributes(attributes, range: range)
        }
        
        // Set cursor color to match text color
        nsView.insertionPointColor = NSColor(viewModel.textObject.typography.fillColor.color)
        
        // Set container size
        nsView.textContainer?.containerSize = NSSize(
            width: viewModel.textBoxFrame.width,
            height: viewModel.textBoxFrame.height
        )
        
        // Focus management
        if viewModel.isEditing {
            if nsView.window?.firstResponder != nsView {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
        
        // Direct state monitoring - update viewModel when text changes
        if nsView.string != viewModel.text {
            viewModel.text = nsView.string
            // Update document
            document.updateTextContent(viewModel.textObject.id, content: nsView.string)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ProfessionalEditingTextView
        weak var textView: NSTextView?
        
        init(_ parent: ProfessionalEditingTextView) {
            self.parent = parent
        }
    }
}

// MARK: - Professional Cursor View
struct ProfessionalCursorView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    
    var body: some View {
        // NSTextView handles its own cursor, but we can add custom cursor logic here if needed
        EmptyView()
    }
}

// MARK: - Professional Resize Handle
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

// MARK: - Professional Text View Model (Adapted from TextEditorViewModel)
class ProfessionalTextViewModel: ObservableObject {
    @Published var text: String = "Text"
    @Published var fontSize: CGFloat = 24
    @Published var selectedFont: NSFont = NSFont.systemFont(ofSize: 24)
    @Published var textBoxFrame: CGRect = CGRect(x: 50, y: 50, width: 200, height: 50)
    @Published var isEditing: Bool = false
    @Published var textAlignment: NSTextAlignment = .left
    @Published var lineSpacing: CGFloat = 0.0
    
    let textObject: VectorText
    let document: VectorDocument
    
    init(textObject: VectorText, document: VectorDocument) {
        self.textObject = textObject
        self.document = document
        
        // Sync from VectorText
        syncFromVectorText()
        
        // Listen for document changes to sync updates from FontPanel
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
        // Find current text object in document (it may have been updated)
        guard let currentTextObject = document.textObjects.first(where: { $0.id == textObject.id }) else { return }
        
        // Update all properties from current VectorText state
        self.text = currentTextObject.content
        self.fontSize = CGFloat(currentTextObject.typography.fontSize)
        self.selectedFont = currentTextObject.typography.nsFont
        self.textBoxFrame = CGRect(
            x: currentTextObject.position.x,
            y: currentTextObject.position.y,
            width: max(currentTextObject.bounds.width, 200),
            height: max(currentTextObject.bounds.height, 50)
        )
        self.isEditing = currentTextObject.isEditing
        self.textAlignment = currentTextObject.typography.alignment.nsTextAlignment
        self.lineSpacing = CGFloat(currentTextObject.typography.lineHeight - currentTextObject.typography.fontSize)
    }
    
    func startEditing() {
        isEditing = true
    }
    
    func stopEditing() {
        isEditing = false
    }
    
    func updateTextBoxFrame(_ newFrame: CGRect) {
        textBoxFrame = newFrame
        // Update document
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
            document.textObjects[textIndex].position = CGPoint(x: newFrame.minX, y: newFrame.minY)
        }
    }
} 