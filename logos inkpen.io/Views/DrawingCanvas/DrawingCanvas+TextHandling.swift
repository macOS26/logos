//
//  TextHandling.swift
//  logos inkpen.io
//
//  Professional Core Graphics Text Editing
//

import SwiftUI
import Foundation

// MARK: - Enhanced Text and Font Handling Extension
extension DrawingCanvas {
    
    // MARK: - Font Tool Handler (Professional Core Graphics Based)
    
    func handleFontToolTap(at location: CGPoint) {
        print("🎯 FONT TOOL TAP at: \(location)")
        lastTapLocation = location
        
        // CRITICAL: Prevent new text box creation when any text box is in active states
        let isAnyTextEditing = document.textObjects.contains { $0.isEditing }
        let isAnyTextSelected = !document.selectedTextIDs.isEmpty
        
        if isAnyTextEditing {
            print("🚫 NEW TEXT BLOCKED: A text box is in BLUE (edit) mode")
            return
        }
        
        if isAnyTextSelected {
            print("🚫 NEW TEXT BLOCKED: Text boxes are in GREEN (selected) mode")
            return
        }
        
        // Check if tapping on existing text to edit it
        if let existingTextID = findTextAt(location: location) {
            startEditingText(textID: existingTextID, at: location)
        } else {
            // Create new text at tap location
            createNewTextAt(location: location)
        }
    }
    
    // MARK: - Professional Text Canvas Background Handler
    func handleAggressiveBackgroundTap(at location: CGPoint) {
        // AGGRESSIVE background tap - deselects ALL text boxes immediately
        // BUT: Use the same improved hit testing as findTextAt to be consistent
        
        print("🔍 BACKGROUND TAP: Checking if location \(location) hits any text")
        
        // Use the same generous hit testing logic as findTextAt
        let tapHitsText = document.textObjects.contains { textObj in
            if !textObj.isVisible || textObj.isLocked { return false }
            
            // Use the same three hit testing methods as findTextAt
            let textContentArea = CGRect(
                x: textObj.position.x,
                y: textObj.position.y,
                width: max(textObj.bounds.width, 200.0),
                height: max(textObj.bounds.height, 60.0)
            )
            
            let exactBounds = CGRect(
                x: textObj.position.x + textObj.bounds.minX,
                y: textObj.position.y + textObj.bounds.minY,
                width: textObj.bounds.width,
                height: textObj.bounds.height
            )
            
            let expandedBounds = exactBounds.insetBy(dx: -30, dy: -20)
            
            let hits = textContentArea.contains(location) || 
                      exactBounds.contains(location) || 
                      expandedBounds.contains(location)
            
            if hits {
                print("🎯 BACKGROUND TAP: Hit text '\(textObj.content.prefix(20))'")
            }
            
            return hits
        }
        
        if !tapHitsText {
            print("🎯 BACKGROUND TAP: No text hit - deselecting all")
            // AGGRESSIVELY deselect everything
            document.selectedTextIDs.removeAll()
            document.selectedShapeIDs.removeAll()
            
            // Stop all editing
            for textIndex in document.textObjects.indices {
                if document.textObjects[textIndex].isEditing {
                    document.textObjects[textIndex].isEditing = false
                }
            }
            
            finishTextEditing()
            print("🎯 AGGRESSIVE DESELECT: All text boxes → GRAY mode")
        } else {
            print("🎯 BACKGROUND TAP: Text hit - no deselection")
        }
    }
    
    func findTextAt(location: CGPoint) -> UUID? {
        print("🔍 FIND TEXT: Looking for text at location \(location)")
        
        for textObj in document.textObjects {
            if !textObj.isVisible || textObj.isLocked { continue }
            
            // IMPROVED: Use a much more generous hit area that covers the entire text content
            // This makes it easy to click anywhere inside the text to select it
            
            // Method 1: Use the actual text position and create a generous content area
            let textContentArea = CGRect(
                x: textObj.position.x,
                y: textObj.position.y,
                width: max(textObj.bounds.width, 200.0), // Minimum 200pt width for easy clicking
                height: max(textObj.bounds.height, 60.0)  // Minimum 60pt height for easy clicking
            )
            
            // Method 2: Also check the exact bounds area (for edge cases)
            let exactBounds = CGRect(
                x: textObj.position.x + textObj.bounds.minX,
                y: textObj.position.y + textObj.bounds.minY,
                width: textObj.bounds.width,
                height: textObj.bounds.height
            )
            
            // Method 3: Create an expanded bounds area with generous tolerance
            let expandedBounds = exactBounds.insetBy(dx: -30, dy: -20) // Much larger tolerance
            
            print("🔍 TEXT CHECK: '\(textObj.content.prefix(20))' UUID: \(textObj.id.uuidString.prefix(8))")
            print("  - Content area: \(textContentArea)")
            print("  - Exact bounds: \(exactBounds)")
            print("  - Expanded bounds: \(expandedBounds)")
            
            // Hit test using any of the three methods (most generous approach)
            if textContentArea.contains(location) || 
               exactBounds.contains(location) || 
               expandedBounds.contains(location) {
                print("✅ TEXT HIT: Found text '\(textObj.content.prefix(20))' at location")
                return textObj.id
            } else {
                print("❌ TEXT MISS: Location not in any hit area")
            }
        }
        
        print("❌ NO TEXT: No text found at location \(location)")
        return nil
    }
    
    func startEditingText(textID: UUID, at location: CGPoint) {
        print("✏️ Starting to edit existing text: \(textID)")
        
        // Save current state before editing
        document.saveToUndoStack()
        
        // CRITICAL: Ensure only one text box can be in edit mode at a time
        var editingCount = 0
        for textIndex in document.textObjects.indices {
            if document.textObjects[textIndex].isEditing {
                editingCount += 1
                print("🔄 STOPPING EDIT: Text box \(document.textObjects[textIndex].id.uuidString.prefix(8)) was in edit mode")
            }
            document.textObjects[textIndex].isEditing = false
        }
        
        if editingCount > 0 {
            print("🔄 STOPPED \(editingCount) text box(es) that were in edit mode")
        }
        
        // Find and start editing the target text
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
            let textObject = document.textObjects[textIndex]
            
            print("✏️ STARTING EDIT MODE:")
            print("  - Text: '\(textObject.content)'")
            print("  - Font: \(textObject.typography.fontFamily) \(textObject.typography.fontSize)pt")
            print("  - State: GRAY/GREEN → BLUE (editing)")
            
            // CRITICAL: Set editing state BEFORE updating selection
            document.textObjects[textIndex].isEditing = true
            
            // Clear other selections and select this text
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs = [textID]
            
            // Update editing state
            isEditingText = true
            editingTextID = textID
            
            print("✅ TEXT EDITING STARTED: Text box \(textID.uuidString.prefix(8)) is now in BLUE (edit) mode")
        } else {
            print("❌ TEXT NOT FOUND: Could not find text with ID \(textID)")
        }
    }
    
    // ENHANCED: Better double-click detection and corner circle support
    func handleTextBoxInteraction(textID: UUID, isDoubleClick: Bool = false, isCornerClick: Bool = false) {
        print("🎯 TEXT BOX INTERACTION: textID=\(textID.uuidString.prefix(8)), doubleClick=\(isDoubleClick), cornerClick=\(isCornerClick)")
        
        guard let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else {
            print("❌ TEXT NOT FOUND: ID \(textID)")
            return
        }
        
        let textObject = document.textObjects[textIndex]
        let currentState = textObject.getState(in: document)
        
        print("📊 CURRENT STATE: \(currentState.description)")
        print("📊 CURRENT TOOL: \(document.currentTool.rawValue)")
        
        // Check if text is locked
        if textObject.isLocked {
            print("🚫 TEXT LOCKED: Cannot interact with locked text")
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
                print("🎯 SELECTED TEXT: GRAY → GREEN")
                
                // If font tool is active and this is a corner click, also start editing
                if document.currentTool == .font && isCornerClick {
                    startEditingText(textID: textID, at: .zero)
                    print("🎯 CORNER CLICK WITH FONT TOOL: GRAY → GREEN → BLUE")
                }
                
            case .selected: // GREEN
                // Start editing if font tool is active
                if document.currentTool == .font {
                    startEditingText(textID: textID, at: .zero)
                    print("🎯 START EDITING: GREEN → BLUE")
                } else {
                    print("🎯 FONT TOOL NOT ACTIVE: Staying GREEN")
                }
                
            case .editing: // BLUE
                // Already editing - do nothing
                print("🎯 ALREADY EDITING: Staying BLUE")
            }
        } else {
            // Single click behavior
            switch currentState {
            case .unselected: // GRAY
                // Select the text
                document.selectedTextIDs = [textID]
                document.selectedShapeIDs.removeAll()
                print("🎯 SINGLE CLICK: GRAY → GREEN")
                
            case .selected: // GREEN
                // Already selected - no change on single click
                print("🎯 SINGLE CLICK: Staying GREEN")
                
            case .editing: // BLUE
                // Let NSTextView handle clicks during editing
                print("🎯 SINGLE CLICK: Staying BLUE (NSTextView handles)")
            }
        }
    }
    
    // MARK: - Enhanced Cursor Positioning
    
    func calculateCursorPosition(in textObj: VectorText, at tapLocation: CGPoint) -> Int {
        // Convert tap location to text-relative coordinates
        let relativePoint = CGPoint(
            x: tapLocation.x - textObj.position.x,
            y: tapLocation.y - textObj.position.y
        )
        
        // Use Core Text to find the character index
        let nsFont = textObj.typography.nsFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .kern: textObj.typography.letterSpacing
        ]
        
        let attributedString = NSAttributedString(string: textObj.content, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // Get character index at the relative point
        let index = CTLineGetStringIndexForPosition(line, relativePoint)
        return max(0, min(textObj.content.count, index))
    }
    
    // MARK: - Text Creation and Management
    

    
    // Create new text at canvas position using our new professional text system
    func createNewTextAt(location: CGPoint) {
        // CRITICAL: Comprehensive check - no text box creation in active states
        let isAnyTextEditing = document.textObjects.contains { $0.isEditing }
        let isAnyTextSelected = !document.selectedTextIDs.isEmpty
        
        if isAnyTextEditing {
            print("🚫 NEW TEXT BLOCKED (createNewTextAt): A text box is in BLUE (edit) mode")
            return
        }
        
        if isAnyTextSelected {
            print("🚫 NEW TEXT BLOCKED (createNewTextAt): Text boxes are in GREEN (selected) mode")
            return
        }
        
        // Default size for click creation
        createNewTextWithSize(at: location, width: 300, height: 100)
    }
    
    // Create new text with user-defined size (like rectangle tool)
    func createNewTextWithSize(at location: CGPoint, width: CGFloat, height: CGFloat) {
        // CRITICAL: Comprehensive check - no text box creation in active states
        let isAnyTextEditing = document.textObjects.contains { $0.isEditing }
        let isAnyTextSelected = !document.selectedTextIDs.isEmpty
        
        if isAnyTextEditing {
            print("🚫 NEW TEXT BLOCKED (createNewTextWithSize): A text box is in BLUE (edit) mode")
            return
        }
        
        if isAnyTextSelected {
            print("🚫 NEW TEXT BLOCKED (createNewTextWithSize): Text boxes are in GREEN (selected) mode")
            return
        }
        
        print("✨ Creating new text box at: \(location) with user size: \(width) × \(height)")
        
        // Save state before creating new text
        document.saveToUndoStack()
        
        // Use current toolbar colors and font settings
        let typography = TypographyProperties(
            fontFamily: document.fontManager.selectedFontFamily,
            fontWeight: document.fontManager.selectedFontWeight,
            fontStyle: document.fontManager.selectedFontStyle,
            fontSize: document.fontManager.selectedFontSize,
            lineHeight: document.fontManager.selectedFontSize, // Default line height = fontSize
            letterSpacing: 0.0,
            alignment: .left, // Default to left alignment
            hasStroke: false, // NO STROKES - only fill colors
            strokeColor: document.defaultStrokeColor,
            strokeOpacity: document.defaultStrokeOpacity,
            fillColor: document.defaultFillColor, // Use current fill color
            fillOpacity: document.defaultFillOpacity
        )
        
        // Create new text object with USER-DEFINED bounds
        var newText = VectorText(
            content: "", // Start with placeholder text
            typography: typography,
            position: location,
            isEditing: true
        )
        
        // CRITICAL: Set bounds to user-drawn size, NOT calculated size
        newText.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        
        // Add to document and associate with current layer
        document.addTextToLayer(newText, layerIndex: document.selectedLayerIndex!)
        
        // Select the text for immediate editing
        document.selectedTextIDs = [newText.id]
        document.selectedShapeIDs.removeAll()
        
        // Set editing state for compatibility with existing system
        isEditingText = true
        editingTextID = newText.id
        
        print("✅ Created text box with USER-DEFINED size: \(width) × \(height)")
        print("🎯 Text ready for editing - size will NOT change unless user manually resizes")
    }
    
    // MARK: - Professional Text Input Handling
    
    func insertTextAtCursor(_ text: String) {
        guard let editingID = editingTextID,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }) else { return }
        
        var textObj = document.textObjects[textIndex]
        
        // Insert text at current cursor position
        let insertIndex = textObj.content.index(
            textObj.content.startIndex,
            offsetBy: min(currentCursorPosition, textObj.content.count)
        )
        textObj.content.insert(contentsOf: text, at: insertIndex)
        
        // Update cursor position
        currentCursorPosition += text.count
        currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
        
        // Update bounds and save back to document
        textObj.updateBounds()
        document.textObjects[textIndex] = textObj
        
        print("📝 Inserted '\(text)' at position \(currentCursorPosition - text.count)")
    }
    
    func deleteBackward() {
        guard let editingID = editingTextID,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }) else { return }
        
        var textObj = document.textObjects[textIndex]
        
        if currentSelectionRange.length > 0 {
            // Delete selected text
            deleteSelectedText()
        } else if currentCursorPosition > 0 {
            // Delete character before cursor
            let deleteIndex = textObj.content.index(
                textObj.content.startIndex,
                offsetBy: currentCursorPosition - 1
            )
            textObj.content.remove(at: deleteIndex)
            
            currentCursorPosition -= 1
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
            
            // Update bounds and save back to document
            textObj.updateBounds()
            document.textObjects[textIndex] = textObj
            
            print("⌫ Deleted character, cursor now at \(currentCursorPosition)")
        }
    }
    
    func deleteSelectedText() {
        guard let editingID = editingTextID,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }),
              currentSelectionRange.length > 0 else { return }
        
        var textObj = document.textObjects[textIndex]
        
        let startIndex = textObj.content.index(
            textObj.content.startIndex,
            offsetBy: currentSelectionRange.location
        )
        let endIndex = textObj.content.index(
            startIndex,
            offsetBy: currentSelectionRange.length
        )
        
        textObj.content.removeSubrange(startIndex..<endIndex)
        
        // Update cursor position
        currentCursorPosition = currentSelectionRange.location
        currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
        
        // Update bounds and save back to document
        textObj.updateBounds()
        document.textObjects[textIndex] = textObj
        
        print("🗑️ Deleted selected text, cursor now at \(currentCursorPosition)")
    }
    
    // MARK: - Text Selection
    
    func selectAll() {
        guard let editingID = editingTextID,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }) else { return }
        
        let textObj = document.textObjects[textIndex]
        currentSelectionRange = NSRange(location: 0, length: textObj.content.count)
        currentCursorPosition = textObj.content.count
        
        print("📋 Selected all text (\(textObj.content.count) characters)")
    }
    
    // MARK: - Arrow Key Navigation
    
    func moveCursorLeft() {
        if currentCursorPosition > 0 {
            currentCursorPosition -= 1
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
            print("← Cursor moved to position \(currentCursorPosition)")
        }
    }
    
    func moveCursorRight() {
        guard let editingID = editingTextID,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }) else { return }
        
        let textObj = document.textObjects[textIndex]
        if currentCursorPosition < textObj.content.count {
            currentCursorPosition += 1
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
            print("→ Cursor moved to position \(currentCursorPosition)")
        }
    }
    
    func moveCursorToBeginning() {
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
        print("⤴️ Cursor moved to beginning")
    }
    
    func moveCursorToEnd() {
        guard let editingID = editingTextID,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }) else { return }
        
        let textObj = document.textObjects[textIndex]
        currentCursorPosition = textObj.content.count
        currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
        print("⤵️ Cursor moved to end")
    }
    
    // MARK: - Finishing Text Editing
    
    func finishTextEditing() {
        if let editingID = editingTextID {
            // Mark text as not editing
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }) {
                document.textObjects[textIndex].isEditing = false
                document.textObjects[textIndex].updateBounds()
                
                // If text is empty, remove it
                if document.textObjects[textIndex].content.isEmpty {
                    document.textObjects.remove(at: textIndex)
                    document.selectedTextIDs.remove(editingID)
                    print("🗑️ Removed empty text object")
                }
            }
        }
        
        // Clear editing state
        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
        
        print("✅ Finished text editing")
    }
    
    func cancelTextEditing() {
        if let editingID = editingTextID {
            // If text is empty or was just created, remove it
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }) {
                if document.textObjects[textIndex].content.isEmpty {
                    document.textObjects.remove(at: textIndex)
                    document.selectedTextIDs.remove(editingID)
                } else {
                    document.textObjects[textIndex].isEditing = false
                }
            }
        }
        
        // Clear editing state
        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
        
        print("❌ Cancelled text editing")
    }
}

// MARK: - Text Editing Key Handling Extension
extension DrawingCanvas {
    
    func handleTextKeyPress(_ key: String) {
        guard isEditingText else { return }
        
        switch key {
        case "\u{08}": // Backspace
            deleteBackward()
        case "\u{7F}": // Delete
            deleteForward()
        case "\u{1B}": // Escape
            finishTextEditing()
        case "\u{0D}", "\u{0A}": // Return/Enter
            finishTextEditing()
        default:
            // Regular character input
            if key.count == 1 && !key.isEmpty {
                insertTextAtCursor(key)
            }
        }
    }
    
    private func deleteForward() {
        guard let editingID = editingTextID,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }) else { return }
        
        var textObj = document.textObjects[textIndex]
        
        if currentSelectionRange.length > 0 {
            deleteSelectedText()
        } else if currentCursorPosition < textObj.content.count {
            let deleteIndex = textObj.content.index(
                textObj.content.startIndex,
                offsetBy: currentCursorPosition
            )
            textObj.content.remove(at: deleteIndex)
            
            // Cursor position stays the same
            textObj.updateBounds()
            document.textObjects[textIndex] = textObj
            
            print("⌦ Deleted character forward")
        }
    }
} 

// MARK: - NEW: Text Box System Integration
extension DrawingCanvas {
    
    func handleTextSelectionChange(textID: UUID, isSelected: Bool) {
        if isSelected {
            // Select the text
            document.selectedTextIDs.insert(textID)
            document.selectedShapeIDs.removeAll() // Clear shape selection
            print("🎯 NEW TEXT BOX: Selected text \(textID)")
        } else {
            // Deselect the text
            document.selectedTextIDs.remove(textID)
            print("🎯 NEW TEXT BOX: Deselected text \(textID)")
        }
        document.objectWillChange.send()
    }
    
    func handleTextEditingChange(textID: UUID, isEditing: Bool) {
        if isEditing {
            // Start editing
            document.saveToUndoStack()
            isEditingText = true
            editingTextID = textID
            
            // Mark text as editing in document
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                document.textObjects[textIndex].isEditing = true
            }
            
            // Select the text
            document.selectedTextIDs.insert(textID)
            document.selectedShapeIDs.removeAll()
            
            print("✏️ NEW TEXT BOX: Started editing text \(textID)")
        } else {
            // Stop editing
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                document.textObjects[textIndex].isEditing = false
                
                // If text is empty, remove it
                if document.textObjects[textIndex].content.isEmpty {
                    document.textObjects.remove(at: textIndex)
                    document.selectedTextIDs.remove(textID)
                    print("🗑️ NEW TEXT BOX: Removed empty text object")
                }
            }
            
            // Clear editing state
            if editingTextID == textID {
                isEditingText = false
                editingTextID = nil
                currentCursorPosition = 0
                currentSelectionRange = NSRange(location: 0, length: 0)
            }
            
            print("✅ NEW TEXT BOX: Finished editing text \(textID)")
        }
        document.objectWillChange.send()
    }
    
    func handleTextContentChange(textID: UUID, newContent: String) {
        guard let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else { return }
        
        // Update text content
        document.textObjects[textIndex].content = newContent
        document.textObjects[textIndex].updateBounds()
        
        print("📝 NEW TEXT BOX: Updated text content to '\(newContent)'")
        document.objectWillChange.send()
    }
    
    func handleTextPositionChange(textID: UUID, newPosition: CGPoint) {
        guard let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        // Update text position
        document.textObjects[textIndex].position = newPosition
        
        print("📍 NEW TEXT BOX: Updated text position to \(newPosition)")
        document.objectWillChange.send()
    }
    
    func handleTextBoundsChange(textID: UUID, newBounds: CGRect) {
        guard let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        // Update text bounds
        document.textObjects[textIndex].bounds = newBounds
        
        print("📏 NEW TEXT BOX: Updated text bounds to \(newBounds)")
        document.objectWillChange.send()
    }
    
    // MARK: - Canvas Background Tap Handler (From Working NewTextBoxFontTool)
    
    func handleCanvasBackgroundTap(at location: CGPoint) {
        // AGGRESSIVE background tap handler - deselects ALL text boxes
        
        // Check if tapping outside all text boxes (use fixed 300pt width)
        let hitAnyTextBox = document.textObjects.contains { textObj in
            let textFrame = CGRect(
                x: textObj.position.x,
                y: textObj.position.y,
                width: 300,  // FIXED WIDTH - always 300pt for text boxes
                height: max(textObj.bounds.height, 100)
            )
            return textFrame.contains(location)
        }
        
        if !hitAnyTextBox {
            // AGGRESSIVELY deselect everything
            document.selectedTextIDs.removeAll()
            document.selectedShapeIDs.removeAll()
            
            // Stop editing any text that might be in edit mode
            for textIndex in document.textObjects.indices {
                if document.textObjects[textIndex].isEditing {
                    document.textObjects[textIndex].isEditing = false
                }
            }
            
            // Clear all editing state
            isEditingText = false
            editingTextID = nil
            
            print("🎯 AGGRESSIVE DESELECT: All text boxes → GRAY mode")
        }
    }
    
    // MARK: - Text Box Drawing (Rectangle Tool Style)
    
    /// Handle text box drawing like rectangle tool - user drags to define size
    func handleTextBoxDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        // CRITICAL: Comprehensive protection - no text creation in active states
        let isAnyTextEditing = document.textObjects.contains { $0.isEditing }
        let isAnyTextSelected = !document.selectedTextIDs.isEmpty
        
        if isAnyTextEditing {
            print("🚫 TEXT BOX DRAWING BLOCKED: A text box is in BLUE (edit) mode")
            return
        }
        
        if isAnyTextSelected {
            print("🚫 TEXT BOX DRAWING BLOCKED: Text boxes are in GREEN (selected) mode")
            return
        }
        
        // CRITICAL FIX: Don't create new text boxes while existing ones are being resized
        // Check if drag started on a text box resize handle
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let isDraggingResizeHandle = isLocationOnTextResizeHandle(startLocation)
        
        if isDraggingResizeHandle {
            print("🚫 FONT TOOL: Blocked - drag started on resize handle, not creating new text box")
            print("🚫 BLUE OUTLINE: Will NOT appear - this is a resize operation")
            return
        }
        
        // CRITICAL FIX: Also check if we're dragging ON TOP of an existing text box
        // This prevents creating overlapping text boxes
        if let existingTextID = findTextAt(location: startLocation) {
            print("🚫 FONT TOOL: Blocked - drag started on existing text box \(existingTextID.uuidString.prefix(8))")
            print("🚫 BLUE OUTLINE: Will NOT appear - would overlap existing text")
            return
        }
        
        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        
        if !isDrawing {
            // START DRAWING: Initialize shape creation state
            print("🎨 FONT TOOL: Starting text box creation (like rectangle tool)")
            print("🔵 BLUE OUTLINE: Will appear - creating new text box")
            isDrawing = true
            shapeDragStart = startLocation
            shapeStartPoint = startLocation
            drawingStartPoint = startLocation
        }
        
        // CONTINUE DRAWING: Update the text box creation rectangle
        let minX = min(shapeStartPoint.x, currentLocation.x)
        let minY = min(shapeStartPoint.y, currentLocation.y)
        let width = abs(currentLocation.x - shapeStartPoint.x)
        let height = abs(currentLocation.y - shapeStartPoint.y)
        
        // Ensure minimum size for text boxes
        let finalWidth = max(width, 50.0)  // Minimum 50pt width
        let finalHeight = max(height, 30.0) // Minimum 30pt height
        
        // Update current path for visual feedback (blue outline rectangle)
        currentPath = VectorPath(elements: [
            .move(to: VectorPoint(minX, minY)),
            .line(to: VectorPoint(minX + finalWidth, minY)),
            .line(to: VectorPoint(minX + finalWidth, minY + finalHeight)),
            .line(to: VectorPoint(minX, minY + finalHeight)),
            .close
        ])
        
        document.objectWillChange.send()
    }
    
    /// Finish text box drawing and create text with user-defined size
    func finishTextBoxDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let endLocation = screenToCanvas(value.location, geometry: geometry)
        
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        
        if dragDistance < 12.0 {
            // Small drag or click - create text with default size at click location
            createNewTextAt(location: startLocation)
            return
        }
        
        // Calculate text box dimensions
        let minX = min(startLocation.x, endLocation.x)
        let minY = min(startLocation.y, endLocation.y)
        let maxX = max(startLocation.x, endLocation.x)
        let maxY = max(startLocation.y, endLocation.y)
        
        let width = maxX - minX
        let height = maxY - minY
        
        // Ensure minimum size
        let finalWidth = max(width, 50.0)
        let finalHeight = max(height, 30.0)
        
        print("📝 TEXT BOX CREATED: User-drawn size (\(String(format: "%.1f", finalWidth)) × \(String(format: "%.1f", finalHeight)))")
        
        // Create text with user-defined size
        createNewTextWithSize(at: CGPoint(x: minX, y: minY), width: finalWidth, height: finalHeight)
    }
    
    /// Reset text box drawing state
    func resetTextBoxDrawingState() {
        let wasDrawing = isDrawing
        isDrawing = false
        currentPath = nil
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
        drawingStartPoint = nil
        
        if wasDrawing {
            print("🔵 BLUE OUTLINE: Cleared - text box creation finished")
        }
        print("📝 TEXT BOX DRAWING: State reset for next operation")
    }
    
    /// Check if location is on a text box resize handle
    private func isLocationOnTextResizeHandle(_ location: CGPoint) -> Bool {
        let handleRadius: Double = 6.0  // Resize handle size (blue circle)
        let tolerance: Double = 15.0    // Extra generous tolerance for easier detection
        let totalTolerance = handleRadius + tolerance
        
        print("🔍 RESIZE HANDLE CHECK: Testing location \(location)")
        
        for textObj in document.textObjects {
            if !textObj.isVisible || textObj.isLocked { continue }
            
            // Check ALL text boxes - editing, selected, and even unselected ones
            // This prevents accidental creation when dragging near any text box edge
            
            print("  - Checking text '\(textObj.content.prefix(20))' UUID: \(textObj.id.uuidString.prefix(8))")
            print("    Position: \(textObj.position), Bounds: \(textObj.bounds)")
            
            // Calculate text box bounds in canvas coordinates
            let textBounds = CGRect(
                x: textObj.position.x,
                y: textObj.position.y,
                width: max(textObj.bounds.width, 200.0),  // Use generous minimum width
                height: max(textObj.bounds.height, 60.0)   // Use generous minimum height
            )
            
            // Define all potential resize handle positions (8 handles around the text box)
            let handles = [
                // Corners
                CGPoint(x: textBounds.minX, y: textBounds.minY),         // Top-left
                CGPoint(x: textBounds.maxX, y: textBounds.minY),         // Top-right  
                CGPoint(x: textBounds.minX, y: textBounds.maxY),         // Bottom-left
                CGPoint(x: textBounds.maxX, y: textBounds.maxY),         // Bottom-right
                
                // Edges
                CGPoint(x: textBounds.midX, y: textBounds.minY),         // Top-center
                CGPoint(x: textBounds.midX, y: textBounds.maxY),         // Bottom-center
                CGPoint(x: textBounds.minX, y: textBounds.midY),         // Left-center
                CGPoint(x: textBounds.maxX, y: textBounds.midY),         // Right-center
            ]
            
            // Check if location is near any resize handle
            for (index, handle) in handles.enumerated() {
                let distance = sqrt(pow(location.x - handle.x, 2) + pow(location.y - handle.y, 2))
                if distance <= totalTolerance {
                    print("✅ RESIZE HANDLE HIT: Handle \(index) at \(handle), distance: \(String(format: "%.1f", distance))")
                    return true
                }
            }
            
            // ADDITIONAL CHECK: Also consider clicks near the text box edges as potential resize operations
            // This prevents accidental text creation when clicking near text boxes
            let edgeTolerance: Double = 25.0
            let expandedBounds = textBounds.insetBy(dx: -edgeTolerance, dy: -edgeTolerance)
            
            if expandedBounds.contains(location) && !textBounds.insetBy(dx: edgeTolerance, dy: edgeTolerance).contains(location) {
                print("✅ EDGE AREA HIT: Near text box edge, treating as potential resize operation")
                return true
            }
        }
        
        print("❌ NO RESIZE HANDLE: Location not near any text box resize handles")
        return false
    }
} 
