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
        
        // DETAILED LOGGING: Determine if this is canvas or pasteboard area
        let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612) // Standard canvas
        let isInCanvasArea = canvasBounds.contains(location)
        let areaType = isInCanvasArea ? "CANVAS AREA" : "PASTEBOARD AREA"
        
        print("🎯 FONT TOOL TAP at: \(location) in \(areaType)")
        
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
        
        // FIXED: Use document default colors from toolbar (exactly like pen tool and shape tools)
        // Create typography using document defaults or user-selected font properties
        // CRITICAL: Ensure text is visible by using black if default fill is white/clear
        let fillColor = (document.defaultFillColor == .white || document.defaultFillColor == .clear) ? .black : document.defaultFillColor
        
        let typography = TypographyProperties(
            fontFamily: document.fontManager.selectedFontFamily,
            fontWeight: document.fontManager.selectedFontWeight,
            fontStyle: document.fontManager.selectedFontStyle,
            fontSize: document.fontManager.selectedFontSize,
            hasStroke: document.defaultStrokeColor != .clear && document.defaultStrokeColor != .white,
            strokeColor: document.defaultStrokeColor,
            strokeOpacity: document.defaultStrokeOpacity,
            fillColor: fillColor,
            fillOpacity: document.defaultFillOpacity
        )
        
        print("🎨 FONT TOOL COLORS: fill=\(fillColor) (default was \(document.defaultFillColor)), stroke=\(document.defaultStrokeColor)")
        print("🎨 FONT TOOL OPACITIES: fillOpacity=\(document.defaultFillOpacity), strokeOpacity=\(document.defaultStrokeOpacity)")
        
        // Create new text object with initial placeholder text
        let newText = VectorText(
            content: "",
            typography: typography,
            position: location,
            isEditing: true
        )
        
        // Add to document and associate with current layer
        document.addTextToLayer(newText, layerIndex: document.selectedLayerIndex)
        
        // Set editing state
        isEditingText = true
        editingTextID = newText.id
        textCursorPosition = 0
        
        print("✅ Created new editable text object with ID: \(newText.id) on layer \(document.selectedLayerIndex ?? -1)")
    }
    
    func finishTextEditing() {
        if let editingID = editingTextID {
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