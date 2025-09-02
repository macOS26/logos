//
//  VectorDocument+UnifiedObjectManagement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics

// MARK: - Unified Object Management
extension VectorDocument {
    /// Gets the next available orderID for a layer
    private func getNextOrderID(for layerIndex: Int) -> Int {
        let existingOrderIDs = unifiedObjects
            .filter { $0.layerIndex == layerIndex }
            .map { $0.orderID }
        
        return existingOrderIDs.isEmpty ? 0 : (existingOrderIDs.max() ?? -1) + 1
    }
    
    /// Adds a shape to the unified objects system
    func addShapeToUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        // CRITICAL FIX: During undo/redo operations, preserve the original orderID if available
        if isUndoRedoOperation {
            // Try to find an existing unified object for this shape to preserve its orderID
            if let existingObject = unifiedObjects.first(where: { 
                if case .shape(let existingShape) = $0.objectType {
                    return existingShape.id == shape.id
                }
                return false
            }) {
                // Use the existing orderID to preserve order
                let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: existingObject.orderID)
                unifiedObjects.append(unifiedObject)
                return
            }
        }
        
        let orderID = getNextOrderID(for: layerIndex)
        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
        unifiedObjects.append(unifiedObject)
    }
    
    /// Adds a shape to the front of the unified objects system (for drawing tools)
    func addShapeToFrontOfUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        // CRITICAL FIX: During undo/redo operations, preserve the original orderID if available
        if isUndoRedoOperation {
            // Try to find an existing unified object for this shape to preserve its orderID
            if let existingObject = unifiedObjects.first(where: { 
                if case .shape(let existingShape) = $0.objectType {
                    return existingShape.id == shape.id
                }
                return false
            }) {
                // Use the existing orderID to preserve order
                let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: existingObject.orderID)
                unifiedObjects.append(unifiedObject)
                return
            }
        }
        
        // Get the highest orderID for this layer and add 1 to put the new shape on top
        let existingOrderIDs = unifiedObjects
            .filter { $0.layerIndex == layerIndex }
            .map { $0.orderID }
        
        let highestOrderID = existingOrderIDs.isEmpty ? 0 : (existingOrderIDs.max() ?? 0)
        let orderID = highestOrderID + 1
        
        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
        unifiedObjects.append(unifiedObject)
    }
    
    /// Adds a shape BEHIND existing shapes in the unified objects system (for positive offset paths)
    func addShapeBehindInUnifiedSystem(_ shape: VectorShape, layerIndex: Int, behindShapeIDs: Set<UUID>) {
        // Find the lowest orderID among the shapes we want to go behind
        let targetOrderIDs = unifiedObjects
            .filter { $0.layerIndex == layerIndex }
            .compactMap { unifiedObj -> Int? in
                switch unifiedObj.objectType {
                case .shape(let existingShape):
                    return behindShapeIDs.contains(existingShape.id) ? unifiedObj.orderID : nil
                }
            }
        
        let orderID: Int
        if let minTargetOrderID = targetOrderIDs.min() {
            // Insert with an orderID just before the minimum target orderID
            orderID = minTargetOrderID - 1
        } else {
            // Fallback: use lowest orderID for this layer minus 1
            let existingOrderIDs = unifiedObjects
                .filter { $0.layerIndex == layerIndex }
                .map { $0.orderID }
            orderID = (existingOrderIDs.min() ?? 0) - 1
        }
        
        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
        unifiedObjects.append(unifiedObject)
    }
    
    /// Adds a text object as VectorShape to the unified objects system
    func addTextToUnifiedSystem(_ text: VectorText, layerIndex: Int) {
        // Convert VectorText to VectorShape
        let textShape = VectorShape.from(text)
        
        // CRITICAL FIX: During undo/redo operations, preserve the original orderID if available
        if isUndoRedoOperation {
            // Try to find an existing unified object for this text to preserve its orderID
            if let existingObject = unifiedObjects.first(where: { 
                if case .shape(let existingShape) = $0.objectType {
                    return existingShape.id == text.id
                }
                return false
            }) {
                // Use the existing orderID to preserve order
                let unifiedObject = VectorObject(shape: textShape, layerIndex: layerIndex, orderID: existingObject.orderID)
                unifiedObjects.append(unifiedObject)
                return
            }
        }
        
        let orderID = getNextOrderID(for: layerIndex)
        let unifiedObject = VectorObject(shape: textShape, layerIndex: layerIndex, orderID: orderID)
        unifiedObjects.append(unifiedObject)
    }
    
    /// ⚠️ DEPRECATED: This function REVERSES layer order and should NOT be used!
    /// USE populateUnifiedObjectsFromLayersPreservingOrder() instead to prevent layer corruption
    /// CRITICAL: This creates a truly unified ordering where text and shapes can be intermixed
    @available(*, deprecated, message: "Use populateUnifiedObjectsFromLayersPreservingOrder() instead - this function reverses order!")
    internal func populateUnifiedObjectsFromLayers() {
        // CRITICAL SAFEGUARD: Prevent this dangerous function from executing - always call the safe version instead
        Log.error("⚠️ CRITICAL BUG PREVENTED: populateUnifiedObjectsFromLayers() blocked to prevent layer corruption! Using safe version.", category: .error)
        populateUnifiedObjectsFromLayersPreservingOrder()
        return
    }
    
    /// Populates the unified objects array from existing layers and text objects
    /// PRESERVES ORIGINAL ORDER: This version maintains the original stacking order from imports
    internal func populateUnifiedObjectsFromLayersPreservingOrder() {
        // CRITICAL FIX: Skip reordering during undo/redo operations to preserve exact order
        if isUndoRedoOperation {
            Log.info("🔧 POPULATE: Skipping unified objects population during undo/redo operation to preserve order", category: .general)
            return
        }
        
        unifiedObjects.removeAll()
        
        // For each layer, we need to create a truly unified ordering of ALL objects (shapes + text)
        for (layerIndex, layer) in layers.enumerated() {
            var layerObjects: [(object: Any, isText: Bool)] = []
            
            // Add all shapes from this layer in their current order
            for shape in layer.shapes {
                layerObjects.append((object: shape, isText: false))
            }
            
            // Add all text objects that belong to this layer
            for text in textObjects {
                if let textLayerIndex = text.layerIndex, textLayerIndex == layerIndex {
                    layerObjects.append((object: text, isText: true))
                } else if text.layerIndex == nil && layerIndex == (selectedLayerIndex ?? 2) {
                    // Legacy text objects without layer assignment go to working layer
                    layerObjects.append((object: text, isText: true))
                }
            }
            
            // Now create unified objects with sequential orderIDs within this layer
            // PRESERVE ORIGINAL ORDER: First item gets lowest orderID (back), last item gets highest orderID (front)
            for (arrayIndex, item) in layerObjects.enumerated() {
                let orderID = arrayIndex // Preserve original order: first item gets lowest orderID (back)
                
                if item.isText {
                    let text = item.object as! VectorText
                    let textShape = VectorShape.from(text)
                    let unifiedObject = VectorObject(shape: textShape, layerIndex: layerIndex, orderID: orderID)
                    unifiedObjects.append(unifiedObject)
                } else {
                    let shape = item.object as! VectorShape
                    let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
                    unifiedObjects.append(unifiedObject)
                }
            }
        }
        
        Log.info("🔧 UNIFIED OBJECTS: Populated with \(unifiedObjects.count) objects preserving original order", category: .general)
    }
    
    /// Sync selection arrays to maintain compatibility with existing code
    func syncSelectionArrays() {
        // Update selectedShapeIDs and selectedTextIDs based on selectedObjectIDs
        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()
        
        for objectID in selectedObjectIDs {
            if let unifiedObject = unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        selectedTextIDs.insert(shape.id)
                    } else {
                        selectedShapeIDs.insert(shape.id)
                    }
                }
            }
        }
    }
    
    /// Sync unified selection from legacy selection arrays
    func syncUnifiedSelectionFromLegacy() {
        selectedObjectIDs.removeAll()
        
        // Add selected shapes
        for shapeID in selectedShapeIDs {
            if let unifiedObject = unifiedObjects.first(where: { 
                if case .shape(let shape) = $0.objectType {
                    return shape.id == shapeID
                }
                return false
            }) {
                selectedObjectIDs.insert(unifiedObject.id)
            }
        }
        
        // Add selected text objects (now represented as VectorShape with isTextObject = true)
        for textID in selectedTextIDs {
            if let unifiedObject = unifiedObjects.first(where: { 
                if case .shape(let shape) = $0.objectType {
                    return shape.isTextObject && shape.id == textID
                }
                return false
            }) {
                selectedObjectIDs.insert(unifiedObject.id)
            }
        }
    }
    
    /// CRITICAL FIX: Update unified objects ordering to match layer ordering
    private func updateUnifiedObjectsOrdering() {
        // Re-populate unified objects to reflect any changes in layer ordering
        populateUnifiedObjectsFromLayersPreservingOrder()
        
        // Re-sync selection to maintain selected objects
        syncUnifiedSelectionFromLegacy()
        
        Log.fileOperation("🔧 UNIFIED OBJECTS: Updated ordering to match layer changes", level: .info)
    }
    
    /// CRITICAL FIX: Sync legacy arrays from unified objects array
    private func syncLegacyArraysFromUnified() {
        // CRITICAL FIX: Preserve original objects before clearing arrays to maintain state
        _ = textObjects
        let originalShapes = layers.map { $0.shapes }
        
        // Clear existing legacy arrays
        for layerIndex in layers.indices {
            layers[layerIndex].shapes.removeAll()
        }
        textObjects.removeAll()
        
        // Rebuild legacy arrays from unified objects, maintaining order
        for unifiedObject in unifiedObjects.sorted(by: { $0.orderID < $1.orderID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    // Convert VectorShape back to VectorText for legacy textObjects array
                    if let textContent = shape.textContent, let typography = shape.typography {
                        let position = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                        let vectorText = VectorText(
                            content: textContent,
                            typography: typography,
                            position: position,
                            transform: .identity,
                            isVisible: shape.isVisible,
                            isLocked: shape.isLocked,
                            isEditing: shape.isEditing ?? false,
                            layerIndex: unifiedObject.layerIndex,
                            isPointText: shape.isPointText ?? true,
                            cursorPosition: shape.cursorPosition ?? 0,
                            areaSize: shape.areaSize
                        )
                        // Note: VectorText.id is let, so we can't change it
                        // We'll need to update VectorText.id to be var if we want to preserve IDs
                        textObjects.append(vectorText)
                    }
                } else {
                    // Regular shape - use original shape from layers array to preserve all state
                    if let originalShape = originalShapes[unifiedObject.layerIndex].first(where: { $0.id == shape.id }) {
                        layers[unifiedObject.layerIndex].shapes.append(originalShape)
                    } else {
                        layers[unifiedObject.layerIndex].shapes.append(shape)
                    }
                }
            }
        }
        
        Log.fileOperation("🔧 LEGACY ARRAYS: Synced from unified objects", level: .info)
    }
    
    /// CRITICAL FIX: Sync unified objects when shape properties change (colors, etc.)
    func syncUnifiedObjectsAfterPropertyChange() {
        // CRITICAL FIX: Skip reordering during undo/redo operations to preserve exact order
        if isUndoRedoOperation {
            Log.info("🔧 SYNC: Skipping unified objects sync during undo/redo operation to preserve order", category: .general)
            return
        }
        
        // CRITICAL FIX: Remove unified objects that no longer exist in legacy arrays
        let beforeCount = unifiedObjects.count
        unifiedObjects.removeAll { unifiedObject in
            switch unifiedObject.objectType {
            case .shape(let shape):
                // CRITICAL PROTECTION: Never remove Canvas or Pasteboard background shapes
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    // Logging removed - background shapes are always preserved
                    return false // Never remove background shapes
                }
                
                // Check if shape still exists in layers array
                if let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil {
                    let exists = layers[layerIndex].shapes.contains { $0.id == shape.id }
                    if !exists {
                        Log.info("🗑️ SYNC: Removing unified object for deleted shape '\(shape.name)' (ID: \(shape.id.uuidString.prefix(8)))", category: .general)
                    }
                    return !exists
                } else {
                    Log.info("🗑️ SYNC: Removing unified object for shape in non-existent layer", category: .general)
                    return true // Remove if layer doesn't exist
                }
            }
        }
        
        let afterRemovalCount = unifiedObjects.count
        let removedCount = beforeCount - afterRemovalCount
        if removedCount > 0 {
            Log.info("🧹 SYNC: Removed \(removedCount) orphaned unified objects", category: .general)
        }
        
        // Update unified objects to reflect property changes in layers
        for i in unifiedObjects.indices {
            let unifiedObject = unifiedObjects[i]
            
            switch unifiedObject.objectType {
            case .shape(let oldShape):
                // CRITICAL PROTECTION: Never modify Canvas or Pasteboard background shapes
                if oldShape.name == "Canvas Background" || oldShape.name == "Pasteboard Background" {
                    // Logging removed - background shapes are always skipped
                    continue // Skip updating background shapes
                }
                
                // Find the updated shape in the layers array
                if let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil,
                   let updatedShape = layers[layerIndex].shapes.first(where: { $0.id == oldShape.id }) {
                    // Update the unified object with the changed shape (deferred to avoid SwiftUI publishing warnings)
                    let newObject = VectorObject(
                        shape: updatedShape,
                        layerIndex: unifiedObject.layerIndex,
                        orderID: unifiedObject.orderID
                    )
                    DispatchQueue.main.async { [weak self] in
                        self?.unifiedObjects[i] = newObject
                    }
                }
            }
        }
        
        // CRITICAL FIX: Ensure all text objects are in unified system
        let textUnifiedObjects = unifiedObjects.filter { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isTextObject
            }
            return false
        }
        
        let missingTextObjects = textObjects.filter { text in
            !textUnifiedObjects.contains { unifiedObject in
                if case .shape(let unifiedShape) = unifiedObject.objectType {
                    return unifiedShape.isTextObject && unifiedShape.id == text.id
                }
                return false
            }
        }
        
        if !missingTextObjects.isEmpty {
            Log.info("🔧 SYNC: Found \(missingTextObjects.count) text objects missing from unified system", category: .general)
            for text in missingTextObjects {
                Log.info("  - Adding missing text: '\(text.content.prefix(20))' (ID: \(text.id.uuidString.prefix(8)))", category: .general)
                addTextToUnifiedSystem(text, layerIndex: text.layerIndex ?? (selectedLayerIndex ?? 2))
            }
        }
    }
    
    /// CRITICAL FIX: Force complete resync of unified objects system
    func forceResyncUnifiedObjects() {
        // CRITICAL FIX: Skip reordering during undo/redo operations to preserve exact order
        if isUndoRedoOperation {
            Log.info("🔧 FORCE RESYNC: Skipping unified objects resync during undo/redo operation to preserve order", category: .general)
            return
        }
        
        Log.info("🔧 FORCE RESYNC: Rebuilding unified objects system", category: .general)
        populateUnifiedObjectsFromLayersPreservingOrder()
        Log.info("🔧 FORCE RESYNC: Unified objects system rebuilt with \(unifiedObjects.count) objects", category: .general)
    }
    
    /// CRITICAL FIX: Restore Canvas and Pasteboard layers if they get corrupted
    func restoreSystemLayers() {
        Log.info("🔧 SYSTEM RESTORE: Checking and restoring Canvas and Pasteboard layers", category: .general)
        
        // Check if Canvas layer exists and has background shape
        if layers.count < 2 || layers[1].name != "Canvas" || 
           !layers[1].shapes.contains(where: { $0.name == "Canvas Background" }) {
            Log.error("🚨 SYSTEM RESTORE: Canvas layer corrupted - recreating", category: .error)
            createCanvasAndWorkingLayers()
            return
        }
        
        // Check if Pasteboard layer exists and has background shape
        if layers.count < 1 || layers[0].name != "Pasteboard" || 
           !layers[0].shapes.contains(where: { $0.name == "Pasteboard Background" }) {
            Log.error("🚨 SYSTEM RESTORE: Pasteboard layer corrupted - recreating", category: .error)
            createCanvasAndWorkingLayers()
            return
        }
        
        Log.info("✅ SYSTEM RESTORE: Canvas and Pasteboard layers are intact", category: .general)
    }
}