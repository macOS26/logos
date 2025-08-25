//
//  VectorDocument+ObjectVisibility.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation

// MARK: - Object Visibility & Locking
extension VectorDocument {
    
    // MARK: - Lock/Unlock Methods
    
    /// Lock selected objects
    func lockSelectedObjects() {
        guard !selectedShapeIDs.isEmpty || !selectedTextIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // Lock selected shapes
        for layerIndex in layers.indices {
            for shapeIndex in layers[layerIndex].shapes.indices {
                if selectedShapeIDs.contains(layers[layerIndex].shapes[shapeIndex].id) {
                    layers[layerIndex].shapes[shapeIndex].isLocked = true
                }
            }
        }
        
        // Lock selected text objects
        for textIndex in textObjects.indices {
            if selectedTextIDs.contains(textObjects[textIndex].id) {
                textObjects[textIndex].isLocked = true
            }
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
        for shapeIndex in layers[layerIndex].shapes.indices {
            if layers[layerIndex].shapes[shapeIndex].isLocked {
                layers[layerIndex].shapes[shapeIndex].isLocked = false
                unlockedCount += 1
            }
        }
        
        // Unlock all text objects (they're global)
        for textIndex in textObjects.indices {
            if textObjects[textIndex].isLocked {
                textObjects[textIndex].isLocked = false
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
            for shapeIndex in layers[layerIndex].shapes.indices {
                if selectedShapeIDs.contains(layers[layerIndex].shapes[shapeIndex].id) {
                    layers[layerIndex].shapes[shapeIndex].isVisible = false
                }
            }
        }
        
        // Hide selected text objects
        for textIndex in textObjects.indices {
            if selectedTextIDs.contains(textObjects[textIndex].id) {
                textObjects[textIndex].isVisible = false
            }
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
        for shapeIndex in layers[layerIndex].shapes.indices {
            if !layers[layerIndex].shapes[shapeIndex].isVisible {
                layers[layerIndex].shapes[shapeIndex].isVisible = true
                shownCount += 1
            }
        }
        
        // Show all text objects (they're global)
        for textIndex in textObjects.indices {
            if !textObjects[textIndex].isVisible {
                textObjects[textIndex].isVisible = true
                shownCount += 1
            }
        }
        
        Log.info("👁️ Shown \(shownCount) objects", category: .general)
    }
}
