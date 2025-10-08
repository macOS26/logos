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

        // Group all typography changes for cleaner code (with precision handling for line height)
        let typographyChanged = (
            self.textObject.typography.alignment != textObject.typography.alignment ||
            self.textObject.typography.fontFamily != textObject.typography.fontFamily ||
            self.textObject.typography.fontWeight != textObject.typography.fontWeight ||
            self.textObject.typography.fontVariant != textObject.typography.fontVariant ||
            abs(self.textObject.typography.lineHeight - textObject.typography.lineHeight) > 0.01 ||
            abs(self.textObject.typography.lineSpacing - textObject.typography.lineSpacing) > 0.01
        )

        // CRITICAL FIX: Check for position changes to ensure drag updates work without .id() modifier
        let positionChanged = (
            abs(self.textBoxFrame.origin.x - textObject.position.x) > 0.1 ||
            abs(self.textBoxFrame.origin.y - textObject.position.y) > 0.1
        )

        // CRITICAL FIX: Check for size changes from transformation box resize
        let sizeChanged = (
            abs(self.textBoxFrame.width - textObject.bounds.width) > 0.1 ||
            abs(self.textBoxFrame.height - textObject.bounds.height) > 0.1
        )

        if !shouldSyncContent && !fontChanged && !editingChanged && !colorChanged && !typographyChanged && !positionChanged && !sizeChanged {
            return // No changes, skip sync
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
        }

        self.fontSize = CGFloat(textObject.typography.fontSize)

        // CRITICAL FIX: Always update the font when typography changes
        // This ensures font style, weight, and other properties update live
        self.selectedFont = textObject.typography.nsFont

        // CRITICAL FIX: Don't reset editing state during active typing
        // Only sync isEditing if we're not currently editing to prevent focus loss
        if !self.isEditing {
            self.isEditing = textObject.isEditing
        }

        // CURSOR POSITIONING: Sync cursor position from VectorText
        if textObject.isEditing && textObject.cursorPosition != self.userInitiatedCursorPosition {
            self.userInitiatedCursorPosition = textObject.cursorPosition
        }

        self.textAlignment = textObject.typography.alignment.nsTextAlignment
        // Line spacing is now handled separately in the typography properties

        // REMOVED: objectWillChange.send() - Properties are @Published and will auto-trigger updates
        // This was causing performance issues with rapid font changes
        // NO MANUAL REFRESH NEEDED - SwiftUI handles this automatically

        // CRITICAL FIX: Sync both position AND size from document
        // Size can change from transformation box resize, position from dragging
        self.textBoxFrame = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: textObject.bounds.width,   // USE DOCUMENT SIZE (updated by transformation)
            height: textObject.bounds.height  // USE DOCUMENT SIZE (updated by transformation)
        )

    }

    private var lastTypingTime: TimeInterval = 0

    // MARK: - Update Last Typing Time
    func updateLastTypingTime() {
        lastTypingTime = Date().timeIntervalSince1970
    }

    // MARK: - Manual Resize Support Only

    var isAutoResizing = false  // Used to prevent sync loops during manual resize

    // MARK: - Working Methods from Original

    func startEditing() {
        // CRITICAL: Ensure only ONE text box can be in editing mode at a time
        // Stop all other text boxes from editing first
        for unifiedObj in document.unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType,
               shape.isTextObject,
               shape.id != textObject.id,
               shape.isEditing == true {
                document.setTextEditingInUnified(id: shape.id, isEditing: false)
            }
        }

        isEditing = true
    }

    func stopEditing() {
        isEditing = false

        // CRITICAL FIX: Update VectorText bounds when editing finishes
        // This ensures the selection box matches the text canvas when switching to arrow tool
        updateDocumentTextBounds(textBoxFrame)
    }

    func updateTextBoxFrame(_ newFrame: CGRect) {
        // CRITICAL: Disable auto-resize during manual resize to prevent conflicts
        isAutoResizing = true

        textBoxFrame = newFrame

        // CRITICAL FIX: Update VectorText bounds to match actual text box size
        // This ensures the main selection system (blue/red rectangle) matches the text canvas
        updateDocumentTextBounds(newFrame)

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
    }

    // MARK: - Rectangle Glyph Detection
    
    // Helper method to detect if a glyph path is a rectangle (missing character)
    private func isRectangleGlyph(_ path: CGPath) -> Bool {
        // Analyze the path structure
        var subpaths: [[CGPoint]] = []
        var currentPath: [CGPoint] = []
        var hasCurves = false
        
        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                // Start a new subpath
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                }
                currentPath = [element.points[0]]
                
            case .addLineToPoint:
                // Add line point
                currentPath.append(element.points[0])
                
            case .addQuadCurveToPoint, .addCurveToPoint:
                // If we have curves, it's not a rectangle
                hasCurves = true
                
            case .closeSubpath:
                // Close current subpath
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = []
                }
                
            @unknown default:
                break
            }
        }
        
        // Add any remaining path
        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }
        
        // Rectangles have no curves
        if hasCurves {
            return false
        }
        
        // Missing glyph rectangles typically have exactly 2 subpaths (outer and inner)
        if subpaths.count != 2 {
            return false
        }
        
        // Check if both subpaths are rectangles (4 or 5 points including close)
        for subpath in subpaths {
            if subpath.count < 4 || subpath.count > 5 {
                return false
            }
            
            // Check if points form a rectangle (all angles are 90 degrees)
            if !isRectangularPath(subpath) {
                return false
            }
        }
        
        // Check if one rectangle is inside the other (counter pattern)
        let bounds1 = boundingBox(of: subpaths[0])
        let bounds2 = boundingBox(of: subpaths[1])
        
        let isNested = (bounds1.contains(bounds2) || bounds2.contains(bounds1))
        
        if isNested {
            Log.warning("⚠️ DETECTED RECTANGLE GLYPH: Missing character placeholder with rectangular counter", category: .general)
            return true
        }
        
        return false
    }
    
    // Helper to check if points form a rectangle
    private func isRectangularPath(_ points: [CGPoint]) -> Bool {
        guard points.count >= 4 else { return false }
        
        // Check that we have mostly horizontal and vertical lines
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i + 1]
            
            let dx = abs(p2.x - p1.x)
            let dy = abs(p2.y - p1.y)
            
            // Line should be mostly horizontal or vertical
            let isHorizontal = dy < 0.1 && dx > 0.1
            let isVertical = dx < 0.1 && dy > 0.1
            
            if !isHorizontal && !isVertical {
                return false
            }
        }
        
        return true
    }
    
    // Helper to get bounding box of points
    private func boundingBox(of points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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
        
        // Track skipped glyphs for reporting
        var skippedGlyphCount = 0

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

                // Create glyph path
                if let glyphPath = CTFontCreatePathForGlyph(ctFont, CGGlyph(glyph), nil) {
                    // Check if this is a rectangle glyph (missing character placeholder)
                    if self.isRectangleGlyph(glyphPath) {
                        // Skip this glyph - it's a missing character placeholder
                        skippedGlyphCount += 1

                        // Get the character for logging
                        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
                        let char = (self.text as NSString).substring(with: NSRange(location: charIndex, length: 1))
                        Log.warning("⚠️ SKIPPING RECTANGLE GLYPH: Character '\(char)' at index \(charIndex) - missing from font", category: .general)
                        continue
                    }
                    
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

            // Only add the line path if it's not empty
            if !linePath.isEmpty {
                self.linePaths.append(linePath)
                combinedPath.addPath(linePath)
            }
        }
        
        // Report skipped glyphs if any
        if skippedGlyphCount > 0 {
            Log.warning("⚠️ RECTANGLE DETECTION: Skipped \(skippedGlyphCount) missing character placeholder(s)", category: .fileOperations)
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


        // NOTE: saveToUndoStack is called once in convertSelectedTextToOutlines() for atomic undo
        // DO NOT call it here to avoid duplicate undo entries

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

            // Add to the unified system WITHOUT saving to undo (atomic operation)
            document.addShapeWithoutUndo(outlineShape, to: targetLayerIndex)
            createdShapeIDs.append(outlineShape.id)
        }

        // DON'T modify selection here - let parent function handle it
        // This was corrupting the undo state by modifying selection after saveToUndoStack()

        // Remove from unified system (which will also update textObjects array)
        document.removeTextFromUnifiedSystem(id: textObject.id)

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
        guard let textObject = document.findText(by: textID) else {
            Log.error("❌ TEXT NOT FOUND: ID \(textID)", category: .error)
            return
        }
        let currentState = textObject.getState(in: document)

        // Check if text is locked
        if textObject.isLocked {
            Log.warning("🚫 TEXT LOCKED: Cannot interact with locked text", category: .general)
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

                // If font tool is active and this is a corner click, also start editing
                if document.currentTool == .font && isCornerClick {
                    startEditingText(textID: textID)
                }

            case .selected: // GREEN
                // Double-click on green text field: switch to font tool and start editing
                if isDoubleClick {
                    // Switch to font tool
                    document.currentTool = .font

                    // Start editing the text
                    startEditingText(textID: textID)
                } else if document.currentTool == .font {
                    // Single click with font tool active - start editing
                    startEditingText(textID: textID)
                }

            case .editing: // BLUE
                // Already editing - do nothing
                break
            }
        } else {
            // Single click behavior
            switch currentState {
            case .unselected: // GRAY
                // Select the text
                document.selectedTextIDs = [textID]
                document.selectedShapeIDs.removeAll()

            case .selected: // GREEN
                // Already selected - no change on single click
                break

            case .editing: // BLUE
                // Let NSTextView handle clicks during editing
                break
            }
        }
    }

    // MARK: - Start Editing Helper
    private func startEditingText(textID: UUID, at location: CGPoint = .zero) {

        // Stop editing any other text boxes first
        var editingCount = 0
        for unifiedObj in document.unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject, shape.isEditing == true {
                document.setTextEditingInUnified(id: shape.id, isEditing: false)
                editingCount += 1
            }
        }

        // Find and start editing the target text
        if let textObject = document.findText(by: textID) {


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

            }

        } else {
            Log.error("❌ TEXT NOT FOUND: Could not find text with ID \(textID)", category: .error)
        }
    }

    // MARK: - Cursor Position Calculation
    private func calculateCursorPosition(in _: VectorText, at _: CGPoint) -> Int {
        // Simple cursor positioning: place cursor at the beginning for now
        // This can be enhanced later with more sophisticated text layout analysis
        return 0
    }
}
