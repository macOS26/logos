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
    
    // MARK: - Professional Text Canvas Background Handler
    func handleAggressiveBackgroundTap(at location: CGPoint) {
        // AGGRESSIVE background tap - deselects ALL text boxes immediately
        let tapHitsText = document.textObjects.contains { textObj in
            let textBounds = CGRect(
                x: textObj.position.x,
                y: textObj.position.y,
                width: 300,  // FIXED WIDTH - always 300pt for text boxes
                height: max(textObj.bounds.height, 100)
            )
            return textBounds.contains(location)
        }
        
        if !tapHitsText {
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
            print("🎯 AGGRESSIVE X: All text boxes → GRAY mode")
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
    

    
    // Create new text at canvas position using our new professional text system
    func createNewTextAt(location: CGPoint) {
        // Default size for click creation
        createNewTextWithSize(at: location, width: 300, height: 100)
    }
    
    // Create new text with user-defined size (like rectangle tool)
    func createNewTextWithSize(at location: CGPoint, width: CGFloat, height: CGFloat) {
        print("✨ Creating new text box at: \(location) with user size: \(width) × \(height)")
        
        // Save state before creating new text
        document.saveToUndoStack()
        
        // Use current toolbar colors and font settings
        let typography = TypographyProperties(
            fontFamily: document.fontManager.selectedFontFamily,
            fontWeight: document.fontManager.selectedFontWeight,
            fontStyle: document.fontManager.selectedFontStyle,
            fontSize: document.fontManager.selectedFontSize,
            lineHeight: 0.0, // Default line height = 0
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
            content: "Text", // Start with placeholder text
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
        // CRITICAL FIX: Don't create new text boxes while existing ones are being resized
        // Check if drag started on a text box resize handle
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let isDraggingResizeHandle = isLocationOnTextResizeHandle(startLocation)
        
        if isDraggingResizeHandle {
            print("📝 TEXT TOOL: Blocked - drag started on resize handle, not creating new text box")
            return
        }
        
        // PROFESSIONAL TEXT BOX DRAWING: Same approach as shape drawing
        // User drags to define the text box size, no auto-resize
        
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        let minimumDragThreshold: Double = 12.0 // Must drag at least 12 pixels to start drawing
        
        // Only proceed with text box creation if user has dragged significantly
        if dragDistance < minimumDragThreshold {
            print("📝 TEXT TOOL: Drag distance (\(String(format: "%.1f", dragDistance))px) below threshold - CLICK will create default size")
            return
        }
        
        if !isDrawing {
            // Start drawing - initialize state once
            isDrawing = true
            
            // Capture reference positions (like shape tool)
            shapeDragStart = value.startLocation  // Reuse shape drawing state
            shapeStartPoint = screenToCanvas(value.startLocation, geometry: geometry)
            drawingStartPoint = shapeStartPoint
            
            print("📝 TEXT BOX DRAWING: Started at cursor position (\(String(format: "%.1f", shapeDragStart.x)), \(String(format: "%.1f", shapeDragStart.y)))")
        }
        
        // Calculate text box dimensions based on drag
        let currentCanvasLocation = screenToCanvas(value.location, geometry: geometry)
        
        let minX = min(shapeStartPoint.x, currentCanvasLocation.x)
        let minY = min(shapeStartPoint.y, currentCanvasLocation.y)
        let maxX = max(shapeStartPoint.x, currentCanvasLocation.x)
        let maxY = max(shapeStartPoint.y, currentCanvasLocation.y)
        
        let width = maxX - minX
        let height = maxY - minY
        
        // Create preview rectangle path for visual feedback (like shapes)
        let textBoxRect = CGRect(x: minX, y: minY, width: width, height: height)
        let path = VectorPath(elements: [
            .move(to: VectorPoint(minX, minY)),
            .line(to: VectorPoint(maxX, minY)),
            .line(to: VectorPoint(maxX, maxY)),
            .line(to: VectorPoint(minX, maxY)),
            .close
        ])
        
        currentPath = path
        
        print("📝 TEXT BOX DRAWING: Size (\(String(format: "%.1f", width)) × \(String(format: "%.1f", height)))")
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
        isDrawing = false
        currentPath = nil
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
        drawingStartPoint = nil
        print("📝 TEXT BOX DRAWING: State reset for next operation")
    }
    
    /// Check if location is on a text box resize handle
    private func isLocationOnTextResizeHandle(_ location: CGPoint) -> Bool {
        let handleRadius: Double = 4.0  // Resize handle size
        let tolerance: Double = 8.0     // Extra tolerance for easier detection
        let totalTolerance = handleRadius + tolerance
        
        for textObj in document.textObjects {
            if !textObj.isVisible || textObj.isLocked { continue }
            
            // Calculate text box bounds
            let textBounds = CGRect(
                x: textObj.position.x,
                y: textObj.position.y,
                width: textObj.bounds.width,
                height: textObj.bounds.height
            )
            
            // Check if text is selected (only selected text boxes show resize handles)
            if document.selectedTextIDs.contains(textObj.id) {
                // Check resize handle position (bottom-right corner)
                let resizeHandleCenter = CGPoint(
                    x: textBounds.maxX,
                    y: textBounds.maxY
                )
                
                let distance = sqrt(pow(location.x - resizeHandleCenter.x, 2) + pow(location.y - resizeHandleCenter.y, 2))
                
                if distance <= totalTolerance {
                    print("🔍 RESIZE HANDLE DETECTED: Location \(location) is on resize handle for text \(textObj.id)")
                    return true
                }
            }
        }
        
        return false
    }
} 
