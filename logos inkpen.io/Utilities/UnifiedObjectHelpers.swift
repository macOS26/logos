//
//  UnifiedObjectHelpers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/21/25.
//
//  Consolidated unified object system access helpers to eliminate duplicate code
//  across DrawingCanvas extensions

import SwiftUI

/// Centralized utilities for working with the unified objects system
enum UnifiedObjectHelpers {
    
    // MARK: - Object Lookup
    
    /// Find a unified object by its ID
    static func findObject(byId id: UUID, in unifiedObjects: [VectorObject]) -> (object: VectorObject, index: Int)? {
        guard let index = unifiedObjects.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return (unifiedObjects[index], index)
    }
    
    /// Find a shape in the unified objects array
    static func findShape(byId shapeId: UUID, in unifiedObjects: [VectorObject]) -> (shape: VectorShape, index: Int)? {
        for (index, object) in unifiedObjects.enumerated() {
            if case .shape(let shape) = object.objectType,
               shape.id == shapeId {
                return (shape, index)
            }
        }
        return nil
    }
    
    // Text objects are not yet implemented in the VectorObject system
    // This is a placeholder for future text object support
    
    // MARK: - Layer Operations
    
    /// Get all shapes for a specific layer from unified objects
    static func getShapesForLayer(_ layerIndex: Int, from unifiedObjects: [VectorObject]) -> [VectorShape] {
        return unifiedObjects.compactMap { object in
            if object.layerIndex == layerIndex,
               case .shape(let shape) = object.objectType {
                return shape
            }
            return nil
        }
    }
    
    // Text objects are not yet implemented - placeholder for future support
    
    /// Get all objects for a specific layer
    static func getObjectsForLayer(_ layerIndex: Int, from unifiedObjects: [VectorObject]) -> [VectorObject] {
        return unifiedObjects.filter { $0.layerIndex == layerIndex }
    }
    
    // MARK: - Object Type Checking
    
    /// Check if an object is a shape
    static func isShape(_ object: VectorObject) -> Bool {
        if case .shape = object.objectType {
            return true
        }
        return false
    }
    
    // Text object checking will be added when text support is implemented
    
    /// Get the shape from a vector object if it contains one
    static func getShape(from object: VectorObject) -> VectorShape? {
        if case .shape(let shape) = object.objectType {
            return shape
        }
        return nil
    }
    
    // Text object extraction will be added when text support is implemented
    
    // MARK: - Object Updates
    
    /// Update a shape in the unified objects array
    static func updateShape(
        _ shape: VectorShape,
        at index: Int,
        in unifiedObjects: inout [VectorObject],
        preserveOrderID: Bool = true
    ) {
        guard index < unifiedObjects.count,
              case .shape = unifiedObjects[index].objectType else {
            return
        }
        
        let layerIndex = unifiedObjects[index].layerIndex
        let orderID = preserveOrderID ? unifiedObjects[index].orderID : unifiedObjects[index].orderID
        unifiedObjects[index] = VectorObject(
            shape: shape,
            layerIndex: layerIndex,
            orderID: orderID
        )
    }
    
    // Text object update will be added when text support is implemented
    
    // MARK: - Selection Helpers
    
    /// Get all selected shapes from unified objects
    static func getSelectedShapes(from unifiedObjects: [VectorObject], selectedIDs: Set<UUID>) -> [(shape: VectorShape, index: Int)] {
        var selectedShapes: [(shape: VectorShape, index: Int)] = []

        for (index, object) in unifiedObjects.enumerated() {
            if case .shape(let shape) = object.objectType,
               selectedIDs.contains(shape.id) {
                selectedShapes.append((shape, index))
            }
        }

        return selectedShapes
    }
    
    // Selected text objects will be added when text support is implemented
    
    /// Get all selected objects (shapes and text)
    static func getSelectedObjects(from unifiedObjects: [VectorObject], selectedIDs: Set<UUID>) -> [VectorObject] {
        return unifiedObjects.filter { object in
            selectedIDs.contains(object.id)
        }
    }
    
    // MARK: - Bounds Calculations
    
    /// Calculate combined bounds of multiple objects
    static func calculateCombinedBounds(of objects: [VectorObject]) -> CGRect {
        var bounds = CGRect.null
        
        for object in objects {
            let objectBounds: CGRect
            switch object.objectType {
            case .shape(let shape):
                objectBounds = shape.bounds
            // Text object bounds will be added later
            }
            
            if bounds.isNull {
                bounds = objectBounds
            } else {
                bounds = bounds.union(objectBounds)
            }
        }
        
        return bounds.isNull ? .zero : bounds
    }
    
    // MARK: - Order Management
    
    /// Sort unified objects by order ID
    static func sortByOrder(_ objects: [VectorObject]) -> [VectorObject] {
        return objects.sorted { $0.orderID < $1.orderID }
    }
    
    /// Reindex order IDs to ensure sequential ordering
    static func reindexOrderIDs(_ objects: inout [VectorObject]) {
        // Note: orderID is immutable in current implementation
        // Would need to recreate VectorObject to change orderID
        // This function would require rebuilding the entire array with new VectorObjects
    }
    
    // MARK: - Background Shape Detection
    
    // Background shape detection would require checking shape properties
    // This functionality may be stored elsewhere in the document structure
    
    // Background shape finding would require checking shape properties
    // This functionality may be stored elsewhere in the document structure
    
    // MARK: - Group Operations
    
    /// Check if a shape is a group
    static func isGroup(_ shape: VectorShape) -> Bool {
        return shape.isGroup
    }

    /// Get all shapes in a group
    static func getGroupMembers(_ group: VectorShape, from unifiedObjects: [VectorObject]) -> [VectorShape] {
        guard group.isGroup else { return [] }
        
        // Groups contain child shape IDs that need to be resolved
        // This would require additional group membership tracking
        // For now, return empty array - implement when group structure is clear
        return []
    }
}