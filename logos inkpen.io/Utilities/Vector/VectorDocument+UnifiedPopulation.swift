//
//  VectorDocument+UnifiedPopulation.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics

// MARK: - Unified Objects Population and Sync
extension VectorDocument {
    
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
        
        // After populating, sync back to layers
        // No longer syncing with layers[].shapes
        
        // For each layer, we need to create a truly unified ordering of ALL objects (shapes + text)
        for (layerIndex, layer) in layers.enumerated() {
            var layerObjects: [(object: Any, isText: Bool)] = []
            
            // DEBUG: Log all shapes in this layer before processing
            Log.info("🎭 UNIFIED SYNC LAYER DEBUG: Layer \(layerIndex) has \(layer.shapes.count) shapes:", category: .general)
            for shape in layer.shapes {
                if shape.isClippingPath || shape.clippedByShapeID != nil {
                    Log.info("🎭 UNIFIED SYNC LAYER DEBUG: - '\(shape.name)' - isClippingPath: \(shape.isClippingPath), clippedByShapeID: \(shape.clippedByShapeID?.uuidString.prefix(8) ?? "nil")", category: .general)
                } else {
                    Log.info("🎭 UNIFIED SYNC LAYER DEBUG: - '\(shape.name)' - regular shape", category: .general)
                }
            }
            
            // Add all shapes from this layer in their current order
            // MIGRATION: Shapes now include text objects (when isTextObject = true)
            for shape in layer.shapes {
                if shape.isTextObject {
                    // Text objects are already in the shapes array as VectorShape
                    layerObjects.append((object: shape, isText: true))
                } else {
                    layerObjects.append((object: shape, isText: false))
                }
            }
            
            // Now create unified objects with sequential orderIDs within this layer
            // PRESERVE ORIGINAL ORDER: First item gets lowest orderID (back), last item gets highest orderID (front)
            for (arrayIndex, item) in layerObjects.enumerated() {
                let orderID = arrayIndex // Preserve original order: first item gets lowest orderID (back)
                
                if item.isText {
                    // MIGRATION: Text is now stored as VectorShape with isTextObject = true
                    let shape = item.object as! VectorShape
                    let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
                    unifiedObjects.append(unifiedObject)
                } else {
                    let shape = item.object as! VectorShape
                    // DEBUG: Log ALL shapes during sync to see clipping state
                    Log.info("🎭 UNIFIED SYNC DEBUG: Processing shape '\(shape.name)' - isClippingPath: \(shape.isClippingPath), clippedByShapeID: \(shape.clippedByShapeID?.uuidString.prefix(8) ?? "nil")", category: .general)
                    
                    let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
                    
                    // DEBUG: Check if properties are still there after VectorObject creation
                    if case .shape(let copiedShape) = unifiedObject.objectType {
                        Log.info("🎭 UNIFIED SYNC DEBUG: After VectorObject creation for '\(copiedShape.name)' - isClippingPath: \(copiedShape.isClippingPath), clippedByShapeID: \(copiedShape.clippedByShapeID?.uuidString.prefix(8) ?? "nil")", category: .general)
                    }
                    unifiedObjects.append(unifiedObject)
                }
            }
        }
        
        Log.info("🔧 UNIFIED OBJECTS: Populated with \(unifiedObjects.count) objects preserving original order", category: .general)
        
        // Text is now fully managed in unified system
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
    
    // Text rebuild no longer needed - all text is accessed directly from unified system
    
    /// OPTIMIZED: Update unified objects without full sync - preserves text object order and IDs
    func updateUnifiedObjectsOptimized() {
        // Skip during undo/redo operations to preserve exact order
        if isUndoRedoOperation {
            return
        }
        
        // OPTIMIZED: Direct unified object updates for smooth performance
        for objectID in selectedObjectIDs {
            if let unifiedIndex = unifiedObjects.firstIndex(where: { $0.id == objectID }) {
                switch unifiedObjects[unifiedIndex].objectType {
                case .shape(let shape):
                    let layerIndex = unifiedObjects[unifiedIndex].layerIndex
                    
                    // MIGRATION: Sync all shapes (including text) from layers
                    if layerIndex < layers.count,
                       let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
                        // Update with latest shape data while preserving orderID
                        let updatedShape = layers[layerIndex].shapes[shapeIndex]
                        unifiedObjects[unifiedIndex] = VectorObject(
                            shape: updatedShape, 
                            layerIndex: layerIndex, 
                            orderID: unifiedObjects[unifiedIndex].orderID
                        )
                        
                        // Text is now fully managed in unified system
                    }
                }
            }
        }
        
        // Force immediate UI update
        objectWillChange.send()
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