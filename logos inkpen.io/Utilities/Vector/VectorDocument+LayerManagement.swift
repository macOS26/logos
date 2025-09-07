//
//  VectorDocument+LayerManagement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics

// MARK: - Layer Management
extension VectorDocument {
    /// Rename a layer at the specified index
    func renameLayer(at index: Int, to newName: String) {
        guard index >= 0 && index < layers.count else {
            Log.error("❌ Invalid layer index for rename: \(index)", category: .error)
            return
        }
        
        // Don't allow renaming Canvas layer
        if index == 0 && layers[index].name == "Canvas" {
            Log.info("🚫 Cannot rename Canvas layer", category: .general)
            return
        }
        
        let oldName = layers[index].name
        layers[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        saveToUndoStack()
        Log.info("✏️ Renamed layer '\(oldName)' to '\(layers[index].name)'", category: .general)
    }
    
    /// Duplicate a layer at the specified index
    func duplicateLayer(at index: Int) {
        guard index >= 0 && index < layers.count else {
            Log.error("❌ Invalid layer index for duplicate: \(index)", category: .error)
            return
        }
        
        // Don't allow duplicating Canvas layer
        if index == 0 && layers[index].name == "Canvas" {
            Log.info("🚫 Cannot duplicate Canvas layer", category: .general)
            return
        }
        
        saveToUndoStack()
        
        let originalLayer = layers[index]
        var duplicatedLayer = VectorLayer(name: "\(originalLayer.name) Copy")
        
        // Copy all properties
        duplicatedLayer.isVisible = originalLayer.isVisible
        duplicatedLayer.isLocked = originalLayer.isLocked
        duplicatedLayer.opacity = originalLayer.opacity
        
        // Deep copy all shapes with new IDs
        for shape in originalLayer.shapes {
            var duplicatedShape = shape
            duplicatedShape.id = UUID() // New unique ID
            // If this shape carries raster content, duplicate the image registry entry to the new ID
            if ImageContentRegistry.containsImage(shape),
               let image = ImageContentRegistry.image(for: shape.id) {
                ImageContentRegistry.register(image: image, for: duplicatedShape.id)
            }
            duplicatedLayer.shapes.append(duplicatedShape)
        }
        
        // Insert the duplicated layer right after the original
        layers.insert(duplicatedLayer, at: index + 1)
        
        // Update unified objects after layer structure change
        updateUnifiedObjectsOptimized()
        
        // Select the new layer
        selectedLayerIndex = index + 1
        
        Log.fileOperation("📋 Duplicated layer '\(originalLayer.name)' to '\(duplicatedLayer.name)'", level: .info)
    }
    
    /// Move a layer from one index to another
    func moveLayer(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < layers.count,
              targetIndex >= 0 && targetIndex <= layers.count,  // Allow targetIndex == layers.count for "move to top"
              sourceIndex != targetIndex else {
            Log.error("❌ Invalid layer indices for move: source=\(sourceIndex), target=\(targetIndex)", category: .error)
            return
        }
        
        // PROTECT PASTEBOARD LAYER: Never allow Pasteboard layer to be moved
        if sourceIndex == 0 && layers[sourceIndex].name == "Pasteboard" {
            Log.info("🚫 Cannot move Pasteboard layer - it must remain at the bottom", category: .general)
            return
        }
        
        // PROTECT CANVAS LAYER: Never allow Canvas layer to be moved
        if sourceIndex == 1 && layers[sourceIndex].name == "Canvas" {
            Log.info("🚫 Cannot move Canvas layer - it must remain above pasteboard", category: .general)
            return
        }
        
        // PROTECT PASTEBOARD LAYER: Never allow moving to Pasteboard position
        if targetIndex == 0 {
            Log.info("🚫 Cannot move layers to Pasteboard position (index 0)", category: .general)
            return
        }
        
        // PROTECT CANVAS LAYER: Never allow moving to Canvas position
        if targetIndex == 1 && targetIndex < layers.count && layers[targetIndex].name == "Canvas" {
            Log.info("🚫 Cannot move layers to Canvas position (index 1)", category: .general)
            return
        }
        
        saveToUndoStack()
        
        let movingLayer = layers.remove(at: sourceIndex)
        
        // Handle insertion logic
        let adjustedTargetIndex: Int
        if targetIndex == layers.count {
            // Special case: move to top (append to end after removal)
            adjustedTargetIndex = layers.count
            Log.info("🔝 Moving to top position (will be index \(adjustedTargetIndex))", category: .general)
        } else if sourceIndex < targetIndex {
            // Moving forward in the array - adjust for removal
            adjustedTargetIndex = targetIndex - 1
        } else {
            // Moving backward in the array - no adjustment needed
            adjustedTargetIndex = targetIndex
        }
        
        layers.insert(movingLayer, at: adjustedTargetIndex)
        
        // Update selected layer index to follow the moved layer
        if selectedLayerIndex == sourceIndex {
            selectedLayerIndex = adjustedTargetIndex
        } else if let selectedIndex = selectedLayerIndex {
            // Adjust selection if it was affected by the move
            if sourceIndex < selectedIndex && adjustedTargetIndex >= selectedIndex {
                selectedLayerIndex = selectedIndex - 1
            } else if sourceIndex > selectedIndex && adjustedTargetIndex <= selectedIndex {
                selectedLayerIndex = selectedIndex + 1
            }
        }
        
        Log.fileOperation("🔄 Moved layer '\(movingLayer.name)' from index \(sourceIndex) to \(adjustedTargetIndex)", level: .info)
    }
    
    func addLayer(name: String = "New Layer") {
        layers.append(VectorLayer(name: name))
        selectedLayerIndex = layers.count - 1
    }
    
    func removeLayer(at index: Int) {
        // Allow deletion of any layer, just prevent deleting the last layer
        guard index >= 0 && index < layers.count && layers.count > 1 else { 
            Log.fileOperation("⚠️ Cannot remove last remaining layer", level: .info)
            return 
        }
        layers.remove(at: index)
        if selectedLayerIndex == index {
            selectedLayerIndex = min(index, layers.count - 1)
        } else if let selected = selectedLayerIndex, selected > index {
            selectedLayerIndex = selected - 1
        }
    }
}