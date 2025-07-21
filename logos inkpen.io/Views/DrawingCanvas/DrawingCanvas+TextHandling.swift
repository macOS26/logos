//
//  TextHandling.swift
//  logos inkpen.io
//
//  Created by Assistant on 1/20/25.
//

import SwiftUI
import Foundation

// MARK: - Text and Font Handling Extension
extension DrawingCanvas {
    
    // MARK: - Font Tool Handler (Core Graphics Based)
    
    func handleFontToolTap(at location: CGPoint) {
        print("🎯 FONT TOOL TAP at: \(location)")
        
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
            
            // CRITICAL FIX: Use actual text bounds (matches selection box exactly)
            // Text position is at baseline, bounds are calculated correctly in VectorText
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
        isEditingText = true
        editingTextID = textID
        
        // Find the text object and calculate cursor position
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
            document.textObjects[textIndex].isEditing = true
            
            // Simple cursor positioning - place at end of text for now
            textCursorPosition = document.textObjects[textIndex].content.count
            
            // Clear shape selection since we're editing text
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs.insert(textID)
        }
    }
    
    func createNewTextAt(location: CGPoint) {
        print("✨ Creating new text at: \(location)")
        
        // NO DEFAULT FONT COLORS - USE CURRENT TOOLBAR COLORS DIRECTLY  
        let typography = TypographyProperties(
            fontFamily: document.fontManager.selectedFontFamily,
            fontWeight: document.fontManager.selectedFontWeight,
            fontStyle: document.fontManager.selectedFontStyle,
            fontSize: document.fontManager.selectedFontSize,
            hasStroke: false, // SURGICAL FIX: Stroke off by default (professional standard)
            strokeColor: document.defaultStrokeColor,  // Current toolbar stroke color
            strokeOpacity: document.defaultStrokeOpacity,
            fillColor: document.defaultFillColor,      // Current toolbar fill color
            fillOpacity: document.defaultFillOpacity
        )
        
        // Clean text creation using drawing app color system
        
        // Create new text object with initial placeholder text
        let newText = VectorText(
            content: "",
            typography: typography,
            position: location,
            isEditing: true
        )
        
        // Add to document and associate with current layer
        document.addTextToLayer(newText, layerIndex: document.selectedLayerIndex)
        
        // CRITICAL FIX: Select the text so toolbar colors apply to it immediately
        document.selectedTextIDs = [newText.id]
        document.selectedShapeIDs.removeAll()  // Clear shape selection
        
        // Set editing state
        isEditingText = true
        editingTextID = newText.id
        textCursorPosition = 0
        
        print("✅ Created new editable text object with ID: \(newText.id) on layer \(document.selectedLayerIndex ?? -1)")
        print("🎯 Text automatically selected for immediate color application")
    }
    
    func finishTextEditing() {
        if let editingID = editingTextID {
            // CRITICAL FIX: Save to undo stack when finishing text editing
            // This captures all the text changes made during the editing session
            document.saveToUndoStack()
            
            // Mark text as not editing
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }) {
                document.textObjects[textIndex].isEditing = false
                document.textObjects[textIndex].updateBounds()
            }
        }
        
        // Clear editing state
        isEditingText = false
        editingTextID = nil
        textCursorPosition = 0
        
        print("✅ Finished text editing")
    }
    
    func cancelTextEditing() {
        if let editingID = editingTextID {
            // If text is empty, remove it
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
        textCursorPosition = 0
        
        print("❌ Cancelled text editing")
    }
} 
