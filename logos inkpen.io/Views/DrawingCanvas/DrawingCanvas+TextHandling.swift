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
        
        // Check if tapping on existing text to edit it
        if let existingTextID = findTextAt(location: location) {
            startEditingText(textID: existingTextID, at: location)
        } else {
            // Create new text at tap location
            createNewTextAt(location: location)
        }
    }
    
    func findTextAt(location: CGPoint) -> UUID? {
        let tolerance: Double = 10.0
        
        for textObj in document.textObjects {
            if !textObj.isVisible || textObj.isLocked { continue }
            
            // Use actual text bounds (matches selection box exactly)
            let absoluteBounds = CGRect(
                x: textObj.position.x + textObj.bounds.minX,
                y: textObj.position.y + textObj.bounds.minY,
                width: textObj.bounds.width,
                height: textObj.bounds.height
            )
            
            // Expand bounds slightly for easier selection
            let expandedBounds = CGRect(
                x: absoluteBounds.minX - tolerance,
                y: absoluteBounds.minY - tolerance,
                width: absoluteBounds.width + (tolerance * 2),
                height: absoluteBounds.height + (tolerance * 2)
            )
            
            if expandedBounds.contains(location) {
                return textObj.id
            }
        }
        
        return nil
    }
    
    func startEditingText(textID: UUID, at location: CGPoint) {
        print("✏️ Starting to edit existing text: \(textID)")
        
        // Save current state before editing
        document.saveToUndoStack()
        
        isEditingText = true
        editingTextID = textID
        
        // Find the text object and calculate precise cursor position
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
            document.textObjects[textIndex].isEditing = true
            
            // ENHANCED: Calculate cursor position based on click location
            let textObj = document.textObjects[textIndex]
            currentCursorPosition = calculateCursorPosition(in: textObj, at: location)
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
            
            // Clear shape selection since we're editing text
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs.insert(textID)
            
            print("📍 Cursor positioned at character \(currentCursorPosition)")
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
    
    // Create new text at canvas position
    func createNewTextAt(location: CGPoint) {
        print("✨ Creating new text at: \(location)")
        
        // Save state before creating new text
        document.saveToUndoStack()
        
        // Use current toolbar colors (no defaults)
        let typography = TypographyProperties(
            fontFamily: document.fontManager.selectedFontFamily,
            fontWeight: document.fontManager.selectedFontWeight,
            fontStyle: document.fontManager.selectedFontStyle,
            fontSize: document.fontManager.selectedFontSize,
            hasStroke: false, // Professional default: text fill only (like Adobe Illustrator)
            strokeColor: document.defaultStrokeColor,
            strokeOpacity: document.defaultStrokeOpacity,
            fillColor: document.defaultFillColor,
            fillOpacity: document.defaultFillOpacity
        )
        
        // Create new text object
        let newText = VectorText(
            content: "",
            typography: typography,
            position: location,
            isEditing: true
        )
        
        // Add to document and associate with current layer
        document.addTextToLayer(newText, layerIndex: document.selectedLayerIndex!)
        
        // Select the text so toolbar colors apply immediately
        document.selectedTextIDs = [newText.id]
        document.selectedShapeIDs.removeAll()
        
        // Set editing state
        isEditingText = true
        editingTextID = newText.id
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
        
        print("✅ Created new editable text object with ID: \(newText.id)")
        print("🎯 Text automatically selected for immediate color application")
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
} 
