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
        
        // CRITICAL FIX: Save to undo stack BEFORE making any changes
        document.saveToUndoStack()
        
        // PROFESSIONAL OBJECT DRAGGING: Save initial positions (not transforms)
        // This matches the precision approach used by the hand tool
        initialObjectPositions.removeAll()
        
        // Store initial positions for shapes
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                let shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // GROUP POSITION FIX: Use appropriate bounds for groups vs individual shapes
                // FLATTENED SHAPE FIX: Use actual path bounds for flattened shapes, not group bounds (CONSISTENT WITH SCALE TOOL)
                let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
                let centerX = bounds.midX
                let centerY = bounds.midY
                initialObjectPositions[shapeID] = CGPoint(x: centerX, y: centerY)
                
                print("🎯 DRAG INIT: Shape '\(shape.name)' (\(shape.isGroupContainer ? "GROUP" : "INDIVIDUAL")) center: (\(String(format: "%.1f", centerX)), \(String(format: "%.1f", centerY)))")
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
                
                let shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // GROUP MOVEMENT FIX: Handle groups EXACTLY like individual shapes
                if shape.isGroupContainer {
                    // For groups, move each grouped shape's coordinates directly (same as individual shapes)
                    let newPosition = CGPoint(
                        x: initialPosition.x + canvasDelta.x,
                        y: initialPosition.y + canvasDelta.y
                    )
                    
                    // Calculate offset needed to move group to new position
                    let currentCenter = CGPoint(
                        x: shape.groupBounds.midX,
                        y: shape.groupBounds.midY
                    )
                    
                    let offset = CGPoint(
                        x: newPosition.x - currentCenter.x,
                        y: newPosition.y - currentCenter.y
                    )
                    
                    // CRITICAL FIX: Move each grouped shape's path coordinates directly
                    if abs(offset.x) > 0.01 || abs(offset.y) > 0.01 {
                        var updatedGroupedShapes: [VectorShape] = []
                        
                        for var groupedShape in shape.groupedShapes {
                            // Apply offset to all path elements in each grouped shape
                            var transformedElements: [PathElement] = []
                            
                            for element in groupedShape.path.elements {
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
                            
                            // Update the grouped shape's path with transformed coordinates
                            groupedShape.path = VectorPath(
                                elements: transformedElements,
                                isClosed: groupedShape.path.isClosed
                            )
                            
                            // Reset individual shape transform to identity (no double transformation)
                            groupedShape.transform = .identity
                            
                            // Update bounds to match new coordinates
                            groupedShape.updateBounds()
                            
                            updatedGroupedShapes.append(groupedShape)
                        }
                        
                        // Update the group with the moved shapes
                        document.layers[layerIndex].shapes[shapeIndex].groupedShapes = updatedGroupedShapes
                        
                        // Reset group transform to identity (no double transformation)
                        document.layers[layerIndex].shapes[shapeIndex].transform = .identity
                        
                        // WARP OBJECT FIX: Update warp envelope coordinates when moving warp objects
                        if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
                            var updatedWarpEnvelope: [CGPoint] = []
                            for envelopePoint in shape.warpEnvelope {
                                updatedWarpEnvelope.append(CGPoint(
                                    x: envelopePoint.x + offset.x,
                                    y: envelopePoint.y + offset.y
                                ))
                            }
                            document.layers[layerIndex].shapes[shapeIndex].warpEnvelope = updatedWarpEnvelope
                            print("📐 WARP ENVELOPE MOVED: Updated envelope coordinates by offset (\(String(format: "%.1f", offset.x)), \(String(format: "%.1f", offset.y)))")
                        }
                        
                        // Update group bounds
                        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    }
                    
                    print("📦 GROUP COORDINATE DRAG: Moving group '\(shape.name)' by coordinate offset (\(String(format: "%.1f", offset.x)), \(String(format: "%.1f", offset.y)))")
                    
                } else {
                    // For individual shapes, use path coordinate modification (existing logic)
                    // Calculate new position based on initial position + cursor delta
                    let newPosition = CGPoint(
                        x: initialPosition.x + canvasDelta.x,
                        y: initialPosition.y + canvasDelta.y
                    )
                    
                    // Calculate offset needed to move shape to new position
                    let currentCenter = CGPoint(
                        x: shape.bounds.midX,
                        y: shape.bounds.midY
                    )
                    
                    let offset = CGPoint(
                        x: newPosition.x - currentCenter.x,
                        y: newPosition.y - currentCenter.y
                    )
                    
                    // Apply offset to all path elements
                    if abs(offset.x) > 0.01 || abs(offset.y) > 0.01 {
                        var transformedElements: [PathElement] = []
                        
                        for element in shape.path.elements {
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
                            isClosed: shape.path.isClosed
                        )
                        
                        // Reset transform to identity (no double transformation)
                        document.layers[layerIndex].shapes[shapeIndex].transform = .identity
                        
                        // WARP OBJECT FIX: Update warp envelope coordinates when moving warp objects
                        if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
                            var updatedWarpEnvelope: [CGPoint] = []
                            for envelopePoint in shape.warpEnvelope {
                                updatedWarpEnvelope.append(CGPoint(
                                    x: envelopePoint.x + offset.x,
                                    y: envelopePoint.y + offset.y
                                ))
                            }
                            document.layers[layerIndex].shapes[shapeIndex].warpEnvelope = updatedWarpEnvelope
                            print("📐 WARP ENVELOPE MOVED: Updated envelope coordinates by offset (\(String(format: "%.1f", offset.x)), \(String(format: "%.1f", offset.y)))")
                        }
                        
                        // Update bounds to match new coordinates
                        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    }
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
        // CRITICAL FIX: Don't apply selection drag if handle scaling was active
        if document.isHandleScalingActive {
            // Reset state without applying any transforms
            initialObjectPositions.removeAll()
            selectionDragStart = CGPoint.zero
            print("🎯 SELECTION DRAG: CANCELLED - Handle scaling was active, no transforms applied")
            return
        }
        
        if !initialObjectPositions.isEmpty {
            // PROFESSIONAL OBJECT DRAGGING: Clean state reset for next drag operation
            // This ensures each new drag operation starts with fresh reference points
            let movedObjects = initialObjectPositions.count
            
            // REMOVED: saveToUndoStack() - now called at START of drag operation, not end
            
            // Reset state
            initialObjectPositions.removeAll()
            selectionDragStart = CGPoint.zero
            
            print("🎯 SELECTION DRAG: Completed successfully - moved \(movedObjects) objects")
            print("   State reset - ready for next drag operation")
        }
    }
} 