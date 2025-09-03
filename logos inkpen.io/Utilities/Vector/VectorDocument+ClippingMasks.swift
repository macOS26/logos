//
//  VectorDocument+ClippingMasks.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics

// MARK: - Clipping Masks
extension VectorDocument {
    /// Creates a clipping mask with top-most selected shape as the clipping path for the rest
    func makeClippingMaskFromSelection() {
        guard let layerIndex = selectedLayerIndex else { return }
        
        // REFACTORED: Use unified objects system for selection
        let selectedObjects = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }
        let selectedShapes = selectedObjects.compactMap { unifiedObject -> VectorShape? in
            if case .shape(let shape) = unifiedObject.objectType {
                return shape
            }
            return nil
        }
        
        guard selectedShapes.count >= 2 else { return }
        saveToUndoStack()
        
        // Use topmost as mask (last in array = topmost due to stacking order)
        guard let maskID = selectedShapes.last?.id else { return }
        
        // Log clipping mask creation for debugging
        if layers[layerIndex].shapes.first(where: { $0.id == maskID }) != nil {
            Log.info("🎭 CLIPPING MASK: Creating mask with shape '\(layers[layerIndex].shapes.first(where: { $0.id == maskID })?.name ?? "Unknown")'", category: .general)
        }
        
        // Mark mask
        if let idx = layers[layerIndex].shapes.firstIndex(where: { $0.id == maskID }) {
            layers[layerIndex].shapes[idx].isClippingPath = true
            Log.info("🎭 CLIPPING MASK DEBUG: Set isClippingPath=true for shape '\(layers[layerIndex].shapes[idx].name)' in layers array", category: .general)
        }
        
        // Apply clipping to others
        for s in selectedShapes.dropLast() {
            if let i = layers[layerIndex].shapes.firstIndex(where: { $0.id == s.id }) {
                layers[layerIndex].shapes[i].clippedByShapeID = maskID
                Log.info("🎭 CLIPPING MASK: Applied clipping to shape '\(s.name)'", category: .general)
            }
        }
        
        // CRITICAL FIX: Use unified objects system for selection
        // Find the unified object for the mask shape
        if let maskUnifiedObject = unifiedObjects.first(where: { 
            if case .shape(let shape) = $0.objectType {
                return shape.id == maskID
            }
            return false
        }) {
            selectedObjectIDs = [maskUnifiedObject.id]
            syncSelectionArrays() // Keep legacy arrays in sync
        }
        
        // CRITICAL: Sync unified objects after property changes
        updateUnifiedObjectsOptimized()
        
        // DEBUG: Check if unified objects were synced correctly
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if shape.id == maskID {
                    Log.info("🎭 CLIPPING MASK DEBUG: Unified object for mask '\(shape.name)' - isClippingPath: \(shape.isClippingPath)", category: .general)
                } else if selectedShapes.dropLast().contains(where: { $0.id == shape.id }) {
                    Log.info("🎭 CLIPPING MASK DEBUG: Unified object for clipped shape '\(shape.name)' - clippedByShapeID: \(shape.clippedByShapeID?.uuidString.prefix(8) ?? "nil")", category: .general)
                }
            }
        }
        
        objectWillChange.send()
        
        Log.info("✅ CLIPPING MASK: Created successfully with \(selectedShapes.count - 1) clipped shapes", category: .general)
    }
    
    /// Releases any clipping relationship among selected shapes
    func releaseClippingMaskForSelection() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        
        // REFACTORED: Use unified objects system for selection
        let selectedObjects = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }
        let selectedShapes = selectedObjects.compactMap { unifiedObject -> VectorShape? in
            if case .shape(let shape) = unifiedObject.objectType {
                return shape
            }
            return nil
        }
        
        // Determine any masks among selection
        let maskIDsToRelease: Set<UUID> = Set(selectedShapes.filter { $0.isClippingPath }.map { $0.id })
        
        // 1) Clear clipping relationship on selected shapes themselves
        for s in selectedShapes {
            if let i = layers[layerIndex].shapes.firstIndex(where: { $0.id == s.id }) {
                layers[layerIndex].shapes[i].clippedByShapeID = nil
                // If this shape is a mask and was selected, clear its mask flag
                if layers[layerIndex].shapes[i].isClippingPath { layers[layerIndex].shapes[i].isClippingPath = false }
            }
        }
        
        // 2) If any selected shape(s) are masks, clear all references to them
        if !maskIDsToRelease.isEmpty {
            for idx in layers[layerIndex].shapes.indices {
                if let clipID = layers[layerIndex].shapes[idx].clippedByShapeID, maskIDsToRelease.contains(clipID) {
                    layers[layerIndex].shapes[idx].clippedByShapeID = nil
                    
                    // CRITICAL FIX: Restore proper bounds for image shapes after releasing clipping mask
                    let shape = layers[layerIndex].shapes[idx]
                    if ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                        // Force bounds recalculation for image shapes
                        layers[layerIndex].shapes[idx].updateBounds()
                        Log.info("🎭 CLIPPING MASK: Restored bounds for image shape '\(shape.name)'", category: .general)
                    }
                }
            }
            // Clear mask flags on the mask shapes
            for idx in layers[layerIndex].shapes.indices {
                if maskIDsToRelease.contains(layers[layerIndex].shapes[idx].id) {
                    layers[layerIndex].shapes[idx].isClippingPath = false
                }
            }
        }
        
        // 3) CRITICAL FIX: Also restore bounds for any shapes that were clipped by the released masks
        for idx in layers[layerIndex].shapes.indices {
            let shape = layers[layerIndex].shapes[idx]
            if shape.clippedByShapeID == nil && (ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil) {
                // This image shape is no longer clipped, ensure its bounds are correct
                layers[layerIndex].shapes[idx].updateBounds()
                Log.info("🎭 CLIPPING MASK: Restored bounds for unclipped image shape '\(shape.name)'", category: .general)
            }
        }
        
        // CRITICAL: Sync unified objects after property changes
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
        
        Log.info("✅ CLIPPING MASK: Released successfully", category: .general)
    }
    
    /// Moves a clipping mask and all its clipped content together
    func moveClippingMask(_ maskID: UUID, by offset: CGPoint) {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        
        // Find the mask shape
        guard let maskIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == maskID }) else { return }
        
        // CRITICAL FIX: Update the mask shape's transform property for proper synchronization
        // This ensures the ClippingMaskNSView renders the mask in the correct position
        layers[layerIndex].shapes[maskIndex].transform = layers[layerIndex].shapes[maskIndex].transform.translatedBy(x: offset.x, y: offset.y)
        
        // Move the mask shape by updating its path coordinates (for selection bounds)
        moveShapeByPathCoordinates(layerIndex: layerIndex, shapeIndex: maskIndex, by: offset)
        
        // Move all clipped content by the same amount
        for idx in layers[layerIndex].shapes.indices {
            if layers[layerIndex].shapes[idx].clippedByShapeID == maskID {
                moveShapeByPathCoordinates(layerIndex: layerIndex, shapeIndex: idx, by: offset)
            }
        }
        
        // CRITICAL: Sync unified objects after property changes
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
        
        Log.info("🎭 CLIPPING MASK: Moved mask and clipped content by \(offset)", category: .general)
    }
    
    /// Helper function to move a shape by updating its path coordinates
    private func moveShapeByPathCoordinates(layerIndex: Int, shapeIndex: Int, by offset: CGPoint) {
        let shape = layers[layerIndex].shapes[shapeIndex]
        
        // For images and complex shapes, update the path coordinates directly
        if ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
            // For image shapes, update both transform and path coordinates
            layers[layerIndex].shapes[shapeIndex].transform = shape.transform.translatedBy(x: offset.x, y: offset.y)
            
            // Also update the path coordinates for the image bounds
            var updatedElements: [PathElement] = []
            for element in shape.path.elements {
                switch element {
                case .move(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.move(to: VectorPoint(newPoint)))
                case .line(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.line(to: VectorPoint(newPoint)))
                case .curve(let to, let control1, let control2):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl1 = CGPoint(x: control1.x + offset.x, y: control1.y + offset.y)
                    let newControl2 = CGPoint(x: control2.x + offset.x, y: control2.y + offset.y)
                    updatedElements.append(.curve(
                        to: VectorPoint(newTo),
                        control1: VectorPoint(newControl1),
                        control2: VectorPoint(newControl2)
                    ))
                case .quadCurve(let to, let control):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl = CGPoint(x: control.x + offset.x, y: control.y + offset.y)
                    updatedElements.append(.quadCurve(
                        to: VectorPoint(newTo),
                        control: VectorPoint(newControl)
                    ))
                case .close:
                    updatedElements.append(.close)
                }
            }
            layers[layerIndex].shapes[shapeIndex].path = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)
        } else {
            // For regular shapes, update path coordinates directly
            var updatedElements: [PathElement] = []
            for element in shape.path.elements {
                switch element {
                case .move(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.move(to: VectorPoint(newPoint)))
                case .line(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.line(to: VectorPoint(newPoint)))
                case .curve(let to, let control1, let control2):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl1 = CGPoint(x: control1.x + offset.x, y: control1.y + offset.y)
                    let newControl2 = CGPoint(x: control2.x + offset.x, y: control2.y + offset.y)
                    updatedElements.append(.curve(
                        to: VectorPoint(newTo),
                        control1: VectorPoint(newControl1),
                        control2: VectorPoint(newControl2)
                    ))
                case .quadCurve(let to, let control):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl = CGPoint(x: control.x + offset.x, y: control.y + offset.y)
                    updatedElements.append(.quadCurve(
                        to: VectorPoint(newTo),
                        control: VectorPoint(newControl)
                    ))
                case .close:
                    updatedElements.append(.close)
                }
            }
            layers[layerIndex].shapes[shapeIndex].path = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)
        }
        
        // Update bounds after moving
        layers[layerIndex].shapes[shapeIndex].updateBounds()
    }
    
    /// Checks if a shape is part of a clipping mask (either as mask or clipped content)
    func isShapeInClippingMask(_ shapeID: UUID) -> Bool {
        guard let layerIndex = selectedLayerIndex else { return false }
        
        if let shape = layers[layerIndex].shapes.first(where: { $0.id == shapeID }) {
            return shape.isClippingPath || shape.clippedByShapeID != nil
        }
        return false
    }
    
    /// Gets all shapes that are part of a clipping mask (including the mask itself)
    func getClippingMaskGroup(for maskID: UUID) -> [VectorShape] {
        guard let layerIndex = selectedLayerIndex else { return [] }
        
        var group: [VectorShape] = []
        
        // Add the mask shape
        if let maskShape = layers[layerIndex].shapes.first(where: { $0.id == maskID && $0.isClippingPath }) {
            group.append(maskShape)
        }
        
        // Add all clipped content
        for shape in layers[layerIndex].shapes {
            if shape.clippedByShapeID == maskID {
                group.append(shape)
            }
        }
        
        return group
    }
}