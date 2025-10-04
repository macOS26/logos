//
//  VectorDocument+ObjectVisibility.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Object Visibility & Locking
extension VectorDocument {
    
    // MARK: - Lock/Unlock Methods
    
    /// Lock selected objects
    func lockSelectedObjects() {
        guard !selectedShapeIDs.isEmpty || !selectedTextIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // Lock selected shapes
        for layerIndex in layers.indices {
            let shapes = getShapesForLayer(layerIndex)
            for (shapeIndex, shape) in shapes.enumerated() {
                if selectedShapeIDs.contains(shape.id) {
                    var updatedShape = shape
                    updatedShape.isLocked = true
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                }
            }
        }
        
        // Lock selected text objects using unified helpers
        for textID in selectedTextIDs {
            lockTextInUnified(id: textID)
        }
        
        Log.info("🔒 Locked \(selectedShapeIDs.count) shapes and \(selectedTextIDs.count) text objects", category: .general)
        
        // Clear selection since locked objects can't be selected
        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()
    }
    
    /// Unlock all objects on current layer
    func unlockAllObjects() {
        guard let layerIndex = selectedLayerIndex else { return }
        
        saveToUndoStack()
        
        var unlockedCount = 0
        
        // Unlock all shapes on current layer
        let shapes = getShapesForLayer(layerIndex)
        for (shapeIndex, shape) in shapes.enumerated() {
            if shape.isLocked {
                var updatedShape = shape
                updatedShape.isLocked = false
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                unlockedCount += 1
            }
        }
        
        // Unlock all text objects using unified helpers
        for unifiedObj in unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject, shape.isLocked == true {
                unlockTextInUnified(id: shape.id)
                unlockedCount += 1
            }
        }
        
        Log.info("🔓 Unlocked \(unlockedCount) objects", category: .general)
    }
    
    // MARK: - Hide/Show Methods
    
    /// Hide selected objects
    func hideSelectedObjects() {
        guard !selectedShapeIDs.isEmpty || !selectedTextIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // Hide selected shapes
        for layerIndex in layers.indices {
            let shapes = getShapesForLayer(layerIndex)
            for (shapeIndex, shape) in shapes.enumerated() {
                if selectedShapeIDs.contains(shape.id) {
                    var updatedShape = shape
                    updatedShape.isVisible = false
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                }
            }
        }
        
        // Hide selected text objects using unified helpers
        for textID in selectedTextIDs {
            hideTextInUnified(id: textID)
        }
        
        Log.info("👁️‍🗨️ Hidden \(selectedShapeIDs.count) shapes and \(selectedTextIDs.count) text objects", category: .general)
        
        // Clear selection since hidden objects can't be selected
        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()
    }
    
    /// Show all objects on current layer
    func showAllObjects() {
        guard let layerIndex = selectedLayerIndex else { return }
        
        saveToUndoStack()
        
        var shownCount = 0
        
        // Show all shapes on current layer
        let shapes = getShapesForLayer(layerIndex)
        for (shapeIndex, shape) in shapes.enumerated() {
            if !shape.isVisible {
                var updatedShape = shape
                updatedShape.isVisible = true
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                shownCount += 1
            }
        }
        
        // Show all text objects using unified helpers
        for unifiedObj in unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject, shape.isVisible == false {
                showTextInUnified(id: shape.id)
                shownCount += 1
            }
        }
        
        Log.info("👁️ Shown \(shownCount) objects", category: .general)
    }
}
