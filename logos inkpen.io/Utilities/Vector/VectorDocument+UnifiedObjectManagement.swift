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
        // CRITICAL FIX: Check for existing object to prevent duplicates
        let existingIndex = unifiedObjects.firstIndex { unifiedObject in
            if case .shape(let existingShape) = unifiedObject.objectType {
                return existingShape.id == shape.id
            }
            return false
        }
        
        // If object already exists, remove it first to prevent duplicates
        if let existingIndex = existingIndex {
            unifiedObjects.remove(at: existingIndex)
        }
        
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
        
        // CRITICAL FIX: Only add to legacy layers array if shape doesn't already exist there
        if layerIndex < layers.count {
            let shapeExists = layers[layerIndex].shapes.contains { $0.id == shape.id }
            if !shapeExists {
                layers[layerIndex].shapes.append(shape)
            }
        }
        
        let orderID = getNextOrderID(for: layerIndex)
        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
        unifiedObjects.append(unifiedObject)
    }
    
    /// Adds a shape to the front of the unified objects system (for drawing tools)
    func addShapeToFrontOfUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        // CRITICAL FIX: Check for existing object to prevent duplicates
        let existingIndex = unifiedObjects.firstIndex { unifiedObject in
            if case .shape(let existingShape) = unifiedObject.objectType {
                return existingShape.id == shape.id
            }
            return false
        }
        
        // If object already exists, remove it first to prevent duplicates
        if let existingIndex = existingIndex {
            unifiedObjects.remove(at: existingIndex)
        }
        
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
        // CRITICAL FIX: Check for existing object to prevent duplicates
        let existingIndex = unifiedObjects.firstIndex { unifiedObject in
            if case .shape(let existingShape) = unifiedObject.objectType {
                return existingShape.id == shape.id
            }
            return false
        }
        
        // If object already exists, remove it first to prevent duplicates
        if let existingIndex = existingIndex {
            unifiedObjects.remove(at: existingIndex)
        }
        
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
        // CRITICAL FIX: Check for existing object to prevent duplicates
        let existingIndex = unifiedObjects.firstIndex { unifiedObject in
            if case .shape(let existingShape) = unifiedObject.objectType {
                return existingShape.id == text.id && existingShape.isTextObject
            }
            return false
        }
        
        // If object already exists, remove it first to prevent duplicates
        if let existingIndex = existingIndex {
            unifiedObjects.remove(at: existingIndex)
        }
        
        // CRITICAL FIX: Also add to legacy textObjects array
        let existingTextIndex = textObjects.firstIndex { $0.id == text.id }
        if let existingTextIndex = existingTextIndex {
            textObjects.remove(at: existingTextIndex)
        }
        
        // Set the layer index on the text object
        var textWithLayer = text
        textWithLayer.layerIndex = layerIndex
        textObjects.append(textWithLayer)
        
        // Convert VectorText to VectorShape
        let textShape = VectorShape.from(textWithLayer)
        
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
                    
                    // CRITICAL FIX: Handle text objects differently - sync from textObjects array
                    if shape.isTextObject {
                        if let textObject = textObjects.first(where: { $0.id == shape.id }) {
                            // Convert updated VectorText to VectorShape and preserve orderID
                            let updatedShape = VectorShape.from(textObject)
                            unifiedObjects[unifiedIndex] = VectorObject(
                                shape: updatedShape, 
                                layerIndex: layerIndex, 
                                orderID: unifiedObjects[unifiedIndex].orderID
                            )
                            Log.info("🔄 SYNC: Updated text object '\(textObject.content.prefix(20))' with areaSize=\(textObject.areaSize?.debugDescription ?? "nil")", category: .general)
                        }
                    } else {
                        // Regular shapes - find updated shape data in layers
                        if layerIndex < layers.count,
                           let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
                            // Update with latest shape data while preserving orderID
                            unifiedObjects[unifiedIndex] = VectorObject(
                                shape: layers[layerIndex].shapes[shapeIndex], 
                                layerIndex: layerIndex, 
                                orderID: unifiedObjects[unifiedIndex].orderID
                            )
                        }
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
    
    // MARK: - UNIFIED TEXT COLOR HELPERS (MIGRATED FROM COLORSWATCHGRID)
    
    /// MIGRATED FROM ColorSwatchGrid - Update text fill color using unified system 
    /// NO MORE DUPLICATES - USE THIS ONE HELPER EVERYWHERE
    func updateTextFillColorInUnified(id: UUID, color: VectorColor) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                // Update typography fill color in the shape
                shape.typography?.fillColor = color
                shape.typography?.fillOpacity = defaultFillOpacity
                
                // Update unified objects
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // CRITICAL FIX: Only update the color properties in legacy array, preserve position
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].typography.fillColor = color
                    textObjects[legacyIndex].typography.fillOpacity = defaultFillOpacity
                }
            }
        }
    }
    
    /// MIGRATED FROM ColorPanel - Update text stroke color using unified system
    /// NO MORE DUPLICATES - USE THIS ONE HELPER EVERYWHERE  
    func updateTextStrokeColorInUnified(id: UUID, color: VectorColor) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                // Update typography stroke color in the shape
                shape.typography?.hasStroke = true
                shape.typography?.strokeColor = color
                
                // Update unified objects
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // CRITICAL FIX: Only update the color properties in legacy array, preserve position
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].typography.hasStroke = true
                    textObjects[legacyIndex].typography.strokeColor = color
                }
            }
        }
    }
    
    // MARK: - UNIFIED LOCK/UNLOCK HELPERS
    
    func lockTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isLocked = true
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].isLocked = true
                }
            }
        }
    }
    
    func unlockTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isLocked = false
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].isLocked = false
                }
            }
        }
    }
    
    // MARK: - UNIFIED VISIBILITY HELPERS
    
    func hideTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isVisible = false
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].isVisible = false
                }
            }
        }
    }
    
    func showTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isVisible = true
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].isVisible = true
                }
            }
        }
    }
    
    // MARK: - UNIFIED OPACITY AND STROKE HELPERS
    
    func updateTextFillOpacityInUnified(id: UUID, opacity: Double) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.typography?.fillOpacity = opacity
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].typography.fillOpacity = opacity
                }
            }
        }
    }
    
    func updateTextStrokeWidthInUnified(id: UUID, width: Double) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.typography?.strokeWidth = width
                shape.typography?.hasStroke = width > 0
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].typography.strokeWidth = width
                    textObjects[legacyIndex].typography.hasStroke = width > 0
                }
            }
        }
    }
    
    // MARK: - UNIFIED POSITION HELPERS
    
    func translateTextInUnified(id: UUID, delta: CGPoint) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                // Update position in transform
                shape.transform.tx += delta.x
                shape.transform.ty += delta.y
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].position.x += delta.x
                    textObjects[legacyIndex].position.y += delta.y
                }
            }
        }
    }
    
    func translateAllTextInUnified(delta: CGPoint) {
        // Get all text IDs first to avoid mutation during iteration
        let textIDs = textObjects.map { $0.id }
        
        // Use unified helper for each text
        for textID in textIDs {
            translateTextInUnified(id: textID, delta: delta)
        }
    }
    
    // MARK: - UNIFIED EDITING STATE HELPERS
    
    func setTextEditingInUnified(id: UUID, isEditing: Bool) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Note: isEditing is stored in textObjects only, not in unified shapes
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].isEditing = isEditing
            }
        }
    }
    
    func updateTextLayerInUnified(id: UUID, layerIndex: Int) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Recreate VectorObject with new layerIndex (layerIndex is let constant)
            let existingObject = unifiedObjects[objectIndex]
            if case .shape(let shape) = existingObject.objectType {
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex,
                    orderID: existingObject.orderID
                )
            }
            
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].layerIndex = layerIndex
            }
        }
    }
    
    // MARK: - UNIFIED CONTENT HELPERS
    
    func updateTextContentInUnified(id: UUID, content: String) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].content = content
                updateUnifiedObjectsOptimized()
            }
        }
    }
    
    func updateTextCursorPositionInUnified(id: UUID, cursorPosition: Int) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].cursorPosition = cursorPosition
            }
        }
    }
    
    func updateTextPositionInUnified(id: UUID, position: CGPoint) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].position = position
            }
        }
    }
    
    func updateTextBoundsInUnified(id: UUID, bounds: CGRect) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].bounds = bounds
            }
        }
    }
    
    func updateTextAreaSizeInUnified(id: UUID, areaSize: CGSize) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].areaSize = areaSize
            }
        }
    }
    
    // MARK: - UNIFIED SHAPE HELPERS
    
    func updateShapeFillColorInUnified(id: UUID, color: VectorColor) {
        // Check if shape exists in unified system  
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: color, opacity: defaultFillOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].fillStyle?.color = color
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokeColorInUnified(id: UUID, color: VectorColor) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeFillOpacityInUnified(id: UUID, opacity: Double) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: defaultFillColor, opacity: opacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].fillStyle?.opacity = opacity
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokeWidthInUnified(id: UUID, width: Double) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: width, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.width = width
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func lockShapeInUnified(id: UUID) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    layers[layerIndex].shapes[shapeIndex].isLocked = true
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func unlockShapeInUnified(id: UUID) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    layers[layerIndex].shapes[shapeIndex].isLocked = false
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func hideShapeInUnified(id: UUID) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    layers[layerIndex].shapes[shapeIndex].isVisible = false
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func showShapeInUnified(id: UUID) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    layers[layerIndex].shapes[shapeIndex].isVisible = true
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokeOpacityInUnified(id: UUID, opacity: Double) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: opacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.opacity = opacity
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeOpacityInUnified(id: UUID, opacity: Double) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    layers[layerIndex].shapes[shapeIndex].opacity = opacity
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokePlacementInUnified(id: UUID, placement: StrokePlacement) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: placement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.placement = placement
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokeLineJoinInUnified(id: UUID, lineJoin: CGLineJoin) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineJoin: lineJoin, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.lineJoin = lineJoin
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokeLineCapInUnified(id: UUID, lineCap: CGLineCap) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: lineCap, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.lineCap = lineCap
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokeMiterLimitInUnified(id: UUID, miterLimit: CGFloat) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, miterLimit: miterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.miterLimit = miterLimit
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func createFillStyleInUnified(id: UUID, color: VectorColor, opacity: Double) {
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                        color: color,
                        opacity: opacity
                    )
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func createStrokeStyleInUnified(id: UUID, color: VectorColor, width: Double, placement: StrokePlacement, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: Double, opacity: Double) {
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(
                        color: color,
                        width: width,
                        placement: placement,
                        lineCap: lineCap,
                        lineJoin: lineJoin,
                        miterLimit: miterLimit,
                        opacity: opacity
                    )
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapePathUnified(id: UUID, path: VectorPath) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    layers[layerIndex].shapes[shapeIndex].path = path
                    layers[layerIndex].shapes[shapeIndex].updateBounds()
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeCornerRadiiInUnified(id: UUID, cornerRadii: [Double], path: VectorPath) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    layers[layerIndex].shapes[shapeIndex].cornerRadii = cornerRadii
                    layers[layerIndex].shapes[shapeIndex].path = path
                    layers[layerIndex].shapes[shapeIndex].updateBounds()
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeGradientInUnified(id: UUID, gradient: VectorGradient, target: ColorTarget) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    switch target {
                    case .fill:
                        layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(gradient: gradient, opacity: 1.0)
                    case .stroke:
                        let currentStroke = layers[layerIndex].shapes[shapeIndex].strokeStyle
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(
                            gradient: gradient, 
                            width: currentStroke?.width ?? defaultStrokeWidth,
                            placement: currentStroke?.placement ?? defaultStrokePlacement,
                            lineCap: currentStroke?.lineCap ?? defaultStrokeLineCap,
                            lineJoin: currentStroke?.lineJoin ?? defaultStrokeLineJoin,
                            miterLimit: currentStroke?.miterLimit ?? defaultStrokeMiterLimit,
                            opacity: currentStroke?.opacity ?? 1.0
                        )
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    /// Generic shape update helper for complex transformations
    func updateShapeTransformAndPathInUnified(id: UUID, path: VectorPath? = nil, transform: CGAffineTransform? = nil) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if let path = path {
                        layers[layerIndex].shapes[shapeIndex].path = path
                    }
                    if let transform = transform {
                        layers[layerIndex].shapes[shapeIndex].transform = transform
                    }
                    layers[layerIndex].shapes[shapeIndex].updateBounds()
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    /// Update entire shape object in unified system (use sparingly)
    func updateEntireShapeInUnified(id: UUID, updater: (inout VectorShape) -> Void) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    updater(&layers[layerIndex].shapes[shapeIndex])
                    layers[layerIndex].shapes[shapeIndex].updateBounds()
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
}