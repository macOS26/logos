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
    /// Gets shapes for a specific layer from the unified objects system
    func getShapesForLayer(_ layerIndex: Int) -> [VectorShape] {
        return unifiedObjects
            .filter { $0.layerIndex == layerIndex }
            .sorted { $0.orderID < $1.orderID }
            .compactMap { object -> VectorShape? in
                if case .shape(let shape) = object.objectType {
                    return shape
                }
                return nil
            }
    }
    
    /// Syncs the legacy layer.shapes array with unified objects (temporary during migration)
    func syncLayerShapesFromUnified() {
        for (index, _) in layers.enumerated() {
            layers[index].shapes = getShapesForLayer(index)
        }
    }
    
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
        // MIGRATION: Text is now stored as VectorShape in unified system
        
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
        
        // Convert VectorText to VectorShape
        var textWithLayer = text
        textWithLayer.layerIndex = layerIndex
        let textShape = VectorShape.from(textWithLayer)
        
        // DEBUG: Log the editing state
        Log.fileOperation("🔍 addTextToUnifiedSystem: text.isEditing=\(text.isEditing), textShape.isEditing=\(textShape.isEditing ?? false)", level: .info)
        
        // CRITICAL: Add the text shape to the layer's shapes array
        if layerIndex < layers.count {
            // Remove any existing shape with same ID to prevent duplicates
            layers[layerIndex].shapes.removeAll { $0.id == text.id }
            // Add the text as a shape (make sure editing state is preserved)
            var shapeToAdd = textShape
            shapeToAdd.isEditing = text.isEditing  // Ensure editing state is preserved
            layers[layerIndex].shapes.append(shapeToAdd)
        }
        
        // MIGRATION: textObjects is now rebuilt from unified, no direct modification needed
        
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
        
        // Text is now fully managed in unified system
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
        
        // After populating, sync back to layers
        defer { syncLayerShapesFromUnified() }
        
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
    
    // MARK: - UNIFIED TEXT COLOR HELPERS (MIGRATED FROM COLORSWATCHGRID)
    
    /// MIGRATED FROM ColorSwatchGrid - Update text fill color using unified system 
    /// NO MORE DUPLICATES - USE THIS ONE HELPER EVERYWHERE
    func updateTextFillColorInUnified(id: UUID, color: VectorColor) {
        Log.fileOperation("🔍 updateTextFillColorInUnified START - id: \(id), color: \(color)", level: .info)
        
        // LOG INITIAL STATE
        if let textObject = findText(by: id) {
            Log.fileOperation("📝 BEFORE COLOR CHANGE - Text Typography:", level: .info)
            Log.fileOperation("  - Font: \(textObject.typography.fontFamily)", level: .info)
            Log.fileOperation("  - Size: \(textObject.typography.fontSize)", level: .info)
            Log.fileOperation("  - Weight: \(String(describing: textObject.typography.fontWeight))", level: .info)
            Log.fileOperation("  - Style: \(String(describing: textObject.typography.fontStyle))", level: .info)
            Log.fileOperation("  - Alignment: \(textObject.typography.alignment)", level: .info)
            Log.fileOperation("  - Current Fill Color: \(textObject.typography.fillColor)", level: .info)
        } else {
            Log.fileOperation("⚠️ NO TEXT FOUND WITH ID: \(id)", level: .warning)
        }
        
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            Log.fileOperation("✅ Found object at unified index: \(objectIndex)", level: .info)
            
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                Log.fileOperation("📊 BEFORE - Unified Shape Typography:", level: .info)
                if let typo = shape.typography {
                    Log.fileOperation("  - Font: \(typo.fontFamily)", level: .info)
                    Log.fileOperation("  - Size: \(typo.fontSize)", level: .info)
                    Log.fileOperation("  - Weight: \(String(describing: typo.fontWeight))", level: .info)
                    Log.fileOperation("  - Style: \(String(describing: typo.fontStyle))", level: .info)
                    Log.fileOperation("  - Alignment: \(typo.alignment)", level: .info)
                } else {
                    Log.fileOperation("  ⚠️ Typography is NIL in unified shape!", level: .warning)
                }
                
                // CRITICAL: Only update color, preserve ALL other typography properties
                if shape.typography != nil {
                    Log.fileOperation("📝 Updating existing typography - ONLY changing fillColor", level: .info)
                    shape.typography?.fillColor = color
                    shape.typography?.fillOpacity = defaultFillOpacity
                } else {
                    // If typography is nil, we need to get it from the text object
                    Log.fileOperation("⚠️ Typography was NIL - restoring from text object", level: .warning)
                    if let textObject = findText(by: id) {
                        shape.typography = textObject.typography
                        shape.typography?.fillColor = color
                        shape.typography?.fillOpacity = defaultFillOpacity
                        Log.fileOperation("✅ Restored typography with font: \(textObject.typography.fontFamily)", level: .info)
                    } else {
                        Log.fileOperation("❌ COULD NOT RESTORE TYPOGRAPHY - NO TEXT OBJECT!", level: .error)
                    }
                }
                
                Log.fileOperation("📊 AFTER COLOR UPDATE - Shape Typography:", level: .info)
                if let typo = shape.typography {
                    Log.fileOperation("  - Font: \(typo.fontFamily)", level: .info)
                    Log.fileOperation("  - Size: \(typo.fontSize)", level: .info)
                    Log.fileOperation("  - Weight: \(String(describing: typo.fontWeight))", level: .info)
                    Log.fileOperation("  - Style: \(String(describing: typo.fontStyle))", level: .info)
                    Log.fileOperation("  - Alignment: \(typo.alignment)", level: .info)
                    Log.fileOperation("  - New Fill Color: \(typo.fillColor)", level: .info)
                }
                
                // Update unified objects
                Log.fileOperation("🔄 Creating new VectorObject to update unified array", level: .info)
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // CRITICAL: Update the shape in the layers array - ONLY COLOR
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                Log.fileOperation("📋 Updating layer \(layerIndex) shapes array", level: .info)
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    Log.fileOperation("  - Found shape at index \(shapeIndex)", level: .info)
                    Log.fileOperation("  - BEFORE layer shape font: \(layers[layerIndex].shapes[shapeIndex].typography?.fontFamily ?? "nil")", level: .info)
                    
                    // Preserve existing typography, only update color
                    layers[layerIndex].shapes[shapeIndex].typography?.fillColor = color
                    layers[layerIndex].shapes[shapeIndex].typography?.fillOpacity = defaultFillOpacity
                    
                    Log.fileOperation("  - AFTER layer shape font: \(layers[layerIndex].shapes[shapeIndex].typography?.fontFamily ?? "nil")", level: .info)
                } else {
                    Log.fileOperation("⚠️ Could not find shape in layers array!", level: .warning)
                }
                
                // Text is now fully managed in unified system
            } else {
                Log.fileOperation("❌ Failed to cast unified object to shape!", level: .error)
            }
        } else {
            Log.fileOperation("❌ Could not find object in unified array with id: \(id)", level: .error)
        }
        
        // No need for explicit objectWillChange.send() - @Published properties handle this
        
        Log.fileOperation("🔍 updateTextFillColorInUnified END", level: .info)
    }
    
    /// MIGRATED FROM ColorPanel - Update text stroke color using unified system
    /// NO MORE DUPLICATES - USE THIS ONE HELPER EVERYWHERE  
    /// CRITICAL FIX: Update text typography in unified objects and layers to keep them in sync
    /// This prevents typography from being reset when color changes
    func updateTextTypographyInUnified(id: UUID, typography: TypographyProperties) {
        Log.fileOperation("🔍 updateTextTypographyInUnified START - id: \(id)", level: .info)
        Log.fileOperation("  - New Font: \(typography.fontFamily) \(typography.fontSize)pt", level: .info)
        
        // Update in unified objects array
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                Log.fileOperation("📊 BEFORE - Unified Shape Typography:", level: .info)
                Log.fileOperation("  - Old Font: \(shape.typography?.fontFamily ?? "nil") \(shape.typography?.fontSize ?? 0)pt", level: .info)
                
                // Update the typography
                shape.typography = typography
                
                Log.fileOperation("📊 AFTER - Unified Shape Typography:", level: .info)
                Log.fileOperation("  - New Font: \(shape.typography?.fontFamily ?? "nil") \(shape.typography?.fontSize ?? 0)pt", level: .info)
                
                // Update unified objects
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    Log.fileOperation("📋 Updating layer \(layerIndex) shape typography", level: .info)
                    Log.fileOperation("  - BEFORE layer font: \(layers[layerIndex].shapes[shapeIndex].typography?.fontFamily ?? "nil")", level: .info)
                    
                    layers[layerIndex].shapes[shapeIndex].typography = typography
                    
                    Log.fileOperation("  - AFTER layer font: \(layers[layerIndex].shapes[shapeIndex].typography?.fontFamily ?? "nil")", level: .info)
                }
                
                // Text is now fully managed in unified system
            }
        } else {
            Log.fileOperation("⚠️ Could not find text in unified objects with id: \(id)", level: .warning)
        }
        
        // No need for explicit objectWillChange.send() - @Published properties handle this
        
        Log.fileOperation("🔍 updateTextTypographyInUnified END", level: .info)
    }
    
    func updateTextStrokeColorInUnified(id: UUID, color: VectorColor) {
        Log.fileOperation("🔍 updateTextStrokeColorInUnified START - id: \(id), color: \(color)", level: .info)
        
        // LOG INITIAL STATE
        if let textObject = findText(by: id) {
            Log.fileOperation("📝 BEFORE STROKE COLOR CHANGE - Text Typography:", level: .info)
            Log.fileOperation("  - Font: \(textObject.typography.fontFamily)", level: .info)
            Log.fileOperation("  - Size: \(textObject.typography.fontSize)", level: .info)
            Log.fileOperation("  - Weight: \(String(describing: textObject.typography.fontWeight))", level: .info)
            Log.fileOperation("  - Style: \(String(describing: textObject.typography.fontStyle))", level: .info)
            Log.fileOperation("  - Alignment: \(textObject.typography.alignment)", level: .info)
            Log.fileOperation("  - Current Stroke Color: \(textObject.typography.strokeColor)", level: .info)
            Log.fileOperation("  - Has Stroke: \(textObject.typography.hasStroke)", level: .info)
        } else {
            Log.fileOperation("⚠️ NO TEXT FOUND WITH ID: \(id)", level: .warning)
        }
        
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            Log.fileOperation("✅ Found object at unified index: \(objectIndex)", level: .info)
            
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                Log.fileOperation("📊 BEFORE - Unified Shape Typography:", level: .info)
                if let typo = shape.typography {
                    Log.fileOperation("  - Font: \(typo.fontFamily)", level: .info)
                    Log.fileOperation("  - Size: \(typo.fontSize)", level: .info)
                    Log.fileOperation("  - Weight: \(String(describing: typo.fontWeight))", level: .info)
                    Log.fileOperation("  - Style: \(String(describing: typo.fontStyle))", level: .info)
                    Log.fileOperation("  - Alignment: \(typo.alignment)", level: .info)
                    Log.fileOperation("  - Has Stroke: \(typo.hasStroke)", level: .info)
                } else {
                    Log.fileOperation("  ⚠️ Typography is NIL in unified shape!", level: .warning)
                }
                
                // CRITICAL: Only update stroke color, preserve ALL other typography properties
                if shape.typography != nil {
                    Log.fileOperation("📝 Updating existing typography - ONLY changing strokeColor", level: .info)
                    shape.typography?.hasStroke = true
                    shape.typography?.strokeColor = color
                } else {
                    // If typography is nil, we need to get it from the text object
                    Log.fileOperation("⚠️ Typography was NIL - restoring from text object", level: .warning)
                    if let textObject = findText(by: id) {
                        shape.typography = textObject.typography
                        shape.typography?.hasStroke = true
                        shape.typography?.strokeColor = color
                        Log.fileOperation("✅ Restored typography with font: \(textObject.typography.fontFamily)", level: .info)
                    } else {
                        Log.fileOperation("❌ COULD NOT RESTORE TYPOGRAPHY - NO TEXT OBJECT!", level: .error)
                    }
                }
                
                Log.fileOperation("📊 AFTER STROKE COLOR UPDATE - Shape Typography:", level: .info)
                if let typo = shape.typography {
                    Log.fileOperation("  - Font: \(typo.fontFamily)", level: .info)
                    Log.fileOperation("  - Size: \(typo.fontSize)", level: .info)
                    Log.fileOperation("  - Weight: \(String(describing: typo.fontWeight))", level: .info)
                    Log.fileOperation("  - Style: \(String(describing: typo.fontStyle))", level: .info)
                    Log.fileOperation("  - Alignment: \(typo.alignment)", level: .info)
                    Log.fileOperation("  - New Stroke Color: \(typo.strokeColor)", level: .info)
                    Log.fileOperation("  - Has Stroke: \(typo.hasStroke)", level: .info)
                }
                
                // Update unified objects
                Log.fileOperation("🔄 Creating new VectorObject to update unified array", level: .info)
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // CRITICAL: Update the shape in the layers array - ONLY STROKE COLOR
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                Log.fileOperation("📋 Updating layer \(layerIndex) shapes array", level: .info)
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    Log.fileOperation("  - Found shape at index \(shapeIndex)", level: .info)
                    Log.fileOperation("  - BEFORE layer shape font: \(layers[layerIndex].shapes[shapeIndex].typography?.fontFamily ?? "nil")", level: .info)
                    
                    // Preserve existing typography, only update stroke color
                    layers[layerIndex].shapes[shapeIndex].typography?.hasStroke = true
                    layers[layerIndex].shapes[shapeIndex].typography?.strokeColor = color
                    
                    Log.fileOperation("  - AFTER layer shape font: \(layers[layerIndex].shapes[shapeIndex].typography?.fontFamily ?? "nil")", level: .info)
                } else {
                    Log.fileOperation("⚠️ Could not find shape in layers array!", level: .warning)
                }
                
                // Text is now fully managed in unified system
            } else {
                Log.fileOperation("❌ Failed to cast unified object to shape!", level: .error)
            }
        } else {
            Log.fileOperation("❌ Could not find object in unified array with id: \(id)", level: .error)
        }
        
        // No need for explicit objectWillChange.send() - @Published properties handle this
        
        Log.fileOperation("🔍 updateTextStrokeColorInUnified END", level: .info)
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
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].isLocked = true
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
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].isLocked = false
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
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].isVisible = false
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
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].isVisible = true
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
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].typography?.fillOpacity = opacity
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
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].typography?.strokeWidth = width
                    layers[layerIndex].shapes[shapeIndex].typography?.hasStroke = width > 0
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
                
                // Also update textPosition if it exists
                if let textPos = shape.textPosition {
                    shape.textPosition = CGPoint(x: textPos.x + delta.x, y: textPos.y + delta.y)
                }
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].transform.tx += delta.x
                        layers[layerIdx].shapes[shapeIdx].transform.ty += delta.y
                        if let textPos = layers[layerIdx].shapes[shapeIdx].textPosition {
                            layers[layerIdx].shapes[shapeIdx].textPosition = CGPoint(x: textPos.x + delta.x, y: textPos.y + delta.y)
                        }
                        break
                    }
                }
            }
        }
    }
    
    func translateAllTextInUnified(delta: CGPoint) {
        // Get all text IDs from unified system
        let textIDs = unifiedObjects.compactMap { obj -> UUID? in
            if case .shape(let shape) = obj.objectType, shape.isTextObject {
                return shape.id
            }
            return nil
        }
        
        // Use unified helper for each text
        for textID in textIDs {
            translateTextInUnified(id: textID, delta: delta)
        }
    }
    
    // MARK: - UNIFIED EDITING STATE HELPERS
    
    func setTextEditingInUnified(id: UUID, isEditing: Bool) {
        // Update in unified objects
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                // Update the isEditing state in the shape
                shape.isEditing = isEditing
                
                // Update unified objects
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].isEditing = isEditing
                }
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
            // Get the existing object and shape
            let existingObject = unifiedObjects[objectIndex]
            if case .shape(let shape) = existingObject.objectType {
                // Find and remove the shape from its current layer
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes.remove(at: shapeIdx)
                        break
                    }
                }
                
                // Add the shape to the new layer
                if layerIndex < layers.count {
                    layers[layerIndex].shapes.append(shape)
                }
                
                // Update the unified object with new layerIndex
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex,
                    orderID: existingObject.orderID
                )
            }
        }
    }
    
    // MARK: - UNIFIED CONTENT HELPERS
    
    func updateTextContentInUnified(id: UUID, content: String) {
        // MIGRATION: Update text directly in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Update in unified objects
            if case .shape(var shape) = unifiedObjects[unifiedIndex].objectType {
                shape.textContent = content
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                    orderID: unifiedObjects[unifiedIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].textContent = content
                        break
                    }
                }
            }
        }
    }
    
    func updateTextCursorPositionInUnified(id: UUID, cursorPosition: Int) {
        // Update cursor position in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Update in unified objects
            if case .shape(var shape) = unifiedObjects[unifiedIndex].objectType {
                shape.cursorPosition = cursorPosition
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                    orderID: unifiedObjects[unifiedIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].cursorPosition = cursorPosition
                        break
                    }
                }
            }
        }
    }
    
    func updateTextPositionInUnified(id: UUID, position: CGPoint) {
        // MIGRATION: Update position directly in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Update in unified objects
            if case .shape(var shape) = unifiedObjects[unifiedIndex].objectType {
                shape.transform = CGAffineTransform(translationX: position.x, y: position.y)
                shape.textPosition = position  // Update textPosition for proper reconstruction
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                    orderID: unifiedObjects[unifiedIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].transform = CGAffineTransform(translationX: position.x, y: position.y)
                        layers[layerIdx].shapes[shapeIdx].textPosition = position
                        break
                    }
                }
            }
        }
    }
    
    func updateTextBoundsInUnified(id: UUID, bounds: CGRect) {
        // Update bounds in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[unifiedIndex].objectType {
                shape.bounds = bounds
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                    orderID: unifiedObjects[unifiedIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].bounds = bounds
                        break
                    }
                }
            }
        }
    }
    
    func updateTextAreaSizeInUnified(id: UUID, areaSize: CGSize) {
        // Update area size in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[unifiedIndex].objectType {
                shape.areaSize = areaSize
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                    orderID: unifiedObjects[unifiedIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].areaSize = areaSize
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - LAYER SHAPE ACCESS HELPERS (MIGRATION)
    
    /// Safe getter for shape at index in layer - returns from unified system
    func getShapeAtIndex(layerIndex: Int, shapeIndex: Int) -> VectorShape? {
        guard layerIndex >= 0 && layerIndex < layers.count else { return nil }
        let shapes = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapes.count else { return nil }
        return shapes[shapeIndex]
    }
    
    /// Safe setter for shape at index in layer - updates both legacy and unified
    func setShapeAtIndex(layerIndex: Int, shapeIndex: Int, shape: VectorShape) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        guard shapeIndex >= 0 && shapeIndex < layers[layerIndex].shapes.count else { return }
        
        // Update in layers array
        layers[layerIndex].shapes[shapeIndex] = shape
        
        // Update in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let s) = obj.objectType {
                return s.id == layers[layerIndex].shapes[shapeIndex].id
            }
            return false
        }) {
            unifiedObjects[unifiedIndex] = VectorObject(
                shape: shape,
                layerIndex: layerIndex,
                orderID: unifiedObjects[unifiedIndex].orderID
            )
        }
    }
    
    /// Append shape to layer - adds to both legacy and unified
    func appendShapeToLayer(layerIndex: Int, shape: VectorShape) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
    }
    
    /// Remove shape at index from layer - removes from both legacy and unified
    func removeShapeAtIndex(layerIndex: Int, shapeIndex: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        guard shapeIndex >= 0 && shapeIndex < layers[layerIndex].shapes.count else { return }
        
        let shapeId = layers[layerIndex].shapes[shapeIndex].id
        layers[layerIndex].shapes.remove(at: shapeIndex)
        
        // Remove from unified
        unifiedObjects.removeAll { obj in
            if case .shape(let s) = obj.objectType {
                return s.id == shapeId
            }
            return false
        }
    }
    
    /// Get shape count for layer from unified system
    func getShapeCount(layerIndex: Int) -> Int {
        guard layerIndex >= 0 && layerIndex < layers.count else { return 0 }
        return getShapesForLayer(layerIndex).count
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
        // Find in legacy layer arrays and update
        for layerIndex in 0..<layers.count {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                layers[layerIndex].shapes[shapeIndex].path = path
                layers[layerIndex].shapes[shapeIndex].updateBounds()
                
                // Update the specific unified object
                if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
                    if case .shape(let shape) = obj.objectType {
                        return shape.id == id && !shape.isTextObject
                    }
                    return false
                }) {
                    let updatedShape = layers[layerIndex].shapes[shapeIndex]
                    unifiedObjects[unifiedIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: layerIndex,
                        orderID: unifiedObjects[unifiedIndex].orderID
                    )
                }
                break
            }
        }
    }
    
    func updateShapeCornerRadiiInUnified(id: UUID, cornerRadii: [Double], path: VectorPath) {
        // Find in legacy layer arrays and update
        for layerIndex in 0..<layers.count {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                layers[layerIndex].shapes[shapeIndex].cornerRadii = cornerRadii
                layers[layerIndex].shapes[shapeIndex].path = path
                layers[layerIndex].shapes[shapeIndex].updateBounds()
                
                // Update the specific unified object
                if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
                    if case .shape(let shape) = obj.objectType {
                        return shape.id == id && !shape.isTextObject
                    }
                    return false
                }) {
                    let updatedShape = layers[layerIndex].shapes[shapeIndex]
                    unifiedObjects[unifiedIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: layerIndex,
                        orderID: unifiedObjects[unifiedIndex].orderID
                    )
                }
                break
            }
        }
    }
    
    func updateShapeGradientInUnified(id: UUID, gradient: VectorGradient, target: ColorTarget) {
        // Find in legacy layer arrays and update
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
                
                // Update the specific unified object
                if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
                    if case .shape(let shape) = obj.objectType {
                        return shape.id == id && !shape.isTextObject
                    }
                    return false
                }) {
                    let updatedShape = layers[layerIndex].shapes[shapeIndex]
                    unifiedObjects[unifiedIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: layerIndex,
                        orderID: unifiedObjects[unifiedIndex].orderID
                    )
                }
                break
            }
        }
    }
    
    /// Generic shape update helper for complex transformations
    func updateShapeTransformAndPathInUnified(id: UUID, path: VectorPath? = nil, transform: CGAffineTransform? = nil) {
        // Find in legacy layer arrays and update
        for layerIndex in 0..<layers.count {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                if let path = path {
                    layers[layerIndex].shapes[shapeIndex].path = path
                }
                if let transform = transform {
                    layers[layerIndex].shapes[shapeIndex].transform = transform
                }
                layers[layerIndex].shapes[shapeIndex].updateBounds()
                
                // Update the specific unified object
                if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
                    if case .shape(let shape) = obj.objectType {
                        return shape.id == id && !shape.isTextObject
                    }
                    return false
                }) {
                    let updatedShape = layers[layerIndex].shapes[shapeIndex]
                    unifiedObjects[unifiedIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: layerIndex,
                        orderID: unifiedObjects[unifiedIndex].orderID
                    )
                }
                break
            }
        }
    }
    
    /// Update entire shape object in unified system (use sparingly)
    func updateEntireShapeInUnified(id: UUID, updater: (inout VectorShape) -> Void) {
        // Find in legacy layer arrays and update
        for layerIndex in 0..<layers.count {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                updater(&layers[layerIndex].shapes[shapeIndex])
                layers[layerIndex].shapes[shapeIndex].updateBounds()
                
                // Update the specific unified object
                if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
                    if case .shape(let shape) = obj.objectType {
                        return shape.id == id && !shape.isTextObject
                    }
                    return false
                }) {
                    let updatedShape = layers[layerIndex].shapes[shapeIndex]
                    unifiedObjects[unifiedIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: layerIndex,
                        orderID: unifiedObjects[unifiedIndex].orderID
                    )
                }
                break
            }
        }
    }
    
    /// Remove shape from both layers array and unified system
    func removeShapeFromUnifiedSystem(id: UUID) {
        // Remove from layers array
        for layerIndex in 0..<layers.count {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                layers[layerIndex].shapes.remove(at: shapeIndex)
                break
            }
        }
        
        // Remove from unified objects
        unifiedObjects.removeAll { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id && !shape.isTextObject
            }
            return false
        }
        
        // Remove from selection if selected
        selectedShapeIDs.remove(id)
        if let unifiedObj = unifiedObjects.first(where: { obj in
            if case .shape(let s) = obj.objectType { return s.id == id }
            return false
        }) {
            selectedObjectIDs.remove(unifiedObj.id)
        }
    }
    
    /// Remove text from unified system
    func removeTextFromUnifiedSystem(id: UUID) {
        // MIGRATION: Remove text shape from layers (text is now stored as shapes)
        for layerIndex in layers.indices {
            layers[layerIndex].shapes.removeAll { $0.id == id && $0.isTextObject }
        }
        
        // MIGRATION: textObjects is rebuilt from unified, no direct removal needed
        
        // Remove from unified objects (text is stored as shape with isTextObject = true)
        unifiedObjects.removeAll { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id && shape.isTextObject
            }
            return false
        }
        
        // Remove from selection if selected
        selectedTextIDs.remove(id)
        if let unifiedObj = unifiedObjects.first(where: { obj in
            if case .shape(let s) = obj.objectType { return s.id == id && s.isTextObject }
            return false
        }) {
            selectedObjectIDs.remove(unifiedObj.id)
        }
        
        // Text is now fully managed in unified system
    }
    
    /// Update entire text object in unified system
    func updateEntireTextInUnified(id: UUID, updater: (inout VectorText) -> Void) {
        // MIGRATION: Find and update text directly in unified objects
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id && shape.isTextObject
            }
            return false
        }) {
            // Extract text from shape
            if case .shape(let shape) = unifiedObjects[unifiedIndex].objectType,
               var vectorText = VectorText.from(shape) {
                
                // Apply the update
                updater(&vectorText)
                
                // Convert back to shape and update unified object
                let updatedShape = VectorShape.from(vectorText)
                let layerIndex = unifiedObjects[unifiedIndex].layerIndex
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: updatedShape,
                    layerIndex: layerIndex,
                    orderID: unifiedObjects[unifiedIndex].orderID
                )
                
                // MIGRATION: Also update in layers array
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx] = updatedShape
                        break
                    }
                }
                
                // Text is now fully managed in unified system
            }
        }
    }
    
    // MARK: - Unified Read-Only Helpers
    
    /// Gets the count of text objects in the unified system
    func getTextCount() -> Int {
        return unifiedObjects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject
            }
            return false
        }.count
    }
    
    /// Checks if there are any text objects in the unified system
    func hasTextObjects() -> Bool {
        return unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject
            }
            return false
        }
    }
    
    /// Gets all text objects from the unified system as VectorText objects
    func getAllTextObjects() -> [VectorText] {
        // MIGRATION: Extract text objects from unified system instead of legacy array
        return unifiedObjects.compactMap { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType, 
               shape.isTextObject,
               var vectorText = VectorText.from(shape) {
                // Set the layerIndex from the unified object wrapper
                vectorText.layerIndex = unifiedObject.layerIndex
                return vectorText
            }
            return nil
        }
    }
    
    /// Gets a text object by ID from the unified system
    func getTextByID(_ id: UUID) -> VectorText? {
        // MIGRATION: Extract from unified system instead of legacy array
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType, 
               shape.isTextObject,
               shape.id == id,
               var vectorText = VectorText.from(shape) {
                // Set the layerIndex from the unified object wrapper
                vectorText.layerIndex = unifiedObject.layerIndex
                return vectorText
            }
        }
        return nil
    }
    
    /// Gets the first text object matching a condition from the unified system
    func getFirstText(where predicate: (VectorText) -> Bool) -> VectorText? {
        // MIGRATION: Extract from unified system instead of legacy array
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType, 
               shape.isTextObject,
               var vectorText = VectorText.from(shape) {
                // Set the layerIndex from the unified object wrapper
                vectorText.layerIndex = unifiedObject.layerIndex
                if predicate(vectorText) {
                    return vectorText
                }
            }
        }
        return nil
    }
    
    /// Gets the index of the first text object matching a condition
    func getTextIndex(where predicate: (VectorText) -> Bool) -> Int? {
        // MIGRATION: Extract from unified system instead of legacy array
        let allTextObjects = getAllTextObjects()
        return allTextObjects.firstIndex(where: predicate)
    }
    
    /// Checks if any text object matches a condition
    func containsText(where predicate: (VectorText) -> Bool) -> Bool {
        // MIGRATION: Extract from unified system instead of legacy array
        let allTextObjects = getAllTextObjects()
        return allTextObjects.contains(where: predicate)
    }
    
    /// Gets text object at a specific index
    func getTextAt(index: Int) -> VectorText? {
        // MIGRATION: Extract from unified system instead of legacy array
        let allTextObjects = getAllTextObjects()
        guard index >= 0 && index < allTextObjects.count else { return nil }
        return allTextObjects[index]
    }
    
    /// Removes all text objects from the unified system
    func removeAllText() {
        // Remove from unified objects
        unifiedObjects.removeAll { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject
            }
            return false
        }
        
        // Remove text shapes from layers
        for layerIndex in layers.indices {
            layers[layerIndex].shapes.removeAll { $0.isTextObject }
        }
    }
    
    /// Removes text objects matching a condition
    func removeText(where predicate: (VectorText) -> Bool) {
        let allTextObjects = getAllTextObjects()
        let idsToRemove = allTextObjects.filter(predicate).map { $0.id }
        for id in idsToRemove {
            removeTextFromUnifiedSystem(id: id)
        }
    }
    
    /// Updates a text object at a specific index
    func updateTextAt(index: Int, update: (inout VectorText) -> Void) {
        let allTextObjects = getAllTextObjects()
        guard index >= 0 && index < allTextObjects.count else { return }
        
        var text = allTextObjects[index]
        update(&text)
        
        // Update in unified system
        updateEntireTextInUnified(id: text.id) { updatedText in
            updatedText = text
        }
    }
    
    // MARK: - COMPREHENSIVE UNIFIED WRITE OPERATIONS
    // These methods ensure ALL operations go through unified system - NO direct layer access
    
    /// Append a shape to a layer through unified system
    func appendShapeToLayerUnified(layerIndex: Int, shape: VectorShape) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Add to legacy layer (temporary until full migration)
        layers[layerIndex].shapes.append(shape)
        
        // Update unified system immediately
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Remove a shape by ID through unified system
    func removeShapeByIdUnified(shapeID: UUID) {
        // Find and remove from legacy layers
        for layerIndex in layers.indices {
            if let index = layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                layers[layerIndex].shapes.remove(at: index)
                break
            }
        }
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Remove all shapes matching a condition through unified system
    func removeShapesUnified(layerIndex: Int, where condition: (VectorShape) -> Bool) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Remove from legacy layer
        layers[layerIndex].shapes.removeAll(where: condition)
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Insert a shape at specific index through unified system
    func insertShapeUnified(layerIndex: Int, shape: VectorShape, at index: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Insert into legacy layer
        let safeIndex = min(index, layers[layerIndex].shapes.count)
        layers[layerIndex].shapes.insert(shape, at: safeIndex)
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Append multiple shapes through unified system
    func appendShapesUnified(layerIndex: Int, shapes: [VectorShape]) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Append to legacy layer
        layers[layerIndex].shapes.append(contentsOf: shapes)
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Remove shape at specific index through unified system
    func removeShapeAtIndexUnified(layerIndex: Int, shapeIndex: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count,
              shapeIndex >= 0 && shapeIndex < layers[layerIndex].shapes.count else { return }
        
        // Remove from legacy layer
        layers[layerIndex].shapes.remove(at: shapeIndex)
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Replace all shapes in a layer through unified system
    func setShapesForLayerUnified(layerIndex: Int, shapes: [VectorShape]) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Replace in legacy layer
        layers[layerIndex].shapes = shapes
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
}