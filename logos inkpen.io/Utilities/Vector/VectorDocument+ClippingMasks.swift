//
//  VectorDocument+ClippingMasks.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import Combine

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

        // Mark mask
        let shapes = getShapesForLayer(layerIndex)
        if let idx = shapes.firstIndex(where: { $0.id == maskID }),
           var maskShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: idx) {
            maskShape.isClippingPath = true
            setShapeAtIndex(layerIndex: layerIndex, shapeIndex: idx, shape: maskShape)
        }
        
        // Apply clipping to others
        for s in selectedShapes.dropLast() {
            let shapes = getShapesForLayer(layerIndex)
            if let i = shapes.firstIndex(where: { $0.id == s.id }),
               var clippedShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: i) {
                clippedShape.clippedByShapeID = maskID
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: i, shape: clippedShape)
            }
        }
        
        // CRITICAL FIX: Use unified objects system for selection
        // Find the unified object for the mask shape
        // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
        if let maskUnifiedObject = findObject(by: maskID) {
            selectedObjectIDs = [maskUnifiedObject.id]
            syncSelectionArrays() // Keep legacy arrays in sync
        }
        
        // DEBUG: Check layers array before unified sync
        for (idx, _) in layers.enumerated() {
            _ = getShapesForLayer(idx)
        }
        
        // CRITICAL FIX: Use full resync for clipping mask changes since they affect object relationships
        forceResyncUnifiedObjects()
        
        // DEBUG: Check if unified objects were synced correctly
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if shape.id == maskID {
                } else if selectedShapes.dropLast().contains(where: { $0.id == shape.id }) {
                }
            }
        }
        
        // Force immediate UI update
        objectWillChange.send()
        
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
            let shapes = getShapesForLayer(layerIndex)
            if let i = shapes.firstIndex(where: { $0.id == s.id }),
               var shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: i) {
                shape.clippedByShapeID = nil
                // If this shape is a mask and was selected, clear its mask flag
                if shape.isClippingPath { shape.isClippingPath = false }
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: i, shape: shape)
            }
        }
        
        // 2) If any selected shape(s) are masks, clear all references to them
        if !maskIDsToRelease.isEmpty {
            let shapes = getShapesForLayer(layerIndex)
            for (idx, shape) in shapes.enumerated() {
                if let clipID = shape.clippedByShapeID, maskIDsToRelease.contains(clipID) {
                    var updatedShape = shape
                    updatedShape.clippedByShapeID = nil
                    
                    // CRITICAL FIX: Restore proper bounds for image shapes after releasing clipping mask
                    if ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                        // Force bounds recalculation for image shapes
                        updatedShape.updateBounds()
                    }
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: idx, shape: updatedShape)
                }
            }
            // Clear mask flags on the mask shapes
            for (idx, shape) in shapes.enumerated() {
                if maskIDsToRelease.contains(shape.id) {
                    var updatedShape = shape
                    updatedShape.isClippingPath = false
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: idx, shape: updatedShape)
                }
            }
        }
        
        // 3) CRITICAL FIX: Also restore bounds for any shapes that were clipped by the released masks
        let allShapes = getShapesForLayer(layerIndex)
        for (idx, shape) in allShapes.enumerated() {
            if shape.clippedByShapeID == nil && (ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil) {
                // This image shape is no longer clipped, ensure its bounds are correct
                var updatedShape = shape
                updatedShape.updateBounds()
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: idx, shape: updatedShape)
            }
        }
        
        // CRITICAL FIX: Use full resync for clipping mask changes
        forceResyncUnifiedObjects()
        objectWillChange.send()
        
    }
    
    /// Moves a clipping mask and all its clipped content together
    func moveClippingMask(_ maskID: UUID, by offset: CGPoint) {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        
        // Find the mask shape
        let shapes = getShapesForLayer(layerIndex)
        guard let maskIndex = shapes.firstIndex(where: { $0.id == maskID }),
              var maskShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: maskIndex) else { return }
        
        // CRITICAL FIX: Update the mask shape's transform property for proper synchronization
        // This ensures the ClippingMaskNSView renders the mask in the correct position
        maskShape.transform = maskShape.transform.translatedBy(x: offset.x, y: offset.y)
        setShapeAtIndex(layerIndex: layerIndex, shapeIndex: maskIndex, shape: maskShape)
        
        // Move the mask shape by updating its path coordinates (for selection bounds)
        moveShapeByPathCoordinates(layerIndex: layerIndex, shapeIndex: maskIndex, by: offset)
        
        // Move all clipped content by the same amount
        let allShapes = getShapesForLayer(layerIndex)
        for (idx, shape) in allShapes.enumerated() {
            if shape.clippedByShapeID == maskID {
                moveShapeByPathCoordinates(layerIndex: layerIndex, shapeIndex: idx, by: offset)
            }
        }
        
        // CRITICAL FIX: Use full resync for clipping mask changes
        forceResyncUnifiedObjects()
        objectWillChange.send()
        
    }
    
    /// Helper function to move a shape by updating its path coordinates
    private func moveShapeByPathCoordinates(layerIndex: Int, shapeIndex: Int, by offset: CGPoint) {
        guard var shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        
        // For images and complex shapes, update the path coordinates directly
        if ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
            // For image shapes, update both transform and path coordinates
            shape.transform = shape.transform.translatedBy(x: offset.x, y: offset.y)
            
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
            shape.path = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)
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
            shape.path = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)
        }
        
        // Update bounds after moving
        shape.updateBounds()
        setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
    }
    
    /// Checks if a shape is part of a clipping mask (either as mask or clipped content)
    func isShapeInClippingMask(_ shapeID: UUID) -> Bool {
        // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
        if let shape = findShape(by: shapeID) {
            return shape.isClippingPath || shape.clippedByShapeID != nil
        }
        return false
    }
    
    /// Gets all shapes that are part of a clipping mask (including the mask itself)
    func getClippingMaskGroup(for maskID: UUID) -> [VectorShape] {
        guard let layerIndex = selectedLayerIndex else { return [] }

        var group: [VectorShape] = []

        // Add the mask shape
        // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
        if let maskShape = findShape(by: maskID), maskShape.isClippingPath {
            group.append(maskShape)
        }

        let shapes = getShapesForLayer(layerIndex)
        
        // Add all clipped content
        for shape in shapes {
            if shape.clippedByShapeID == maskID {
                group.append(shape)
            }
        }
        
        return group
    }
}
