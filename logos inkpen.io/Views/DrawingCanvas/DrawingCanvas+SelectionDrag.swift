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
        
        // PERFORMANCE FIX: Use transform-based movement during drag instead of expensive coordinate recalculation
        // Only recalculate coordinates at the end when drag finishes
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                
                // Create translation transform from canvas delta
                let translationTransform = CGAffineTransform.identity.translatedBy(x: canvasDelta.x, y: canvasDelta.y)
                
                // Apply translation to shape's transform (much faster than coordinate recalculation)
                document.layers[layerIndex].shapes[shapeIndex].transform = translationTransform
                
                // Reduce logging frequency for better performance during drag
                #if DEBUG
                if abs(canvasDelta.x) > 5 || abs(canvasDelta.y) > 5 { // Only log every 5 points of movement
                    print("🚀 FAST DRAG: Shape '\(document.layers[layerIndex].shapes[shapeIndex].name)' moved by transform (\(String(format: "%.1f", canvasDelta.x)), \(String(format: "%.1f", canvasDelta.y)))")
                }
                #endif
            }
        }
        
        // Move selected text objects with same efficient approach
        for textID in document.selectedTextIDs {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }),
               let initialPosition = initialObjectPositions[textID] {
                
                // For text, we can directly update position (simpler than shapes)
                let newPosition = CGPoint(
                    x: initialPosition.x + canvasDelta.x,
                    y: initialPosition.y + canvasDelta.y
                )
                document.textObjects[textIndex].position = newPosition
            }
        }
        
        // Only trigger one UI update per frame instead of multiple updates
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
            // PERFORMANCE FIX: Apply transforms to actual coordinates at the end of drag
            // This ensures smooth 60fps movement during drag, then commits changes once
            guard let layerIndex = document.selectedLayerIndex else { return }
            
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    let shape = document.layers[layerIndex].shapes[shapeIndex]
                    
                    // Only apply if there's actually a transform to apply
                    if !shape.transform.isIdentity {
                        print("🎯 FINALIZING: Converting transform to coordinates for '\(shape.name)'")
                        applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex)
                    }
                }
            }
            
            // PROFESSIONAL OBJECT DRAGGING: Clean state reset for next drag operation
            // This ensures each new drag operation starts with fresh reference points
            let movedObjects = initialObjectPositions.count
            
            // Reset state
            initialObjectPositions.removeAll()
            selectionDragStart = CGPoint.zero
            
            print("🎯 SELECTION DRAG: Completed successfully - moved \(movedObjects) objects")
            print("   State reset - ready for next drag operation")
        }
    }
    
    /// PERFORMANCE OPTIMIZED: Apply transform to actual coordinates (only called at end of drag)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let transform = shape.transform
        
        // Don't apply identity transforms
        if transform.isIdentity {
            return
        }
        
        print("🔧 Applying transform to shape coordinates: \(shape.name)")
        
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
            document.layers[layerIndex].shapes[shapeIndex].groupedShapes = transformedGroupedShapes
            document.layers[layerIndex].shapes[shapeIndex].transform = .identity
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("✅ Flattened group coordinates updated - transformed \(transformedGroupedShapes.count) individual shapes")
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
        document.layers[layerIndex].shapes[shapeIndex].path = transformedPath
        document.layers[layerIndex].shapes[shapeIndex].transform = .identity
        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
        
        print("✅ Shape coordinates updated after movement - object origin stays with object")
    }
} 