//
//  DrawingCanvas+DirectSelectionDrag.swift
//  logos inkpen.io
//
//  Direct selection drag functionality
//

import SwiftUI
import Combine
extension DrawingCanvas {
    // MARK: - Direct Selection Drag Handling
    internal func handleDirectSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        // Check if we should drag entire direct-selected shapes (when no points/handles selected)
        if selectedPoints.isEmpty && selectedHandles.isEmpty && !directSelectedShapeIDs.isEmpty {
            // WHOLE SHAPE DRAGGING: When shapes are direct-selected but no individual points
            // This allows moving entire shapes in direct selection mode with snapping
            handleDirectSelectionShapeDrag(value: value, geometry: geometry)
            return
        }

        // IMPROVED: Enable immediate click-and-drag without prior selection
        // If nothing is selected, try to auto-select at the drag start location
        if selectedPoints.isEmpty && selectedHandles.isEmpty && !isDraggingPoint && !isDraggingHandle {
            let canvasLocation = screenToCanvas(value.startLocation, geometry: geometry)
            let screenTolerance: Double = 15.0
            let tolerance: Double = screenTolerance / document.zoomLevel

            Log.fileOperation("🎯 IMMEDIATE DRAG: Attempting auto-selection at start location \(canvasLocation)", level: .info)

            // Try to auto-select a point or handle at the drag start location
            var foundPointOrHandle = false

            // Check all direct-selected shapes first
            if !directSelectedShapeIDs.isEmpty {
                foundPointOrHandle = selectIndividualAnchorPointOrHandle(at: canvasLocation, tolerance: tolerance)
            }

            // If no direct-selected shapes, try to direct-select a shape and then select a point/handle
            if !foundPointOrHandle {
                if directSelectWholeShape(at: canvasLocation) {
                    // Shape was direct-selected, now try to select a point/handle on it
                    foundPointOrHandle = selectIndividualAnchorPointOrHandle(at: canvasLocation, tolerance: tolerance)

                    // If still no point/handle found, drag the whole shape
                    if !foundPointOrHandle && !directSelectedShapeIDs.isEmpty {
                        handleDirectSelectionShapeDrag(value: value, geometry: geometry)
                        return
                    }
                }
            }

            if !foundPointOrHandle {
                Log.fileOperation("🎯 IMMEDIATE DRAG: No point or handle found at drag start - early return", level: .info)
                return
            }

            Log.fileOperation("🎯 IMMEDIATE DRAG: Auto-selected for dragging", level: .info)
        }

        // Now proceed with normal drag logic (points/handles should be selected)
        guard !selectedPoints.isEmpty || !selectedHandles.isEmpty else { return }
        
        // PROTECT LOCKED LAYERS: Don't allow editing points/handles on locked layers
        // PERFORMANCE: Use O(1) UUID lookup instead of searching all layers
        for pointID in selectedPoints {
            if let unifiedObject = document.findObject(by: pointID.shapeID) {
                let layerIndex = unifiedObject.layerIndex
                if document.layers[layerIndex].isLocked {
                    // Log.info("🚫 Cannot edit points on locked layer '\(document.layers[layerIndex].name)'", category: .general)
                    return
                }
            }
        }

        for handleID in selectedHandles {
            if let unifiedObject = document.findObject(by: handleID.shapeID) {
                let layerIndex = unifiedObject.layerIndex
                if document.layers[layerIndex].isLocked {
                    // Log.info("🚫 Cannot edit handles on locked layer '\(document.layers[layerIndex].name)'", category: .general)
                    return
                }
            }
        }
        
        if !isDraggingPoint && !isDraggingHandle {
            // Start dragging - capture initial positions
            isDraggingPoint = !selectedPoints.isEmpty
            isDraggingHandle = !selectedHandles.isEmpty
            document.saveToUndoStack() // Save state before modifying paths
            
            // Store initial positions for accurate dragging
            captureOriginalPositions()
        }
        
        // STABLE COORDINATE CALCULATION: Use high precision to prevent drift
        let preciseZoom = Double(document.zoomLevel)
        let preciseTranslationX = Double(value.translation.width)
        let preciseTranslationY = Double(value.translation.height)
        
        let delta = CGPoint(
            x: preciseTranslationX / preciseZoom,
            y: preciseTranslationY / preciseZoom
        )
        
        // Batch all point and handle movements to reduce updates
        // Move selected points to absolute positions WITHOUT triggering individual updates

        // For snapping, we need to find the primary dragged point and snap it,
        // then apply the same offset to other selected points
        var snappedDelta = delta

        if (document.snapToPoint || document.snapToGrid) && !selectedPoints.isEmpty {
            // Use the first selected point as the reference for snapping
            if let firstPointID = selectedPoints.first,
               let originalPosition = originalPointPositions[firstPointID] {
                let unsnappedPosition = CGPoint(
                    x: originalPosition.x + delta.x,
                    y: originalPosition.y + delta.y
                )
                let snappedPosition = applySnapping(to: unsnappedPosition)

                // Calculate the snapped delta based on the difference
                snappedDelta = CGPoint(
                    x: snappedPosition.x - originalPosition.x,
                    y: snappedPosition.y - originalPosition.y
                )
            }
        }

        // Now move all points with the snapped delta
        for pointID in selectedPoints {
            if let originalPosition = originalPointPositions[pointID] {
                movePointToAbsolutePositionBatched(pointID, to: CGPoint(
                    x: originalPosition.x + snappedDelta.x,
                    y: originalPosition.y + snappedDelta.y
                ))
            }
        }

        // Move selected handles to absolute positions WITHOUT triggering individual updates
        // Note: Handles typically don't snap to grid/points to maintain curve control
        for handleID in selectedHandles {
            if let originalPosition = originalHandlePositions[handleID] {
                moveHandleToAbsolutePositionBatched(handleID, to: CGPoint(
                    x: originalPosition.x + delta.x,
                    y: originalPosition.y + delta.y
                ))
            }
        }

        // Single UI update after all movements are complete
        document.objectWillChange.send()
    }
    
    // MARK: - Direct Selection Shape Drag (Whole Shapes)

    private func handleDirectSelectionShapeDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        // Convert selected shape IDs to document selection for reusing selection drag logic
        if !isDraggingDirectSelectedShapes {
            // Initialize drag for direct-selected shapes
            isDraggingDirectSelectedShapes = true

            // Convert direct selected shapes to regular selection temporarily
            document.selectedObjectIDs = directSelectedShapeIDs

            // Start the selection drag using existing logic
            startSelectionDrag()
            selectionDragStart = value.startLocation
        }

        // Reuse the existing selection drag logic which already has snap to grid
        handleSelectionDrag(value: value, geometry: geometry)
    }

    internal func finishDirectSelectionDrag() {
        // Handle whole shape dragging cleanup
        if isDraggingDirectSelectedShapes {
            finishSelectionDrag()
            isDraggingDirectSelectedShapes = false

            // Restore direct selection state
            document.selectedObjectIDs.removeAll()
            return
        }

        isDraggingPoint = false
        isDraggingHandle = false
        originalPointPositions.removeAll()
        originalHandlePositions.removeAll()
        
        // Update bounds for all modified shapes now that dragging is complete
        for pointID in selectedPoints {
            for layerIndex in document.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if let shapeIndex = shapes.firstIndex(where: { $0.id == pointID.shapeID }),
                   let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                    var updatedShape = shape
                    updatedShape.updateBounds()
                    document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                    break
                }
            }
        }
        for handleID in selectedHandles {
            for layerIndex in document.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if let shapeIndex = shapes.firstIndex(where: { $0.id == handleID.shapeID }),
                   let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                    var updatedShape = shape
                    updatedShape.updateBounds()
                    document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                    break
                }
            }
        }
        
        // Perform expensive sync operations now that dragging is complete
        // No need to send update here since we'll send it immediately after
        document.updateUnifiedObjectsOptimized(sendUpdate: false)

        // Force UI update once at the end of drag operation
        document.objectWillChange.send()
    }
} 
