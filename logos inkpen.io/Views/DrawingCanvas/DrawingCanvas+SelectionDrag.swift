//
//  DrawingCanvas+SelectionDrag.swift
//  logos inkpen.io
//
//  Selection drag functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func startSelectionDrag() {
        guard let _ = document.selectedLayerIndex,
              !document.selectedObjectIDs.isEmpty else { return }
        
        // REFACTORED: Use unified objects system for selection checking
        let selectedObjects = document.unifiedObjects.filter { document.selectedObjectIDs.contains($0.id) }
        
        // PROTECT LOCKED OBJECTS: Check all selected objects for locked state
        for unifiedObject in selectedObjects {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isLocked {
                    Log.info("🚫 Cannot move locked shape '\(shape.name)'", category: .general)
                    return
                }
            }
        }
        
        // CRITICAL FIX: Save to undo stack BEFORE making any changes
        document.saveToUndoStack()
        
        // PROFESSIONAL OBJECT DRAGGING: Save initial positions AND transforms
        // This matches the precision approach used by the hand tool
        initialObjectPositions.removeAll()
        
        // Store initial positions AND transforms for all selected objects
        for unifiedObject in selectedObjects {
            switch unifiedObject.objectType {
            case .shape(let shape):
                Log.error("🚨 DRAG DEBUG: Processing shape id=\(shape.id), isTextObject=\(shape.isTextObject)", category: .debug)
                
                if shape.isTextObject {
                    // CRITICAL FIX: For text objects, use actual position from unified system + center offset
                    if let textObject = document.findText(by: shape.id) {
                        Log.error("🚨 DRAG DEBUG: Found textObject position=\(textObject.position), bounds=\(textObject.bounds)", category: .debug)
                        let centerX = textObject.position.x + textObject.bounds.width/2  
                        let centerY = textObject.position.y + textObject.bounds.height/2
                        let calculatedCenter = CGPoint(x: centerX, y: centerY)
                        Log.error("🚨 DRAG DEBUG: Calculated text center=\(calculatedCenter)", category: .debug)
                        initialObjectPositions[unifiedObject.id] = calculatedCenter
                    } else {
                        // Fallback: Use shape bounds center
                        Log.error("🚨 DRAG DEBUG: NO textObject found! Using shape fallback", category: .debug)
                        Log.error("🚨 DRAG DEBUG: Shape transform=\(shape.transform), bounds=\(shape.bounds)", category: .debug)
                        let bounds = shape.bounds
                        let centerX = shape.transform.tx + bounds.width/2
                        let centerY = shape.transform.ty + bounds.height/2
                        let fallbackCenter = CGPoint(x: centerX, y: centerY)
                        Log.error("🚨 DRAG DEBUG: Fallback text center=\(fallbackCenter)", category: .debug)
                        initialObjectPositions[unifiedObject.id] = fallbackCenter
                    }
                } else {
                    // GROUP POSITION FIX: Use appropriate bounds for groups vs individual shapes
                    // FLATTENED SHAPE FIX: Use actual path bounds for flattened shapes, not group bounds (CONSISTENT WITH SCALE TOOL)
                    let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                    let centerX = bounds.midX
                    let centerY = bounds.midY
                    initialObjectPositions[unifiedObject.id] = CGPoint(x: centerX, y: centerY)
                }
                
                // CRITICAL FIX: Store initial transform to prevent jitter
                Log.error("🚨 DRAG DEBUG: Storing initial transform=\(shape.transform)", category: .debug)
                initialObjectTransforms[unifiedObject.id] = shape.transform
            }
        }
        
        let shapeCount = selectedObjects.filter { if case .shape = $0.objectType { return true } else { return false } }.count
        let textCount = selectedObjects.filter { if case .shape(let shape) = $0.objectType, shape.isTextObject { return true } else { return false } }.count
        Log.fileOperation("🎯 SELECTION DRAG: Established reference positions for \(shapeCount) shapes and \(textCount) text objects", level: .info)
    }
    
    internal func handleSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let _ = document.selectedLayerIndex,
              !document.selectedObjectIDs.isEmpty else { return }
        
        // REFACTORED: Use unified objects system for selection checking
        let selectedObjects = document.unifiedObjects.filter { document.selectedObjectIDs.contains($0.id) }
        
        // PROTECT LOCKED OBJECTS: Check all selected objects for locked state
        for unifiedObject in selectedObjects {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isLocked {
                    return
                }
            }
        }
        
        // PROFESSIONAL OBJECT DRAGGING: Perfect cursor-to-object synchronization
        // Uses the same precision approach as the hand tool - calculate cursor delta directly
        // This eliminates floating-point accumulation errors from DragGesture.translation
        
        // Calculate cursor movement from reference location (perfect 1:1 tracking)
        let cursorDelta = CGPoint(
            x: value.location.x - selectionDragStart.x,
            y: value.location.y - selectionDragStart.y
        )
        
        // Convert screen delta to canvas delta (accounting for zoom)
        let preciseZoom = Double(document.zoomLevel)
        let canvasDelta = CGPoint(
            x: cursorDelta.x / preciseZoom,
            y: cursorDelta.y / preciseZoom
        )
        
        // CRITICAL FIX: For clipping masks, move the image shape DURING drag for live preview
        for unifiedObject in selectedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                // CLIPPING MASK PREVIEW: Use same preview system as regular objects
                // Don't modify actual document during drag - use currentDragDelta for preview
                if shape.isClippingPath {
                    Log.info("🎭 CLIPPING MASK PREVIEW: Using preview system for mask '\(shape.name)'", category: .selection)
                    // Continue with normal preview system - don't return early
                }
            }
        }
        
        // BLAZING FAST 60FPS: Store drag delta for preview rendering - DON'T modify actual objects during drag
        // This eliminates expensive document updates and bounds recalculation during drag
        currentDragDelta = canvasDelta
        
        // VECTOR APP OPTIMIZATION: Don't trigger full scene redraw - just update drag preview overlay
        // The dragged object will be rendered as a separate overlay, keeping all other objects static
        // NO dragPreviewUpdateTrigger.toggle() - we'll use SwiftUI overlay instead
    }
    
    internal func finishSelectionDrag() {
        // CRITICAL FIX: Don't apply selection drag if handle scaling was active
        if document.isHandleScalingActive {
            // Reset state without applying any transforms
            initialObjectPositions.removeAll()
            initialObjectTransforms.removeAll()
            selectionDragStart = CGPoint.zero
            currentDragDelta = .zero
            // Removed excessive logging during drag operations
            return
        }
        
        if !initialObjectPositions.isEmpty && currentDragDelta != .zero {
            // BLAZING FAST FINISH: Apply accumulated drag delta to actual coordinates at the end
            // This ensures smooth 60fps preview during drag, then commits changes once
            guard let _ = document.selectedLayerIndex else { return }
            
            // REFACTORED: Use unified objects system for applying drag delta
            let selectedObjects = document.unifiedObjects.filter { document.selectedObjectIDs.contains($0.id) }
            
            // Apply drag delta to all selected objects
            for unifiedObject in selectedObjects {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    let shapes = document.getShapesForLayer(unifiedObject.layerIndex)
                    if let shapeIndex = shapes.firstIndex(where: { $0.id == unifiedObject.id }) {
                        // CLIPPING MASK MOVEMENT: Use normal drag system (preview already handled movement)
                        if shape.isClippingPath {
                            // Clipping masks use the same drag system as regular shapes
                            // The preview system already showed the movement, so just apply normal coordinates
                            applyDragDeltaToShapeCoordinates(layerIndex: unifiedObject.layerIndex, shapeIndex: shapeIndex, delta: currentDragDelta)
                        } else {
                            // Regular shape movement
                            applyDragDeltaToShapeCoordinates(layerIndex: unifiedObject.layerIndex, shapeIndex: shapeIndex, delta: currentDragDelta)
                        }
                    }
                    
                    if let textObj = document.allTextObjects.first(where: { $0.id == unifiedObject.id }),
                       let initialCenter = initialObjectPositions[unifiedObject.id] {
                        // CRITICAL FIX: Use absolute positioning from initial reference, not delta accumulation
                        // Convert from center-based reference to position-based coordinates
                        let textBounds = textObj.bounds
                        let newPositionX = initialCenter.x - textBounds.width/2 + currentDragDelta.x
                        let newPositionY = initialCenter.y - textBounds.height/2 + currentDragDelta.y
                        
                        Log.error("🚨 FINISH DRAG: textID=\(unifiedObject.id)", category: .debug)
                        Log.error("🚨 FINISH DRAG: OLD position=\(textObj.position)", category: .debug)
                        Log.error("🚨 FINISH DRAG: NEW position=(\(newPositionX), \(newPositionY))", category: .debug)
                        Log.error("🚨 FINISH DRAG: initialCenter=\(initialCenter), dragDelta=\(currentDragDelta)", category: .debug)
                        
                        let delta = CGPoint(x: newPositionX - textObj.position.x, y: newPositionY - textObj.position.y)
                        document.translateTextInUnified(id: unifiedObject.id, delta: CGVector(dx: delta.x, dy: delta.y))
                        
                        Log.error("🚨 FINISH DRAG: Updated textObject position to (\(newPositionX), \(newPositionY))", category: .debug)
                    }
                }
            }
            
            // CRITICAL FIX: Sync unified objects with moved shapes
            syncUnifiedObjectsAfterMovement()
            
            // PROFESSIONAL OBJECT DRAGGING: Clean state reset for next drag operation
            // This ensures each new drag operation starts with fresh reference points
            _ = initialObjectPositions.count
            
            // Reset state
            initialObjectPositions.removeAll()
            initialObjectTransforms.removeAll()
            selectionDragStart = CGPoint.zero
            currentDragDelta = .zero
            
            // Selection drag completed - reduced logging for performance
        }
    }
    
    /// BLAZING FAST: Apply drag delta to actual coordinates (only called at end of drag)
    private func applyDragDeltaToShapeCoordinates(layerIndex: Int, shapeIndex: Int, delta: CGPoint) {
        guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        
        // SPECIAL CASE: Raster image shapes are rendered using their transform, not path coordinates.
        // Move them by updating the transform translation rather than rewriting path points.
        if ImageContentRegistry.containsImage(shape) {
            var updatedShape = shape
            
            // CRITICAL FIX: For transformed images, we need to handle the coordinate system properly
            // to prevent jumping when the image has scaling, rotation, or other transforms
            if updatedShape.transform.isIdentity {
                // Simple case: no existing transforms, just add translation
                updatedShape.transform = updatedShape.transform.translatedBy(x: delta.x, y: delta.y)
            } else {
                // COMPLEX CASE: Image has existing transforms (scale, rotation, etc.)
                // We need to decompose the transform, add the translation, and recompose
                // This prevents coordinate system drift and jumping
                
                // Extract the current transform components
                let currentTransform = updatedShape.transform
                
                // Create a pure translation transform for the delta
                let translationTransform = CGAffineTransform(translationX: delta.x, y: delta.y)
                
                // Apply the translation to the existing transform
                // This preserves all existing scaling, rotation, and skew while adding movement
                updatedShape.transform = currentTransform.concatenating(translationTransform)
                
                Log.info("🖼️ IMAGE TRANSFORM: Applied delta (\(String(format: "%.2f", delta.x)), \(String(format: "%.2f", delta.y))) to existing transform", category: .fileOperations)
            }
            
            // Bounds for images are their rectangular path; keep as-is (transform applied at render time)
            document.updateShapeTransformAndPathInUnified(id: updatedShape.id, path: updatedShape.path, transform: updatedShape.transform)
            return
        }
        
        // FLATTENED SHAPE FIX: Handle groups correctly
        if shape.isGroupContainer && !shape.groupedShapes.isEmpty {
            // Apply delta to each individual shape within the flattened group
            var updatedGroupedShapes: [VectorShape] = []
            
            for var groupedShape in shape.groupedShapes {
                // Apply delta to all path elements of this grouped shape
                var updatedElements: [PathElement] = []
                
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to):
                        let newPoint = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                        updatedElements.append(.move(to: VectorPoint(newPoint)))
                        
                    case .line(let to):
                        let newPoint = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                        updatedElements.append(.line(to: VectorPoint(newPoint)))
                        
                    case .curve(let to, let control1, let control2):
                        let newTo = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                        let newControl1 = CGPoint(x: control1.x + delta.x, y: control1.y + delta.y)
                        let newControl2 = CGPoint(x: control2.x + delta.x, y: control2.y + delta.y)
                        updatedElements.append(.curve(
                            to: VectorPoint(newTo),
                            control1: VectorPoint(newControl1),
                            control2: VectorPoint(newControl2)
                        ))
                        
                    case .quadCurve(let to, let control):
                        let newTo = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                        let newControl = CGPoint(x: control.x + delta.x, y: control.y + delta.y)
                        updatedElements.append(.quadCurve(
                            to: VectorPoint(newTo),
                            control: VectorPoint(newControl)
                        ))
                        
                    case .close:
                        updatedElements.append(.close)
                    }
                }
                
                // Update this grouped shape with moved coordinates
                groupedShape.path = VectorPath(elements: updatedElements, isClosed: groupedShape.path.isClosed)
                groupedShape.updateBounds()
                
                updatedGroupedShapes.append(groupedShape)
            }
            
            // Update the flattened group with the moved individual shapes
            var groupShape = shape
            groupShape.groupedShapes = updatedGroupedShapes
            
            // CRITICAL FIX: Update warp envelope coordinates for warp objects in groups
            if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
                var updatedWarpEnvelope: [CGPoint] = []
                for corner in shape.warpEnvelope {
                    let movedCorner = CGPoint(x: corner.x + delta.x, y: corner.y + delta.y)
                    updatedWarpEnvelope.append(movedCorner)
                }
                groupShape.warpEnvelope = updatedWarpEnvelope
                
                // CRITICAL FIX: DO NOT move originalEnvelope - it must stay as reference coordinate system
                Log.fileOperation("🔧 GROUP WARP ENVELOPE MOVED: Updated \(updatedWarpEnvelope.count) current coordinates (original envelope preserved)", level: .info)
            }
            
            groupShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: groupShape)
            return
        }
        
        // Apply delta to all path elements
        var updatedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let newPoint = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                updatedElements.append(.move(to: VectorPoint(newPoint)))
                
            case .line(let to):
                let newPoint = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                updatedElements.append(.line(to: VectorPoint(newPoint)))
                
            case .curve(let to, let control1, let control2):
                let newTo = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                let newControl1 = CGPoint(x: control1.x + delta.x, y: control1.y + delta.y)
                let newControl2 = CGPoint(x: control2.x + delta.x, y: control2.y + delta.y)
                updatedElements.append(.curve(
                    to: VectorPoint(newTo),
                    control1: VectorPoint(newControl1),
                    control2: VectorPoint(newControl2)
                ))
                
            case .quadCurve(let to, let control):
                let newTo = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                let newControl = CGPoint(x: control.x + delta.x, y: control.y + delta.y)
                updatedElements.append(.quadCurve(
                    to: VectorPoint(newTo),
                    control: VectorPoint(newControl)
                ))
                
            case .close:
                updatedElements.append(.close)
            }
        }
        
        // Create new path with moved coordinates
        let updatedPath = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)
        
        // Update the shape with moved path
        var movedShape = shape
        movedShape.path = updatedPath
        
        // CRITICAL FIX: Update warp envelope coordinates for warp objects
        if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
            var updatedWarpEnvelope: [CGPoint] = []
            for corner in shape.warpEnvelope {
                let movedCorner = CGPoint(x: corner.x + delta.x, y: corner.y + delta.y)
                updatedWarpEnvelope.append(movedCorner)
            }
            movedShape.warpEnvelope = updatedWarpEnvelope
            
            // CRITICAL FIX: DO NOT move originalEnvelope - it must stay as reference coordinate system
            // The originalEnvelope represents the coordinate system before ANY transformations
            Log.fileOperation("🔧 WARP ENVELOPE MOVED: Updated \(updatedWarpEnvelope.count) current coordinates (original envelope preserved)", level: .info)
        }
        
        // CLIPPING MASK: If this is a mask shape, also move all its clipped content
        if shape.isClippingPath {
            let shapes = document.getShapesForLayer(layerIndex)
            for (idx, checkShape) in shapes.enumerated() {
                if checkShape.clippedByShapeID == shape.id {
                    // Move the clipped shape by the same delta
                    applyDragDeltaToShapeCoordinates(layerIndex: layerIndex, shapeIndex: idx, delta: delta)
                }
            }
        }
        
        movedShape.updateBounds()
        document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: movedShape)
    }

    /// PERFORMANCE OPTIMIZED: Apply transform to actual coordinates (only called at end of drag)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int) {
        guard var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let transform = shape.transform
        
        // Don't apply identity transforms
        if transform.isIdentity {
            return
        }
        
        Log.fileOperation("🔧 Applying transform to shape coordinates: \(shape.name)", level: .info)
        
        // FLATTENED SHAPE FIX: Handle groups correctly
        if shape.isGroupContainer && !shape.groupedShapes.isEmpty {
            // Transform each individual shape within the flattened group
            var transformedGroupedShapes: [VectorShape] = []
            
            for var groupedShape in shape.groupedShapes {
                // Transform all path elements of this grouped shape
                var transformedElements: [PathElement] = []
                
                for element in groupedShape.path.elements {
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
                
                // Update this grouped shape with transformed coordinates
                groupedShape.path = VectorPath(elements: transformedElements, isClosed: groupedShape.path.isClosed)
                groupedShape.transform = .identity
                groupedShape.updateBounds()
                
                transformedGroupedShapes.append(groupedShape)
            }
            
            // Update the flattened group with the transformed individual shapes
            shape.groupedShapes = transformedGroupedShapes
            shape.transform = .identity
            shape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
            
            Log.info("✅ Flattened group coordinates updated - transformed \(transformedGroupedShapes.count) individual shapes", category: .fileOperations)
            return
        }
        
        // Transform regular shape path elements
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
        
        // Create new path with transformed coordinates
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        // Update the shape with transformed path and reset transform to identity
        shape.path = transformedPath
        shape.transform = .identity
        shape.updateBounds()
        
        // CORNER RADIUS SCALING: Apply transform to corner radii if this shape has them
        var updatedShape = shape
        if !updatedShape.cornerRadii.isEmpty && updatedShape.isRoundedRectangle {
            updatedShape.transform = transform // Temporarily restore transform for scaling calculation
            applyTransformToCornerRadii(shape: &updatedShape)
            document.updateShapeCornerRadiiInUnified(id: updatedShape.id, cornerRadii: updatedShape.cornerRadii, path: updatedShape.path)
        }
        
        Log.info("✅ Shape coordinates updated after movement - object origin stays with object", category: .fileOperations)
    }
    
    /// CRITICAL FIX: Sync unified objects array after shapes/text have been moved
    /// IMPORTANT: This only updates object data without changing layer ordering
    private func syncUnifiedObjectsAfterMovement() {
        // CRITICAL FIX: Don't call populateUnifiedObjectsFromLayers() which reorders everything!
        // Just update the object data while preserving orderID and layerIndex
        
        // Update unified objects to reflect changes in layers and textObjects
        for i in document.unifiedObjects.indices {
            let unifiedObject = document.unifiedObjects[i]
            
            switch unifiedObject.objectType {
            case .shape(let oldShape):
                // CRITICAL FIX: Handle text objects - sync unified objects FROM textObjects (after drag)
                if oldShape.isTextObject {
                    Log.error("🚨 SYNC DEBUG: Text object - syncing unified objects FROM allTextObjects (CORRECTED)", category: .debug)
                    if let updatedText = document.allTextObjects.first(where: { $0.id == oldShape.id }) {
                        Log.error("🚨 SYNC DEBUG: Updating unified object position to (\(updatedText.position.x), \(updatedText.position.y))", category: .debug)
                        
                        // CRITICAL FIX: Update unified object FROM textObjects array (textObjects has new position)
                        let updatedShape = VectorShape.from(updatedText)
                        document.unifiedObjects[i] = VectorObject(
                            shape: updatedShape,
                            layerIndex: unifiedObject.layerIndex,
                            orderID: unifiedObject.orderID  // Keep same orderID = no reordering
                        )
                        
                        Log.error("🚨 SYNC DEBUG: Updated unified objects array from textObjects authority", category: .debug)
                    } else {
                        Log.error("🚨 SYNC DEBUG: TEXT OBJECT NOT FOUND in textObjects array!", category: .debug)
                    }
                } else {
                    // Regular shapes - find in unified objects
                    if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if let updatedShape = shapes.first(where: { $0.id == oldShape.id }) {
                            // DEBUG: Check clipping properties before and after sync
                            if oldShape.clippedByShapeID != nil || updatedShape.clippedByShapeID != nil {
                                Log.info("🎭 DRAG SYNC DEBUG: Shape '\(oldShape.name)' - old clippedByShapeID: \(oldShape.clippedByShapeID?.uuidString.prefix(8) ?? "nil"), new clippedByShapeID: \(updatedShape.clippedByShapeID?.uuidString.prefix(8) ?? "nil")", category: .general)
                            }
                            // CRITICAL FIX: Preserve original orderID - DO NOT reorder during drag
                            document.unifiedObjects[i] = VectorObject(
                                shape: updatedShape,
                                layerIndex: unifiedObject.layerIndex,
                                orderID: unifiedObject.orderID  // Keep same orderID = no reordering
                            )
                        }
                    }
                }
            }
        }
        
        Log.info("🔧 DRAG SYNC: Updated unified objects data without reordering", category: .general)
    }
} 