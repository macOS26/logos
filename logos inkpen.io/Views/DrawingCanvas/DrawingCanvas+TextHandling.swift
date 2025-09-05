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
        Log.fileOperation("🎯 FONT TOOL TAP at: \(location)", level: .info)
        lastTapLocation = location
        
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
        
        Log.info("🔍 BACKGROUND TAP: Checking if location \(location) hits any text", category: .general)
        
        // Use the same generous hit testing logic as findTextAt
        let tapHitsText = document.allTextObjects.contains { textObj in
            if !textObj.isVisible || textObj.isLocked { return false }
            
            // Use the same three hit testing methods as findTextAt
            let textContentArea = CGRect(
                x: textObj.position.x,
                y: textObj.position.y,
                width: textObj.bounds.width,
                height: textObj.bounds.height
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
                Log.fileOperation("🎯 BACKGROUND TAP: Hit text '\(textObj.content.prefix(20))'", level: .info)
            }
            
            return hits
        }
        
        if !tapHitsText {
            Log.fileOperation("🎯 BACKGROUND TAP: No text hit - deselecting all", level: .info)
            // AGGRESSIVELY deselect everything
            document.selectedTextIDs.removeAll()
            document.selectedShapeIDs.removeAll()
            
            // Stop all editing
            for textObject in document.getAllTextObjects() {
                if textObject.isEditing {
                    document.setTextEditingInUnified(id: textObject.id, isEditing: false)
                }
            }
            
            finishTextEditing()
            Log.fileOperation("🎯 AGGRESSIVE DESELECT: All text boxes → GRAY mode", level: .info)
        } else {
            Log.fileOperation("🎯 BACKGROUND TAP: Text hit - no deselection", level: .info)
        }
    }
    
    func findTextAt(location: CGPoint) -> UUID? {
        Log.info("🔍 FIND TEXT: Looking for text at location \(location)", category: .general)
        
        for textObj in document.getAllTextObjects() {
            if !textObj.isVisible || textObj.isLocked { continue }
            
            // ACCURATE HIT TESTING: Use precise text bounds with minimal tolerance
            // This allows easy deselection by clicking outside the text
            
            // Calculate the actual text bounds in canvas coordinates
            let textBounds = CGRect(
                x: textObj.position.x + textObj.bounds.minX,
                y: textObj.position.y + textObj.bounds.minY,
                width: textObj.bounds.width,
                height: textObj.bounds.height
            )
            
            // Use exact bounds with zero tolerance for precise hit testing
            let hitArea = textBounds
            
            Log.info("🔍 TEXT CHECK: '\(textObj.content.prefix(20))' UUID: \(textObj.id.uuidString.prefix(8))", category: .general)
            Log.info("  - Text bounds: \(textBounds)", category: .general)
            Log.info("  - Hit area: \(hitArea)", category: .general)
            
            // Hit test using precise bounds with minimal tolerance
            if hitArea.contains(location) {
                Log.info("✅ TEXT HIT: Found text '\(textObj.content.prefix(20))' at location", category: .fileOperations)
                return textObj.id
            }
        }
        
        return nil
    }
    
    func startEditingText(textID: UUID, at location: CGPoint) {
        Log.info("✏️ Starting to edit existing text: \(textID)", category: .general)
        
        // Save current state before editing
        document.saveToUndoStack()
        
        // CRITICAL: Ensure only one text box can be in edit mode at a time
        var editingCount = 0
        let allTextObjects = document.getAllTextObjects()
        for textObject in allTextObjects {
            if textObject.isEditing {
                editingCount += 1
                Log.fileOperation("🔄 STOPPING EDIT: Text box \(textObject.id.uuidString.prefix(8)) was in edit mode", level: .info)
            }
            document.setTextEditingInUnified(id: textObject.id, isEditing: false)
        }
        
        if editingCount > 0 {
            Log.fileOperation("🔄 STOPPED \(editingCount) text box(es) that were in edit mode", level: .info)
        }
        
        // Find and start editing the target text  
        if let textObject = document.allTextObjects.first(where: { $0.id == textID }) {
            
            Log.info("✏️ STARTING EDIT MODE:", category: .general)
            Log.info("  - Text: '\(textObject.content)'", category: .general)
            Log.info("  - Font: \(textObject.typography.fontFamily) \(textObject.typography.fontSize)pt", category: .general)
            Log.info("  - State: GRAY/GREEN → BLUE (editing)", category: .general)
            Log.info("  - Click location: (\(String(format: "%.1f", location.x)), \(String(format: "%.1f", location.y)))", category: .general)
            
            // CRITICAL: Set editing state BEFORE updating selection
            document.setTextEditingInUnified(id: textObject.id, isEditing: true)
            
            // Clear other selections and select this text
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs = [textID]
            
            // Update editing state
            isEditingText = true
            editingTextID = textID
            
            // Calculate cursor position at click location
            let cursorPosition = calculateCursorPosition(in: textObject, at: location)
            currentCursorPosition = cursorPosition
            currentSelectionRange = NSRange(location: cursorPosition, length: 0)
            
            // CRITICAL: Also update the VectorText's cursor position directly
            document.updateTextCursorPositionInUnified(id: textObject.id, cursorPosition: cursorPosition)
            
            Log.info("🎯 CURSOR POSITIONING: Set cursor position \(cursorPosition) for click at (\(String(format: "%.1f", location.x)), \(String(format: "%.1f", location.y)))", category: .general)
            Log.info("🎯 CURSOR POSITIONING: Updated VectorText.cursorPosition = \(cursorPosition)", category: .general)
            
            Log.info("✅ TEXT EDITING STARTED: Text box \(textID.uuidString.prefix(8)) is now in BLUE (edit) mode", category: .fileOperations)
        } else {
            Log.error("❌ TEXT NOT FOUND: Could not find text with ID \(textID)", category: .error)
        }
    }
    
    // ENHANCED: Better double-click detection and corner circle support
    func handleTextBoxInteraction(textID: UUID, isDoubleClick: Bool = false, isCornerClick: Bool = false) {
        Log.fileOperation("🎯 TEXT BOX INTERACTION: textID=\(textID.uuidString.prefix(8)), doubleClick=\(isDoubleClick), cornerClick=\(isCornerClick)", level: .info)
        
        guard let textObject = document.allTextObjects.first(where: { $0.id == textID }) else {
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
                    startEditingText(textID: textID, at: .zero)
                    Log.fileOperation("🎯 CORNER CLICK WITH FONT TOOL: GRAY → GREEN → BLUE", level: .info)
                }
                
            case .selected: // GREEN
                // Double-click on green text field: switch to font tool and start editing
                if isDoubleClick {
                    // Switch to font tool
                    document.currentTool = .font
                    Log.fileOperation("🔧 DOUBLE-CLICK: Switched to font tool", level: .info)
                    
                    // Start editing the text
                    startEditingText(textID: textID, at: .zero)
                    Log.fileOperation("🎯 DOUBLE-CLICK: GREEN → BLUE (switched to font tool)", level: .info)
                } else if document.currentTool == .font {
                    // Single click with font tool active - start editing
                    startEditingText(textID: textID, at: .zero)
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
    
    // MARK: - Enhanced Cursor Positioning
    
    func calculateCursorPosition(in textObj: VectorText, at tapLocation: CGPoint) -> Int {
        // Convert tap location to text-relative coordinates
        let relativePoint = CGPoint(
            x: tapLocation.x - textObj.position.x,
            y: tapLocation.y - textObj.position.y
        )
        
        Log.info("🎯 CURSOR CALC: Tap at (\(String(format: "%.1f", tapLocation.x)), \(String(format: "%.1f", tapLocation.y))), relative (\(String(format: "%.1f", relativePoint.x)), \(String(format: "%.1f", relativePoint.y)))", category: .general)
        
        // Create a temporary text layout similar to NSTextView to get accurate positioning
        let nsFont = textObj.typography.nsFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .kern: textObj.typography.letterSpacing
        ]
        
        let attributedString = NSAttributedString(string: textObj.content, attributes: attributes)
        
        // Create text container with similar settings to NSTextView
        let textContainer = NSTextContainer(containerSize: CGSize(
            width: textObj.bounds.width,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        
        // Create layout manager
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        
        // Create text storage
        let textStorage = NSTextStorage(attributedString: attributedString)
        textStorage.addLayoutManager(layoutManager)
        
        // Ensure layout is complete
        layoutManager.ensureLayout(for: textContainer)
        
        // Convert relative point to character index using layout manager
        let characterIndex = layoutManager.characterIndex(
            for: relativePoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        let finalIndex = max(0, min(textObj.content.count, characterIndex))
        
        Log.info("🎯 CURSOR CALC: Character index \(finalIndex) for text '\(textObj.content.prefix(20))'", category: .general)
        
        return finalIndex
    }
    
    /// Update the text view model's cursor position for proper NSTextView synchronization
    private func updateTextViewModelCursorPosition(textID: UUID, position: Int, length: Int) {
        // ENHANCED: Store the desired cursor position in the text object itself temporarily
        // This will be picked up by the view model when it syncs
        if document.allTextObjects.contains(where: { $0.id == textID }) {
            // Store cursor position in a temporary property or use a custom approach
            Log.info("🎯 TEXT VIEW MODEL: Storing cursor position \(position) for textID \(textID.uuidString.prefix(8))", category: .general)
            
            // For now, rely on the fact that the NSTextView will be created fresh when editing starts
            // and we can set the cursor position at that time
            
            // Add a custom property to VectorText to track desired cursor position
            // This is a temporary solution until we can implement a better architecture
        }
    }
    
    // MARK: - Text Creation and Management
    

    
    // Create new text at canvas position using our new professional text system
    func createNewTextAt(location: CGPoint) {
        // Default size for click creation
        createNewTextWithSize(at: location, width: 300, height: 100)
    }
    
    // Create new text with user-defined size (like rectangle tool)
    func createNewTextWithSize(at location: CGPoint, width: CGFloat, height: CGFloat) {
        Log.info("✨ Creating new text box at: \(location) with user size: \(width) × \(height)", category: .general)

        
        // Save state before creating new text
        document.saveToUndoStack()
        
        // Use current toolbar colors and font settings
        let typography = TypographyProperties(
            fontFamily: document.fontManager.selectedFontFamily,
            fontWeight: document.fontManager.selectedFontWeight,
            fontStyle: document.fontManager.selectedFontStyle,
            fontSize: document.fontManager.selectedFontSize,
            lineHeight: document.fontManager.selectedLineHeight, // FIXED: Use font manager's line height
            lineSpacing: document.fontManager.selectedLineSpacing, // FIXED: Use font manager's line spacing
            letterSpacing: 0.0,
            alignment: document.fontManager.selectedTextAlignment, // FIXED: Use font manager's alignment
            hasStroke: false, // NO STROKES - only fill colors
            strokeColor: document.defaultStrokeColor,
            strokeOpacity: document.defaultStrokeOpacity,
            fillColor: document.defaultFillColor, // Use current fill color
            fillOpacity: document.defaultFillOpacity
        )
        
        Log.fileOperation("🔤 TYPOGRAPHY CREATION:", level: .info)
        Log.info("  - Font Manager Line Spacing: \(document.fontManager.selectedLineSpacing)", category: .general)
        Log.info("  - Typography Line Spacing: \(typography.lineSpacing)", category: .general)
        Log.info("  - Font Manager Line Height: \(document.fontManager.selectedLineHeight)", category: .general)
        Log.info("  - Typography Line Height: \(typography.lineHeight)", category: .general)
        Log.info("  - Font Manager Alignment: \(document.fontManager.selectedTextAlignment)", category: .general)
        Log.info("  - Typography Alignment: \(typography.alignment)", category: .general)
        
        // Create new text object with USER-DEFINED bounds
        var newText = VectorText(
            content: "", // Start with placeholder text
            typography: typography,
            position: location,
            isEditing: true
        )
        
        // CRITICAL: Set bounds AND areaSize to user-drawn size, NOT calculated size
        newText.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        newText.areaSize = CGSize(width: width, height: height) // CRITICAL FIX: Preserve user-drawn dimensions
        
        // Add to document and associate with current layer
        document.addTextToLayer(newText, layerIndex: document.selectedLayerIndex!)
        
        // Select the text for immediate editing
        document.selectedTextIDs = [newText.id]
        document.selectedShapeIDs.removeAll()
        
        // Set editing state for compatibility with existing system
        isEditingText = true
        editingTextID = newText.id
        
        // Initialize cursor position
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
        
        Log.info("✅ Created text box with USER-DEFINED size: \(width) × \(height)", category: .fileOperations)
        Log.fileOperation("🎯 Text ready for editing - size will NOT change unless user manually resizes", level: .info)
        Log.fileOperation("🎯 Cursor initialized at position 0", level: .info)
    }
    
    // MARK: - Professional Text Input Handling
    
    func insertTextAtCursor(_ text: String) {
        guard let editingID = editingTextID,
              var textObj = document.allTextObjects.first(where: { $0.id == editingID }) else { return }
        
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
        document.updateTextInUnified(textObj)
        
        Log.fileOperation("📝 Inserted '\(text)' at position \(currentCursorPosition - text.count)", level: .info)
    }
    
    func deleteBackward() {
        guard let editingID = editingTextID,
              var textObj = document.allTextObjects.first(where: { $0.id == editingID }) else { return }
        
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
            document.updateTextInUnified(textObj)
            
            Log.info("⌫ Deleted character, cursor now at \(currentCursorPosition)", category: .general)
        }
    }
    
    func deleteSelectedText() {
        guard let editingID = editingTextID,
              var textObj = document.allTextObjects.first(where: { $0.id == editingID }),
              currentSelectionRange.length > 0 else { return }
        
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
        document.updateTextInUnified(textObj)
        
        Log.info("🗑️ Deleted selected text, cursor now at \(currentCursorPosition)", category: .general)
    }
    
    // MARK: - Text Selection
    
    func selectAll() {
        guard let editingID = editingTextID,
              let textObj = document.allTextObjects.first(where: { $0.id == editingID }) else { return }
        currentSelectionRange = NSRange(location: 0, length: textObj.content.count)
        currentCursorPosition = textObj.content.count
        
        Log.fileOperation("📋 Selected all text (\(textObj.content.count) characters)", level: .info)
    }
    
    // MARK: - Arrow Key Navigation
    
    func moveCursorLeft() {
        if currentCursorPosition > 0 {
            currentCursorPosition -= 1
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
            Log.info("← Cursor moved to position \(currentCursorPosition)", category: .general)
        }
    }
    
    func moveCursorRight() {
        guard let editingID = editingTextID,
              let textObj = document.allTextObjects.first(where: { $0.id == editingID }) else { return }
        if currentCursorPosition < textObj.content.count {
            currentCursorPosition += 1
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
            Log.info("→ Cursor moved to position \(currentCursorPosition)", category: .general)
        }
    }
    
    func moveCursorToBeginning() {
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
        Log.info("⤴️ Cursor moved to beginning", category: .general)
    }
    
    func moveCursorToEnd() {
        guard let editingID = editingTextID,
              let textObj = document.allTextObjects.first(where: { $0.id == editingID }) else { return }
        currentCursorPosition = textObj.content.count
        currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
        Log.info("⤵️ Cursor moved to end", category: .general)
    }
    
    // MARK: - Finishing Text Editing
    
    func finishTextEditing() {
        if let editingID = editingTextID {
            // Mark text as not editing
            if var textObj = document.allTextObjects.first(where: { $0.id == editingID }) {
                document.setTextEditingInUnified(id: textObj.id, isEditing: false)
                textObj.updateBounds()
                document.updateTextInUnified(textObj)
                
                // If text is empty, remove it
                if textObj.content.isEmpty {
                    document.unifiedObjects.removeAll { $0.id == editingID }
                    document.textObjects.removeAll { $0.id == editingID }
                    document.selectedTextIDs.remove(editingID)
                    Log.info("🗑️ Removed empty text object", category: .general)
                }
            }
        }
        
        // Clear editing state
        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
        
        // Reset text editing cursor mode
        isTextEditingMode = false
        #if os(macOS)
        // Reset cursor to default arrow when exiting text editing
        NSCursor.arrow.set()
        Log.info("🎯 TEXT EDITING: Exited text editing mode - reset cursor to arrow", category: .selection)
        #endif
        
        Log.info("✅ Finished text editing", category: .fileOperations)
    }
    
    func cancelTextEditing() {
        if let editingID = editingTextID {
            // If text is empty or was just created, remove it
            if let textObj = document.allTextObjects.first(where: { $0.id == editingID }) {
                if textObj.content.isEmpty {
                    document.unifiedObjects.removeAll { $0.id == editingID }
                    document.textObjects.removeAll { $0.id == editingID }
                    document.selectedTextIDs.remove(editingID)
                } else {
                    document.setTextEditingInUnified(id: textObj.id, isEditing: false)
                }
            }
        }
        
        // Clear editing state
        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
        
        // Reset text editing cursor mode
        isTextEditingMode = false
        #if os(macOS)
        // Reset cursor to default arrow when cancelling text editing
        NSCursor.arrow.set()
        Log.info("🎯 TEXT EDITING: Cancelled text editing mode - reset cursor to arrow", category: .selection)
        #endif
        
        Log.error("❌ Cancelled text editing", category: .error)
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
              var textObj = document.allTextObjects.first(where: { $0.id == editingID }) else { return }
        
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
            document.updateTextInUnified(textObj)
            
            Log.info("⌦ Deleted character forward", category: .general)
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
            Log.fileOperation("🎯 NEW TEXT BOX: Selected text \(textID)", level: .info)
        } else {
            // Deselect the text
            document.selectedTextIDs.remove(textID)
            Log.fileOperation("🎯 NEW TEXT BOX: Deselected text \(textID)", level: .info)
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
            if let textObj = document.allTextObjects.first(where: { $0.id == textID }) {
                document.setTextEditingInUnified(id: textObj.id, isEditing: true)
            }
            
            // Select the text
            document.selectedTextIDs.insert(textID)
            document.selectedShapeIDs.removeAll()
            
            Log.info("✏️ NEW TEXT BOX: Started editing text \(textID)", category: .general)
        } else {
            // Stop editing
            if let textObj = document.allTextObjects.first(where: { $0.id == textID }) {
                document.setTextEditingInUnified(id: textObj.id, isEditing: false)
                
                // If text is empty, remove it
                if textObj.content.isEmpty {
                    document.unifiedObjects.removeAll { $0.id == textID }
                    document.textObjects.removeAll { $0.id == textID }
                    document.selectedTextIDs.remove(textID)
                    Log.info("🗑️ NEW TEXT BOX: Removed empty text object", category: .general)
                }
            }
            
            // Clear editing state
            if editingTextID == textID {
                isEditingText = false
                editingTextID = nil
                currentCursorPosition = 0
                currentSelectionRange = NSRange(location: 0, length: 0)
            }
            
            Log.info("✅ NEW TEXT BOX: Finished editing text \(textID)", category: .fileOperations)
        }
        document.objectWillChange.send()
    }
    
    func handleTextContentChange(textID: UUID, newContent: String) {
        guard var textObj = document.allTextObjects.first(where: { $0.id == textID }) else { return }
        
        // Update text content
        document.updateTextContentInUnified(id: textObj.id, content: newContent)
        textObj.updateBounds()
        document.updateTextInUnified(textObj)
        
        Log.fileOperation("📝 NEW TEXT BOX: Updated text content to '\(newContent)'", level: .info)
        document.objectWillChange.send()
    }
    
    func handleTextPositionChange(textID: UUID, newPosition: CGPoint) {
        guard let textObj = document.allTextObjects.first(where: { $0.id == textID }) else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        // Update text position
        document.updateTextPositionInUnified(id: textObj.id, position: newPosition)
        
        Log.info("📍 NEW TEXT BOX: Updated text position to \(newPosition)", category: .general)
        document.objectWillChange.send()
    }
    
    func handleTextBoundsChange(textID: UUID, newBounds: CGRect) {
        guard let textObj = document.allTextObjects.first(where: { $0.id == textID }) else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        // Update text bounds
        document.updateTextBoundsInUnified(id: textObj.id, bounds: newBounds)
        
        Log.info("📏 NEW TEXT BOX: Updated text bounds to \(newBounds)", category: .general)
        document.objectWillChange.send()
    }
    
    // MARK: - Canvas Background Tap Handler (From Working NewTextBoxFontTool)
    
    func handleCanvasBackgroundTap(at location: CGPoint) {
        // AGGRESSIVE background tap handler - deselects ALL text boxes
        
        // Check if tapping outside all text boxes (use fixed 300pt width)
        let hitAnyTextBox = document.allTextObjects.contains { textObj in
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
            for textObject in document.getAllTextObjects() {
                if textObject.isEditing {
                    document.setTextEditingInUnified(id: textObject.id, isEditing: false)
                }
            }
            
            // Clear all editing state
            isEditingText = false
            editingTextID = nil
            
            Log.fileOperation("🎯 AGGRESSIVE DESELECT: All text boxes → GRAY mode", level: .info)
        }
    }
    
    // MARK: - Text Box Drawing (Rectangle Tool Style)
    
    /// Handle text box drawing like rectangle tool - user drags to define size
    func handleTextBoxDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        // CRITICAL FIX: Don't create new text boxes when any text box is in editing mode (blue state)
        let hasEditingTextBox = document.allTextObjects.contains { $0.isEditing }
        if hasEditingTextBox {
            Log.info("🚫 FONT TOOL: Blocked - text box is in editing mode, not creating new text box", category: .general)
            Log.info("🚫 BLUE OUTLINE: Will NOT appear - this is a resize operation", category: .general)
            return
        }
        
        // CRITICAL FIX: Don't create new text boxes while existing ones are being resized
        // Check if drag started on a text box resize handle
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let isDraggingResizeHandle = isLocationOnTextResizeHandle(startLocation)
        
        if isDraggingResizeHandle {
            Log.info("🚫 FONT TOOL: Blocked - drag started on resize handle, not creating new text box", category: .general)
            Log.info("🚫 BLUE OUTLINE: Will NOT appear - this is a resize operation", category: .general)
            return
        }
        
        // CRITICAL FIX: Also check if we're dragging ON TOP of an existing text box
        // This prevents creating overlapping text boxes
        if let existingTextID = findTextAt(location: startLocation) {
            Log.info("🚫 FONT TOOL: Blocked - drag started on existing text box \(existingTextID.uuidString.prefix(8))", category: .general)
            Log.info("🚫 BLUE OUTLINE: Will NOT appear - would overlap existing text", category: .general)
            return
        }
        
        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        
        if !isDrawing {
            // START DRAWING: Initialize shape creation state
            Log.fileOperation("🎨 FONT TOOL: Starting text box creation (like rectangle tool)", level: .info)
            Log.info("🔵 BLUE OUTLINE: Will appear - creating new text box", category: .general)
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
        // CRITICAL FIX: Don't create new text boxes when any text box is in editing mode (blue state)
        let hasEditingTextBox = document.allTextObjects.contains { $0.isEditing }
        if hasEditingTextBox {
            Log.info("🚫 FONT TOOL: Blocked - text box is in editing mode, not creating new text box", category: .general)
            return
        }
        
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
            Log.info("🔵 BLUE OUTLINE: Cleared - text box creation finished", category: .general)
        }
        Log.fileOperation("📝 TEXT BOX DRAWING: State reset for next operation", level: .info)
    }
    
    /// Check if location is on a text box resize handle
    private func isLocationOnTextResizeHandle(_ location: CGPoint) -> Bool {
        let handleRadius: Double = 6.0  // Resize handle size (blue circle)
        let tolerance: Double = 15.0    // Extra generous tolerance for easier detection
        let totalTolerance = handleRadius + tolerance
        
        Log.info("🔍 RESIZE HANDLE CHECK: Testing location \(location)", category: .general)
        
        for textObj in document.getAllTextObjects() {
            if !textObj.isVisible || textObj.isLocked { continue }
            
            // Check ALL text boxes - editing, selected, and even unselected ones
            // This prevents accidental creation when dragging near any text box edge
            
            Log.info("  - Checking text '\(textObj.content.prefix(20))' UUID: \(textObj.id.uuidString.prefix(8))", category: .general)
            Log.info("    Position: \(textObj.position), Bounds: \(textObj.bounds)", category: .general)
            
            // Calculate text box bounds in canvas coordinates (use actual bounds)
            let textBounds = CGRect(
                x: textObj.position.x + textObj.bounds.minX,
                y: textObj.position.y + textObj.bounds.minY,
                width: textObj.bounds.width,
                height: textObj.bounds.height
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
            let edgeTolerance: Double = 0.0  // Set to 0.0 for exact text box selection
            let expandedBounds = textBounds.insetBy(dx: -edgeTolerance, dy: -edgeTolerance)
            
            if expandedBounds.contains(location) && !textBounds.insetBy(dx: edgeTolerance, dy: edgeTolerance).contains(location) {
                Log.info("✅ EDGE AREA HIT: Near text box edge, treating as potential resize operation", category: .fileOperations)
                return true
            }
        }
        
        Log.error("❌ NO RESIZE HANDLE: Location not near any text box resize handles", category: .error)
        return false
    }
} 
