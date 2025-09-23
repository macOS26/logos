//
//  VectorDocument+UnifiedCore.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import SwiftUI

// MARK: - Core Unified Object Management
extension VectorDocument {
    
    /// NO LONGER NEEDED - unified objects is the single source of truth
    /// This method is now a no-op for compatibility
    func syncShapeToLayer(_ shape: VectorShape, at layerIndex: Int) {
        // NO-OP: Everything is managed through unified objects
        // No sync needed since there's only one source of truth
        Log.fileOperation("✅ Shape \(shape.id) managed through unified objects", level: .debug)
    }
    
    /// Get shape at specific index (compatibility wrapper)
    func getShapeAtIndex(layerIndex: Int, shapeIndex: Int) -> VectorShape? {
        let shapes = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapes.count else { return nil }
        return shapes[shapeIndex]
    }
    
    /// Get shape count for a layer
    func getShapeCount(layerIndex: Int) -> Int {
        return getShapesForLayer(layerIndex).count
    }
    
    /// Set shape at specific index (compatibility wrapper)
    func setShapeAtIndex(layerIndex: Int, shapeIndex: Int, shape: VectorShape) {
        let shapes = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapes.count else { return }
        let oldShape = shapes[shapeIndex]
        
        // Find and update in unified objects
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let s) = obj.objectType {
                return s.id == oldShape.id
            }
            return false
        }) {
            let orderID = unifiedObjects[index].orderID
            unifiedObjects[index] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
            // REMOVED: objectWillChange.send() - unifiedObjects is @Published
        }
    }
    
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
        
        // Shape is now only in unified objects
        
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
        
        // Text shape is now only in unified objects
        
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
}
