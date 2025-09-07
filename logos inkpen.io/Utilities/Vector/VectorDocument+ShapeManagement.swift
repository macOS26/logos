//
//  VectorDocument+ShapeManagement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics

// MARK: - Shape Management
extension VectorDocument {
    func addShape(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        layers[layerIndex].addShape(shape)
        
        // Add to unified system
        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        
        selectedShapeIDs = [shape.id]
        selectedObjectIDs = [shape.id]
        syncSelectionArrays()
    }
    
    /// Add shape to the front of the current layer (for drawing tools)
    func addShapeToFront(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        layers[layerIndex].addShape(shape)
        
        // Add to front of unified system
        addShapeToFrontOfUnifiedSystem(shape, layerIndex: layerIndex)
        
        selectedShapeIDs = [shape.id]
        selectedObjectIDs = [shape.id]
        syncSelectionArrays()
    }
    
    /// Add shape to a specific layer with unified system support
    func addShape(_ shape: VectorShape, to layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        saveToUndoStack()
        layers[layerIndex].addShape(shape)
        
        // Add to unified system
        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
    }
    
    func removeSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        
        // CRITICAL PROTECTION: Filter out background shapes that should never be deleted
        let shapesToRemove = getShapesForLayer(layerIndex).filter { shape in
            if selectedShapeIDs.contains(shape.id) {
                // NEVER allow deletion of Canvas or Pasteboard background shapes
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    Log.error("🚫 PROTECTED: Attempted to delete protected background shape '\(shape.name)' - BLOCKED", category: .error)
                    return false
                }
                return true
            }
            return false
        }
        
        // Remove only the non-protected shapes
        for shape in shapesToRemove {
            removeShapesUnified(layerIndex: layerIndex, where: { $0.id == shape.id })
        }
        
        selectedShapeIDs.removeAll()
        
        Log.fileOperation("🗑️ SHAPES: Deleted \(shapesToRemove.count) shapes (protected background shapes)", level: .info)
    }
    
    // CRITICAL FIX: Unified deletion method that works with unified objects system
    func removeSelectedObjects() {
        saveToUndoStack()
        
        // Get the objects to delete from unified system
        let objectsToDelete = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }
        
        // CRITICAL PROTECTION: Filter out background shapes that should never be deleted
        let protectedObjects = objectsToDelete.filter { objectToDelete in
            switch objectToDelete.objectType {
            case .shape(let shape):
                // NEVER allow deletion of Canvas or Pasteboard background shapes
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    Log.error("🚫 PROTECTED: Attempted to delete protected background shape '\(shape.name)' - BLOCKED", category: .error)
                    return false
                }
                return true
            }
        }
        
        if protectedObjects.count != objectsToDelete.count {
            let blockedCount = objectsToDelete.count - protectedObjects.count
            Log.error("🚫 PROTECTION: Blocked deletion of \(blockedCount) protected background shapes", category: .error)
        }
        
        // Remove from legacy arrays first
        for objectToDelete in protectedObjects {
            switch objectToDelete.objectType {
            case .shape(let shape):
                if !shape.isTextObject {
                    // Remove from layers array for regular shapes
                    if let layerIndex = objectToDelete.layerIndex < layers.count ? objectToDelete.layerIndex : nil {
                        removeShapesUnified(layerIndex: layerIndex, where: { $0.id == shape.id })
                    }
                }
            }
        }
        
        // Remove from unified objects array
        unifiedObjects.removeAll { selectedObjectIDs.contains($0.id) }
        
        // Clear selection
        selectedObjectIDs.removeAll()
        
        // Sync legacy selection arrays
        syncSelectionArrays()
        
        Log.fileOperation("🗑️ UNIFIED: Deleted \(protectedObjects.count) objects (protected \(objectsToDelete.count - protectedObjects.count) background shapes)", level: .info)
    }
    
    /// Gets all currently selected shapes across all layers
    func getSelectedShapes() -> [VectorShape] {
        var selectedShapes: [VectorShape] = []
        
        // Use unified objects to get selected shapes
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if selectedShapeIDs.contains(shape.id) {
                    selectedShapes.append(shape)
                }
            }
        }
        
        return selectedShapes
    }
    
    /// Gets shapes by their IDs across all layers
    func getShapesByIds(_ shapeIDs: Set<UUID>) -> [VectorShape] {
        var shapes: [VectorShape] = []
        
        // Use unified objects to get shapes by IDs
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if shapeIDs.contains(shape.id) {
                    shapes.append(shape)
                }
            }
        }
        
        return shapes
    }
    
    /// Gets the currently active shape IDs based on tool state
    /// This considers both regular selection and direct selection
    func getActiveShapeIDs() -> Set<UUID> {
        // If direct selection tool is active and we have direct selected shapes, use those
        if currentTool == .directSelection || currentTool == .convertAnchorPoint || currentTool == .penPlusMinus,
           !directSelectedShapeIDs.isEmpty {
            return directSelectedShapeIDs
        }
        
        // Otherwise use regular selection
        return selectedShapeIDs
    }
    
    /// Gets the currently active shapes based on tool state
    /// This considers both regular selection and direct selection
    func getActiveShapes() -> [VectorShape] {
        let activeShapeIDs = getActiveShapeIDs()
        return getShapesByIds(activeShapeIDs)
    }
    
    /// Gets all objects in proper layer stacking order (bottom→top, then by orderID within layer)
    func getObjectsInStackingOrder() -> [VectorObject] {
        return unifiedObjects
            .filter { $0.isVisible }
            .sorted { obj1, obj2 in
                // First sort by layer index (bottom to top)
                if obj1.layerIndex != obj2.layerIndex {
                    return obj1.layerIndex < obj2.layerIndex
                }
                // Then sort by orderID within the same layer
                return obj1.orderID < obj2.orderID
            }
    }
    
    /// Gets all currently selected shapes in correct STACKING ORDER (bottom→top)
    /// This is critical for pathfinder operations
    func getSelectedShapesInStackingOrder() -> [VectorShape] {
        var stackingOrderShapes: [VectorShape] = []
        
        // Process shapes from bottom to top using unified objects (already in stacking order)
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if selectedShapeIDs.contains(shape.id) {
                    stackingOrderShapes.append(shape)
                }
            }
        }
        
        return stackingOrderShapes
    }
    
    /// Selects a shape by its ID (clears other selections)
    func selectShape(_ shapeID: UUID) {
        // Find the unified object for this shape
        if let unifiedObject = unifiedObjects.first(where: { 
            if case .shape(let shape) = $0.objectType {
                return shape.id == shapeID
            }
            return false
        }) {
            selectedObjectIDs = [unifiedObject.id]
            syncSelectionArrays() // Keep legacy arrays in sync
        }
    }
    
    /// Adds a shape to the current selection (multi-select)
    func addToSelection(_ shapeID: UUID) {
        // Find the unified object for this shape
        if let unifiedObject = unifiedObjects.first(where: { 
            if case .shape(let shape) = $0.objectType {
                return shape.id == shapeID
            }
            return false
        }) {
            selectedObjectIDs.insert(unifiedObject.id)
            syncSelectionArrays() // Keep legacy arrays in sync
        }
    }
    
    /// PROFESSIONAL SELECT ALL
    func selectAll() {
        guard let layerIndex = selectedLayerIndex else { return }
        
        // Get all visible, unlocked objects for this layer from unified array
        let layerObjects = unifiedObjects.filter { 
            $0.layerIndex == layerIndex && $0.isVisible && !$0.isLocked 
        }
        
        if !layerObjects.isEmpty {
            selectedObjectIDs = Set(layerObjects.map { $0.id })
            syncSelectionArrays() // Keep legacy arrays in sync
            Log.fileOperation("🎯 SELECT ALL: Selected \(layerObjects.count) objects", level: .info)
        } else {
            Log.fileOperation("🎯 SELECT ALL: No selectable objects found", level: .info)
        }
    }
    
    func duplicateSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        
        // Get selected shapes from unified array
        let selectedShapes = unifiedObjects.filter { unifiedObject in
            guard selectedObjectIDs.contains(unifiedObject.id) && 
                  unifiedObject.layerIndex == layerIndex else { return false }
            
            if case .shape = unifiedObject.objectType {
                return true
            } else {
                return false
            }
        }
        
        var newShapeIDs: Set<UUID> = []
        
        for unifiedObject in selectedShapes {
            if case .shape(let shape) = unifiedObject.objectType {
                var newShape = shape
                newShape.id = UUID() // 🎯 CRITICAL: Generate new ID for duplicate
                // Duplicate raster content mapping when present
                if ImageContentRegistry.containsImage(shape),
                   let image = ImageContentRegistry.image(for: shape.id) {
                    ImageContentRegistry.register(image: image, for: newShape.id)
                }
                
                // PROFESSIONAL COORDINATE SYSTEM: Apply offset to actual coordinates instead of using transform
                // This ensures object origin follows object position
                let offsetTransform = CGAffineTransform(translationX: 10, y: 10)
                newShape = applyTransformToShapeCoordinates(shape: newShape, transform: offsetTransform)
                newShape.updateBounds()
                addShape(newShape, to: layerIndex)
                newShapeIDs.insert(newShape.id)
            }
        }
        
        // Update selection to the new shapes
        selectedShapeIDs = newShapeIDs
        syncUnifiedSelectionFromLegacy() // Keep unified array in sync
    }
    
    /// PROFESSIONAL COORDINATE SYSTEM: Apply transform to shape coordinates
    /// Returns a new shape with transformed coordinates and identity transform
    internal func applyTransformToShapeCoordinates(shape: VectorShape, transform: CGAffineTransform) -> VectorShape {
        // Don't apply identity transforms
        if transform.isIdentity {
            return shape
        }
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(transform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(transform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(transform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
                
            case .close:
                transformedElements.append(.close)
            }
        }
        
        // Create new shape with transformed path and identity transform
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        var newShape = shape
        newShape.path = transformedPath
        newShape.transform = .identity
        
        return newShape
    }
}