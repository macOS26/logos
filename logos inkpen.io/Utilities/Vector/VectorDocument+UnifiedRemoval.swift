//
//  VectorDocument+UnifiedRemoval.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import SwiftUI

// MARK: - UNIFIED REMOVAL AND TEXT OPERATIONS
extension VectorDocument {
    
    /// Remove shape from both layers array and unified system
    func removeShapeFromUnifiedSystem(id: UUID) {
        // Remove from unified objects
        unifiedObjects.removeAll { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id && !shape.isTextObject
            }
            return false
        }
        
        // Remove from selection if selected
        selectedShapeIDs.remove(id)
        // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
        if let unifiedObj = findObject(by: id) {
            selectedObjectIDs.remove(unifiedObj.id)
        }
    }
    
    /// Remove text from unified system
    func removeTextFromUnifiedSystem(id: UUID) {
        // Text is now only in unified objects
        
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
        // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
        if let unifiedObj = findObject(by: id) {
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
                
                // Shape is now only in unified objects
                
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
        // Text objects are now only in unified system
    }
}
