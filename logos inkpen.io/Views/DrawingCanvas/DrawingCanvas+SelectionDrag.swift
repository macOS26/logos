//
//  DrawingCanvas+SelectionDrag.swift
//  logos inkpen.io
//
//  Selection drag functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func startSelectionDrag() {
        guard let layerIndex = document.selectedLayerIndex,
              (!document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty) else { return }
        
        // PROTECT LOCKED LAYERS: Don't allow moving objects on locked layers
        if document.layers[layerIndex].isLocked {
            print("🚫 Cannot move objects on locked layer '\(document.layers[layerIndex].name)'")
            return
        }
        
        // PROFESSIONAL OBJECT DRAGGING: Save initial positions (not transforms)
        // This matches the precision approach used by the hand tool
        initialObjectPositions.removeAll()
        
        // Store initial positions for shapes
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                let shape = document.layers[layerIndex].shapes[shapeIndex]
                // Store the actual center position of the shape
                let centerX = shape.bounds.midX
                let centerY = shape.bounds.midY
                initialObjectPositions[shapeID] = CGPoint(x: centerX, y: centerY)
            }
        }
        
        // Store initial positions for text objects
        for textID in document.selectedTextIDs {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                let textObj = document.textObjects[textIndex]
                // Store the text baseline position
                initialObjectPositions[textID] = textObj.position
            }
        }
        
        print("🎯 SELECTION DRAG: Established reference positions for \(document.selectedShapeIDs.count) shapes and \(document.selectedTextIDs.count) text objects")
    }
    
    internal func handleSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let layerIndex = document.selectedLayerIndex,
              (!document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty) else { return }
        
        // PROTECT LOCKED LAYERS: Don't allow moving objects on locked layers
        if document.layers[layerIndex].isLocked {
            return
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
        
        // Move selected shapes by directly updating their path coordinates
        // This ensures the object origin moves with the object (Adobe Illustrator behavior)
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }),
               let initialPosition = initialObjectPositions[shapeID] {
                
                // Calculate new position based on initial position + cursor delta
                let newPosition = CGPoint(
                    x: initialPosition.x + canvasDelta.x,
                    y: initialPosition.y + canvasDelta.y
                )
                
                // Calculate offset needed to move shape to new position
                let currentCenter = CGPoint(
                    x: document.layers[layerIndex].shapes[shapeIndex].bounds.midX,
                    y: document.layers[layerIndex].shapes[shapeIndex].bounds.midY
                )
                
                let offset = CGPoint(
                    x: newPosition.x - currentCenter.x,
                    y: newPosition.y - currentCenter.y
                )
                
                // Apply offset to all path elements
                if abs(offset.x) > 0.01 || abs(offset.y) > 0.01 {
                    var transformedElements: [PathElement] = []
                    
                    for element in document.layers[layerIndex].shapes[shapeIndex].path.elements {
                        switch element {
                        case .move(let to):
                            transformedElements.append(.move(to: VectorPoint(to.x + offset.x, to.y + offset.y)))
                        case .line(let to):
                            transformedElements.append(.line(to: VectorPoint(to.x + offset.x, to.y + offset.y)))
                        case .curve(let to, let control1, let control2):
                            transformedElements.append(.curve(
                                to: VectorPoint(to.x + offset.x, to.y + offset.y),
                                control1: VectorPoint(control1.x + offset.x, control1.y + offset.y),
                                control2: VectorPoint(control2.x + offset.x, control2.y + offset.y)
                            ))
                        case .quadCurve(let to, let control):
                            transformedElements.append(.quadCurve(
                                to: VectorPoint(to.x + offset.x, to.y + offset.y),
                                control: VectorPoint(control.x + offset.x, control.y + offset.y)
                            ))
                        case .close:
                            transformedElements.append(.close)
                        }
                    }
                    
                    // Update the path with transformed coordinates
                    document.layers[layerIndex].shapes[shapeIndex].path = VectorPath(
                        elements: transformedElements,
                        isClosed: document.layers[layerIndex].shapes[shapeIndex].path.isClosed
                    )
                    
                    // Reset transform to identity (no double transformation)
                    document.layers[layerIndex].shapes[shapeIndex].transform = .identity
                    
                    // Update bounds to match new coordinates
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                }
            }
        }
        
        // Move selected text objects by directly updating their position
        for textID in document.selectedTextIDs {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }),
               let initialPosition = initialObjectPositions[textID] {
                
                // Calculate new position based on initial position + cursor delta
                let newPosition = CGPoint(
                    x: initialPosition.x + canvasDelta.x,
                    y: initialPosition.y + canvasDelta.y
                )
                
                // Update text position directly
                document.textObjects[textIndex].position = newPosition
                
                // Update text bounds if needed
                document.textObjects[textIndex].updateBounds()
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    internal func finishSelectionDrag() {
        if !initialObjectPositions.isEmpty {
            // PROFESSIONAL OBJECT DRAGGING: Clean state reset for next drag operation
            // This ensures each new drag operation starts with fresh reference points
            let movedObjects = initialObjectPositions.count
            
            // Save to undo stack if we moved objects
            if movedObjects > 0 {
                document.saveToUndoStack()
            }
            
            // Reset state
            initialObjectPositions.removeAll()
            selectionDragStart = CGPoint.zero
            
            print("🎯 SELECTION DRAG: Completed successfully - moved \(movedObjects) objects")
            print("   State reset - ready for next drag operation")
        }
    }
} 