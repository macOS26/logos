//
//  DrawingCanvas+DirectSelectionDrag.swift
//  logos inkpen.io
//
//  Direct selection drag functionality
//

import SwiftUI

extension DrawingCanvas {
    // MARK: - Direct Selection Drag Handling
    internal func handleDirectSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
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
        for pointID in selectedPoints {
            // Find which layer this point belongs to
            for layerIndex in document.layers.indices {
                if let _ = document.layers[layerIndex].shapes.first(where: { $0.id == pointID.shapeID }) {
                    if document.layers[layerIndex].isLocked {
                        Log.info("🚫 Cannot edit points on locked layer '\(document.layers[layerIndex].name)'", category: .general)
                        return
                    }
                    break
                }
            }
        }
        
        for handleID in selectedHandles {
            // Find which layer this handle belongs to
            for layerIndex in document.layers.indices {
                if let _ = document.layers[layerIndex].shapes.first(where: { $0.id == handleID.shapeID }) {
                    if document.layers[layerIndex].isLocked {
                        Log.info("🚫 Cannot edit handles on locked layer '\(document.layers[layerIndex].name)'", category: .general)
                        return
                    }
                    break
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
        
        // Move selected points to absolute positions
        for pointID in selectedPoints {
            if let originalPosition = originalPointPositions[pointID] {
                movePointToAbsolutePosition(pointID, to: CGPoint(
                    x: originalPosition.x + delta.x,
                    y: originalPosition.y + delta.y
                ))
            }
        }
        
        // Move selected handles to absolute positions
        for handleID in selectedHandles {
            if let originalPosition = originalHandlePositions[handleID] {
                moveHandleToAbsolutePosition(handleID, to: CGPoint(
                    x: originalPosition.x + delta.x,
                    y: originalPosition.y + delta.y
                ))
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    internal func finishDirectSelectionDrag() {
        isDraggingPoint = false
        isDraggingHandle = false
        originalPointPositions.removeAll()
        originalHandlePositions.removeAll()
    }
} 