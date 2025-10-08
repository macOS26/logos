//
//  VectorDocument+TextManagement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import CoreText
import AppKit

// MARK: - Text Management
extension VectorDocument {
    
    // MARK: - Professional Text Management
    func addText(_ text: VectorText) {
        saveToUndoStack()
        
        // Add to unified system with current layer
        if let layerIndex = selectedLayerIndex {
            addTextToUnifiedSystem(text, layerIndex: layerIndex)
        }
        
        selectedTextIDs = [text.id]
        selectedObjectIDs = [text.id]
        selectedShapeIDs.removeAll() // Clear shape selection (mutually exclusive)
        syncSelectionArrays()
    }
    
    func addTextToLayer(_ text: VectorText, layerIndex: Int?) {
        guard let layerIndex = layerIndex,
              layerIndex >= 0 && layerIndex < layers.count else {
            // Fallback to global text objects if no valid layer
            addText(text)
            return
        }
        
        saveToUndoStack()
        
        // Associate text with specific layer by storing layer reference
        var modifiedText = text
        modifiedText.layerIndex = layerIndex
        
        // Add to unified system
        addTextToUnifiedSystem(modifiedText, layerIndex: layerIndex)
        
        selectedTextIDs = [text.id]
        selectedObjectIDs = [text.id]
        selectedShapeIDs.removeAll() // Clear shape selection (mutually exclusive)
        selectedLayerIndex = layerIndex // Select the layer we added text to
        syncSelectionArrays()
        
    }
    
    func removeSelectedText() {
        saveToUndoStack()
        
        // MIGRATION: Remove text shapes from layers
        for textID in selectedTextIDs {
            for layerIndex in layers.indices {
                removeShapesUnified(layerIndex: layerIndex, where: { $0.id == textID && $0.isTextObject })
            }
        }
        
        // Remove from unified system
        unifiedObjects.removeAll { obj in
            if case .shape(let shape) = obj.objectType {
                return selectedTextIDs.contains(shape.id) && shape.isTextObject
            }
            return false
        }
        
        // Text is now fully managed in unified system
        
        selectedTextIDs.removeAll()
    }
    
    func duplicateSelectedText() {
        guard !selectedTextIDs.isEmpty else { return }
        saveToUndoStack()
        
        var newTextIDs: Set<UUID> = []
        
        for textID in selectedTextIDs {
            if let originalText = findText(by: textID) {
                // Create duplicate with slight offset
                var duplicateText = originalText
                duplicateText.id = UUID() // New unique ID
                duplicateText.position = CGPoint(
                    x: originalText.position.x + 10, // 10pt offset
                    y: originalText.position.y + 10
                )
                // CRITICAL FIX: Don't call updateBounds() - preserve original bounds from ProfessionalTextCanvas
                // duplicateText.updateBounds() - REMOVED because it uses old single-line algorithm

                // UNIFIED SYSTEM: Use unified helper instead of direct manipulation
                if let layerIndex = originalText.layerIndex ?? selectedLayerIndex {
                    addTextToUnifiedSystem(duplicateText, layerIndex: layerIndex)
                }
                newTextIDs.insert(duplicateText.id)
            }
        }
        
        // Select the duplicated text objects
        selectedTextIDs = newTextIDs
    }
    
    // MARK: - Helper method for updating text in unified system
    func updateTextInUnified(_ updatedText: VectorText) {
        // Find and update in unified objects
        if let unifiedIndex = unifiedObjects.firstIndex(where: { $0.id == updatedText.id }),
           case .shape(_) = unifiedObjects[unifiedIndex].objectType {
            
            // Convert to shape and update
            let updatedShape = VectorShape.from(updatedText)
            unifiedObjects[unifiedIndex] = VectorObject(
                shape: updatedShape,
                layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                orderID: unifiedObjects[unifiedIndex].orderID
            )
            
            // Text is now fully managed in unified system
        }
    }
    
    // PROFESSIONAL TEXT TO OUTLINES CONVERSION - USES WORKING PROFESSIONALTEXT IMPLEMENTATION
    func convertSelectedTextToOutlines() {
        guard !selectedTextIDs.isEmpty else { return }

        saveToUndoStack()

        let selectedTexts = selectedTextIDs.compactMap { textID in findText(by: textID) }
        var newShapeIDs: Set<UUID> = []

        // Track shapes before conversion - only count non-text shapes
        let shapesBefore = unifiedObjects.compactMap { obj -> UUID? in
            if case .shape(let shape) = obj.objectType, !shape.isTextObject {
                return shape.id
            }
            return nil
        }
        let shapesBeforeSet = Set(shapesBefore)

        for textObj in selectedTexts {
            // CRITICAL: Use ProfessionalTextCanvas convertToPath logic
            let viewModel = ProfessionalTextViewModel(textObject: textObj, document: self)

            // Call the new word-by-word convertToPath method
            viewModel.convertToPath()
        }

        // Track shapes after conversion - only count non-text shapes
        let shapesAfter = unifiedObjects.compactMap { obj -> UUID? in
            if case .shape(let shape) = obj.objectType, !shape.isTextObject {
                return shape.id
            }
            return nil
        }
        let shapesAfterSet = Set(shapesAfter)

        // Find new shapes created
        newShapeIDs = shapesAfterSet.subtracting(shapesBeforeSet)

        if !newShapeIDs.isEmpty {
            // Remove the original text objects from unified system
            unifiedObjects.removeAll { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.isTextObject && selectedTextIDs.contains(shape.id)
                }
                return false
            }

            // Clear text selection and select new shapes
            selectedTextIDs.removeAll()
            selectedShapeIDs = newShapeIDs

        } else {
            Log.error("❌ TEXT TO OUTLINES FAILED: No new shapes were created", category: .error)
        }

        // Text is now fully managed in unified system
    }
    
    
    func updateTextContent(_ textID: UUID, content: String) {
        // PERFORMANCE FIX: Don't save to undo stack on every keystroke - only when editing ends
        // saveToUndoStack() - REMOVED to prevent performance issues during typing
        
        // Use unified helper instead of direct property access
        updateTextContentInUnified(id: textID, content: content)
    }
}
