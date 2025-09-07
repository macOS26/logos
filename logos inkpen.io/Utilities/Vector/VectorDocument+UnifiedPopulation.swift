//
//  VectorDocument+UnifiedPopulation.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics
import SwiftUI

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
    /// Now that unified objects is the primary storage, this is mostly a no-op
    internal func populateUnifiedObjectsFromLayersPreservingOrder() {
        // CRITICAL FIX: Skip reordering during undo/redo operations to preserve exact order
        if isUndoRedoOperation {
            Log.info("🔧 POPULATE: Skipping unified objects population during undo/redo operation to preserve order", category: .general)
            return
        }
        
        // Unified objects is now the primary storage - this function is mostly a no-op
        Log.info("🔧 UNIFIED OBJECTS: Check complete with \(unifiedObjects.count) objects", category: .general)
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
        // Since unified objects is primary storage, just log the action
        Log.fileOperation("🔧 UNIFIED OBJECTS: Ordering check complete", level: .info)
    }
    
    /// OPTIMIZED: Update unified objects without full sync - preserves text object order and IDs
    func updateUnifiedObjectsOptimized() {
        // Skip during undo/redo operations to preserve exact order
        if isUndoRedoOperation {
            return
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
        
        Log.info("🔧 FORCE RESYNC: Unified objects system check with \(unifiedObjects.count) objects", category: .general)
    }
}