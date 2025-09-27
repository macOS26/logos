// ProfessionalTextViewModel.swift - Professional Text View Model
//
// CRITICAL DESIGN PRINCIPLE:
// This view model manages the RENDERED state of a text object for display and interaction.
// It syncs with the VectorText from the document but maintains its own state for UI.

import SwiftUI
import AppKit
import CoreText
import Combine

// CRITICAL: Text View Model manages the PRESENTATION LAYER only
// - The VectorDocument owns VectorText objects as the source of truth
// - This view model creates the visual representation and handles user interaction
// - Changes flow: User -> ViewModel -> Document -> VectorText

@MainActor
class ProfessionalTextViewModel: ObservableObject {
    // MARK: - The DISPLAY state (what the user sees)
    @Published var text: String = ""
    @Published var fontSize: CGFloat = 24.0
    @Published var selectedFont: NSFont = NSFont.systemFont(ofSize: 24.0)
    @Published var textAlignment: NSTextAlignment = .left
    @Published var isEditing: Bool = false
    @Published var textBoxFrame: CGRect = CGRect(x: 100, y: 100, width: 200, height: 100) // MANUAL SIZE
    @Published var userInitiatedCursorPosition: Int = 0  // SINGLE SOURCE OF TRUTH for cursor position
    @Published var userInitiatedSelectionLength: Int = 0  // SINGLE SOURCE OF TRUTH for selection length

    // MARK: - References
    @Published var textObject: VectorText  // Reference to document's VectorText
    let document: VectorDocument  // Weak reference to parent document

    // MARK: - Path Conversion Output
    var linePaths: [CGPath] = []

    // MARK: - Initialize from VectorText
    init(textObject: VectorText, document: VectorDocument) {
        self.textObject = textObject
        self.document = document

        // CRITICAL FIX: Calculate height based on actual text content with proper typography
        self.text = textObject.content
        self.fontSize = CGFloat(textObject.typography.fontSize)
        self.selectedFont = textObject.typography.nsFont
        self.textAlignment = textObject.typography.alignment.nsTextAlignment

        // CRITICAL FIX: Always use the text object's area size and position
        // This ensures consistency between VectorText and text canvas
        let width = textObject.areaSize?.width ?? 200.0
        let height = textObject.areaSize?.height ?? calculateTextHeight(for: textObject.content)

        self.textBoxFrame = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: width,
            height: height
        )

        self.isEditing = textObject.isEditing

        Log.info("📝 TEXT INIT: '\(textObject.content)' at \(textObject.position)", category: .general)
        Log.info("📝 TEXT INIT: Using areaSize \(textObject.areaSize?.debugDescription ?? "nil") for text box", category: .general)
    }

    // MARK: - Calculate Text Height
    private func calculateTextHeight(for content: String) -> CGFloat {
        guard !content.isEmpty else { return 50.0 }  // Default minimum height

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = max(0, textObject.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = textObject.typography.lineHeight
        paragraphStyle.maximumLineHeight = textObject.typography.lineHeight

        let attributes: [NSAttributedString.Key: Any] = [
            .font: selectedFont,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: content, attributes: attributes)
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: CGSize(width: textBoxFrame.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)

        layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: content.count))
        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        return max(50.0, ceil(usedRect.height + 10)) // Add small padding
    }

    // MARK: - Sync FROM Document VectorText
    func syncFromDocument(_ textObject: VectorText) {
        // CRITICAL: Check if we should update at all
        guard self.textObject.id == textObject.id else {
            Log.error("❌ SYNC ERROR: Mismatched text IDs", category: .error)
            return
        }

        // Skip rapid updates during active typing to prevent cursor jumping
        if isEditing && Date().timeIntervalSince1970 - lastTypingTime < 0.1 {
            return // Skip this sync - too frequent during typing
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
        // CRITICAL FIX: Store old font to detect style changes
        let oldFont = self.selectedFont

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

        // CRITICAL FIX: Always update the font when typography changes
        // This ensures font style, weight, and other properties update live
        self.selectedFont = textObject.typography.nsFont

        // CRITICAL FIX: Detect font style changes that don't change the font name
        let fontStyleChanged = oldFont != self.selectedFont

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

        // REMOVED: objectWillChange.send() - Properties are @Published and will auto-trigger updates
        // This was causing performance issues with rapid font changes
        if colorChanged || typographyChanged || fontStyleChanged {
            let changes = [
                colorChanged ? "color" : nil,
                typographyChanged ? "typography" : nil,
                fontStyleChanged ? "font-style" : nil
            ].compactMap { $0 }.joined(separator: ", ")

            Log.fileOperation("🎨 Visual properties changed: \(changes)", level: .debug)
            // NO MANUAL REFRESH NEEDED - SwiftUI handles this automatically
        }

        // CRITICAL FIX: NEVER override user's manual resize - ONLY sync position
        // Text box size is ENTIRELY controlled by user manual resize and auto-resize
        self.textBoxFrame = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: self.textBoxFrame.width,   // PRESERVE USER'S WIDTH
            height: self.textBoxFrame.height  // PRESERVE USER'S HEIGHT
        )

      //  Log.info("📦 EXTERNAL SYNC: Preserved user text box size, only updated position", category: .general)
    }

    private var lastTypingTime: TimeInterval = 0

    // MARK: - Manual Resize Support Only

    var isAutoResizing = false  // Used to prevent sync loops during manual resize

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

    func updateDocumentTextBounds(_ frame: CGRect) {
        // Update the document VectorText position and bounds to match actual text canvas
        document.updateTextPositionInUnified(id: textObject.id, position: CGPoint(x: frame.minX, y: frame.minY))
        document.updateTextBoundsInUnified(id: textObject.id, bounds: CGRect(
            x: 0, y: 0,
            width: frame.width,
            height: frame.height
        ))
        // CRITICAL FIX: Update areaSize to match new dimensions for proper copy/paste
        document.updateTextAreaSizeInUnified(id: textObject.id, areaSize: CGSize(width: frame.width, height: frame.height))
        if let textObj = document.findText(by: textObject.id) {
            Log.fileOperation("📐 UPDATED VECTORTEXT BOUNDS: position=\(textObj.position), bounds=\(textObj.bounds), areaSize=\(textObj.areaSize?.debugDescription ?? "nil")", level: .info)
        }
    }

    // MARK: - Convert using NSLayoutManager (matches NSTextView exactly)

    private func convertUsingNSLayoutManager() {
        // Use NSLayoutManager to get exact glyph positions matching NSTextView
        let nsFont = selectedFont

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = max(0, textObject.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = textObject.typography.lineHeight
        paragraphStyle.maximumLineHeight = textObject.typography.lineHeight

        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Create text storage and layout manager
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        // CRITICAL FIX: Use infinite height for text container to ensure no text is cut off
        // The text box height is just the visible area, but text might extend beyond it
        let textContainer = NSTextContainer(size: CGSize(width: textBoxFrame.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0 // Match NSTextView settings
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)

        // Force complete layout
        layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: text.count))
        layoutManager.ensureLayout(for: textContainer)
        
        // Get the actual used rect to understand where text is positioned
        let usedRect = layoutManager.usedRect(for: textContainer)

        // Create paths from glyphs
        linePaths = []
        let combinedPath = CGMutablePath()

        // CRITICAL FIX: Create CTFont with proper weight/traits from NSFont
        // This preserves Bold, Italic, etc.
        let ctFont = CTFontCreateWithGraphicsFont(
            CTFontCopyGraphicsFont(nsFont as CTFont, nil),
            nsFont.pointSize,
            nil,
            nil
        )

        // Enumerate through all glyphs
        let glyphRange = layoutManager.glyphRange(for: textContainer)

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, lineUsedRect, container, lineRange, stop) in
            let linePath = CGMutablePath()

            for glyphIndex in lineRange.location..<NSMaxRange(lineRange) {
                // Get the glyph and its position
                let glyph = layoutManager.cgGlyph(at: glyphIndex)
                let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)

                // CRITICAL FIX: Get the actual line fragment rect and used rect for this specific glyph
                var actualLineRect = CGRect.zero
                var actualUsedRect = CGRect.zero
                var effectiveRange = NSRange()
                actualLineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)
                actualUsedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)

                // Get the typographic bounds for accurate baseline positioning
                let textAscent = nsFont.ascender
                let textDescent = abs(nsFont.descender)
                let textLeading = nsFont.leading

                // CRITICAL FIX: Handle X positioning based on text alignment
                // Different alignments need different approaches for accurate positioning
                let glyphX: CGFloat

                switch self.textAlignment {
                case .left, .justified:
                    // For left and justified: use actualUsedRect for precise start position
                    glyphX = self.textBoxFrame.origin.x + actualUsedRect.origin.x + glyphLocation.x

                case .center, .right:
                    // For center and right: use lineRect since glyphLocation.x already includes the alignment offset
                    glyphX = self.textBoxFrame.origin.x + lineRect.origin.x + glyphLocation.x

                default:
                    // Fallback to left alignment behavior
                    glyphX = self.textBoxFrame.origin.x + actualUsedRect.origin.x + glyphLocation.x
                }

                // CRITICAL FIX: Match NSTextView positioning exactly
                // glyphLocation.y already contains the baseline position within the line (e.g., 19.0)
                // We just need to add it to the text box origin and line rect origin
                let glyphY = self.textBoxFrame.origin.y + actualLineRect.origin.y + glyphLocation.y

                // Enhanced debug logging for first glyph of each line
                if glyphIndex == lineRange.location {
                    Log.info("=== LINE \(self.linePaths.count) TEXT TO PATH CONVERSION ===", category: .general)
                    Log.info("TextBox Frame: \(self.textBoxFrame)", category: .general)
                    Log.info("  - Origin: (\(self.textBoxFrame.origin.x), \(self.textBoxFrame.origin.y))", category: .general)
                    Log.info("  - Size: \(self.textBoxFrame.width) x \(self.textBoxFrame.height)", category: .general)
                    Log.info("NSTextView Layout Info:", category: .general)
                    Log.info("  - Container Used Rect: \(usedRect)", category: .general)
                    Log.info("  - Line Rect: \(lineRect)", category: .general)
                    Log.info("  - Actual Line Rect: \(actualLineRect)", category: .general)
                    Log.info("  - Actual Used Rect: \(actualUsedRect)", category: .general)
                    Log.info("Type Metrics:", category: .general)
                    Log.info("  - Ascent: \(textAscent)", category: .general)
                    Log.info("  - Descent: \(textDescent)", category: .general)
                    Log.info("  - Leading: \(textLeading)", category: .general)
                    Log.info("Glyph Positioning:", category: .general)
                    Log.info("  - Glyph Location in Line: \(glyphLocation)", category: .general)
                    Log.info("  - Final X: \(glyphX)", category: .general)
                    Log.info("  - Final Y: \(glyphY)", category: .general)
                    Log.info("====================================", category: .general)
                }

                // Create glyph path
                if let glyphPath = CTFontCreatePathForGlyph(ctFont, CGGlyph(glyph), nil) {
                    // Apply self-union for better bezier curves
                    var unionedGlyph: CGPath
                    if let unionResult = ProfessionalPathOperations.union([glyphPath, glyphPath]) {
                        unionedGlyph = unionResult.normalized()
                    } else {
                        unionedGlyph = glyphPath
                    }

                    // FIX: NSLayoutManager uses top-left origin, but CTFont paths are bottom-left
                    // We need to flip the Y axis for the glyph path
                    var transform = CGAffineTransform(scaleX: 1.0, y: -1.0)  // Flip Y
                    transform = transform.translatedBy(x: glyphX, y: -glyphY)

                    linePath.addPath(unionedGlyph, transform: transform)
                }
            }

            self.linePaths.append(linePath)
            combinedPath.addPath(linePath)
        }
    }

    // MARK: - Convert to Core Text Path (ORIGINAL WORKING CODE)

    private func convertToCoreTextPath() {
        // Always use NSLayoutManager approach to match NSTextView exactly
        convertUsingNSLayoutManager()
    }

    // Alternative Core Text implementation (currently unused)
    // Removed unused convertUsingCoreText function

    // PUBLIC method for document conversion - calls the working Core Text method
    func convertToPath() {
        guard !text.isEmpty else {
            Log.error("❌ CONVERT TO OUTLINES: Cannot convert empty text", category: .error)
            return
        }

        Log.fileOperation("🎯 CONVERTING TO OUTLINES: Creating compound paths per line", level: .info)

        document.saveToUndoStack()

        // Call the working Core Text conversion
        convertToCoreTextPath()

        guard !linePaths.isEmpty else {
            Log.error("❌ CONVERT TO OUTLINES FAILED: No line paths created", category: .error)
            return
        }

        // Get target layer index
        let targetLayerIndex = document.selectedLayerIndex ?? 2

        // Create one compound path shape per line
        var createdShapeIDs: [UUID] = []
        for (lineIndex, linePath) in linePaths.enumerated() {
            // Convert to VectorShape - each line becomes a compound path
            let vectorPath = convertCGPathToVectorPath(linePath)
            let lineName = "Line \(lineIndex + 1)"
            let outlineShape = VectorShape(
                name: lineName,
                path: vectorPath,
                strokeStyle: nil,  // NO STROKES as requested
                fillStyle: FillStyle(
                    color: textObject.typography.fillColor,
                    opacity: textObject.typography.fillOpacity
                ),
                transform: .identity,
                isGroup: false
            )

            // Add to the unified system
            document.addShape(outlineShape, to: targetLayerIndex)
            createdShapeIDs.append(outlineShape.id)

            Log.fileOperation("🎯 ADDED LINE SHAPE: '\(outlineShape.name)' to unified system", level: .info)
        }

        Log.info("✅ TEXT CONVERSION COMPLETE: Created \(linePaths.count) compound path(s)", category: .fileOperations)

        // Select all converted shapes
        document.selectedShapeIDs = Set(createdShapeIDs)
        document.selectedTextIDs.removeAll()

        // Remove from unified system (which will also update textObjects array)
        document.removeTextFromUnifiedSystem(id: textObject.id)
        Log.info("🗑️ REMOVED TEXT OBJECT FROM UNIFIED: ID \(textObject.id.uuidString.prefix(8))", category: .general)

        // Force UI update
        document.objectWillChange.send()
    }

    // MARK: - Core Graphics Path Conversion Helper
    func convertCGPathToVectorPath(_ cgPath: CGPath) -> VectorPath {
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

        guard let textObject = document.findText(by: textID) else {
            Log.error("❌ TEXT NOT FOUND: ID \(textID)", category: .error)
            return
        }
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
                    Log.fileOperation("🎯 CORNER CLICK WITH TYPE TOOL: GRAY → GREEN → BLUE", level: .info)
                }

            case .selected: // GREEN
                // Double-click on green text field: switch to font tool and start editing
                if isDoubleClick {
                    // Switch to font tool
                    document.currentTool = .font
                    Log.fileOperation("🔧 DOUBLE-CLICK: Switched to type tool", level: .info)

                    // Start editing the text
                    startEditingText(textID: textID)
                    Log.fileOperation("🎯 DOUBLE-CLICK: GREEN → BLUE (switched to type tool)", level: .info)
                } else if document.currentTool == .font {
                    // Single click with font tool active - start editing
                    startEditingText(textID: textID)
                    Log.fileOperation("🎯 START EDITING: GREEN → BLUE", level: .info)
                } else {
                    Log.fileOperation("🎯 TYPE TOOL NOT ACTIVE: Staying GREEN", level: .info)
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
        for textObject in document.getAllTextObjects() {
            if textObject.isEditing {
                document.setTextEditingInUnified(id: textObject.id, isEditing: false)
                editingCount += 1
            }
        }

        if editingCount > 0 {
            Log.fileOperation("🔄 STOPPED \(editingCount) text box(es) that were in edit mode", level: .info)
        }

        // Find and start editing the target text
        if let textObject = document.findText(by: textID) {

            Log.info("✏️ STARTING EDIT MODE:", category: .general)
            Log.info("  - Text: '\(textObject.content)'", category: .general)
            Log.info("  - Type: \(textObject.typography.fontFamily) \(textObject.typography.fontSize)pt", category: .general)
            Log.info("  - State: GRAY/GREEN → BLUE (editing)", category: .general)
            Log.info("  - Click location: (\(String(format: "%.1f", location.x)), \(String(format: "%.1f", location.y)))", category: .general)

            // CRITICAL: Set editing state BEFORE updating selection
            document.setTextEditingInUnified(id: textObject.id, isEditing: true)

            // Clear other selections and select this text
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs = [textID]

            // Calculate cursor position at click location if provided
            if location != .zero {
                let cursorPosition = calculateCursorPosition(in: textObject, at: location)

                // CRITICAL: Update the VectorText's cursor position directly
                document.updateTextCursorPositionInUnified(id: textObject.id, cursorPosition: cursorPosition)

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