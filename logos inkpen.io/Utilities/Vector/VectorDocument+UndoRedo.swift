//
//  VectorDocument+UndoRedo.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import Combine

// MARK: - Undo/Redo
extension VectorDocument {
    func saveToUndoStack() {
        // Create a copy of the current state
        do {
            let data = try JSONEncoder().encode(self)
            let copy = try JSONDecoder().decode(VectorDocument.self, from: data)
            undoStack.append(copy)

            // Limit undo stack size
            if undoStack.count > maxUndoStackSize {
                undoStack.removeFirst()
            }

            // Clear redo stack when a new action is performed
            redoStack.removeAll()
        } catch {
        }
    }
    
    func undo() {
        guard !undoStack.isEmpty else { return }

        Log.info("⏪ UNDO: Starting - undoStack.count=\(undoStack.count), current selectedTextIDs=\(selectedTextIDs), selectedShapeIDs=\(selectedShapeIDs)", category: .general)

        // Set flag to prevent reordering during undo operation
        isUndoRedoOperation = true
        defer { isUndoRedoOperation = false }

        // Save current state to redo stack
        do {
            let data = try JSONEncoder().encode(self)
            let copy = try JSONDecoder().decode(VectorDocument.self, from: data)
            redoStack.append(copy)
        } catch {
            Log.error("❌ UNDO: Failed to save current state to redo - \(error)", category: .error)
        }

        // Restore previous state
        let previousState = undoStack.removeLast()

        Log.info("⏪ UNDO: Restoring state - previousState selectedTextIDs=\(previousState.selectedTextIDs), selectedShapeIDs=\(previousState.selectedShapeIDs), unifiedObjects.count=\(previousState.unifiedObjects.count)", category: .general)

        settings = previousState.settings
        layers = previousState.layers
        customRgbSwatches = previousState.customRgbSwatches
        customCmykSwatches = previousState.customCmykSwatches
        customHsbSwatches = previousState.customHsbSwatches
        documentColorDefaults = previousState.documentColorDefaults
        selectedLayerIndex = previousState.selectedLayerIndex
        selectedShapeIDs = previousState.selectedShapeIDs
        selectedTextIDs = previousState.selectedTextIDs
        selectedObjectIDs = previousState.selectedObjectIDs

        // Text is now stored in unified system
        unifiedObjects = previousState.unifiedObjects
        currentTool = previousState.currentTool
        zoomLevel = previousState.zoomLevel
        canvasOffset = previousState.canvasOffset
        // REMOVED: View-only properties (showRulers, snapToGrid, showGrid) should NOT be part of undo/redo
        // These are UI preferences, not document content
        gridSpacing = previousState.gridSpacing
        backgroundColor = previousState.backgroundColor
        viewMode = previousState.viewMode
        defaultFillColor = previousState.defaultFillColor
        defaultStrokeColor = previousState.defaultStrokeColor
        defaultFillOpacity = previousState.defaultFillOpacity
        defaultStrokeOpacity = previousState.defaultStrokeOpacity
        defaultStrokeWidth = previousState.defaultStrokeWidth
        defaultStrokePlacement = previousState.defaultStrokePlacement
        defaultStrokeLineJoin = previousState.defaultStrokeLineJoin
        defaultStrokeLineCap = previousState.defaultStrokeLineCap
        defaultStrokeMiterLimit = previousState.defaultStrokeMiterLimit
        activeColorTarget = previousState.activeColorTarget
        colorChangeNotification = previousState.colorChangeNotification
        lastColorChangeType = previousState.lastColorChangeType
        currentBrushThickness = previousState.currentBrushThickness
        // currentBrushPressureSensitivity removed - now using global pressure curve
        // currentBrushTaper removed - tapering is now hardcoded in brush tool
        currentBrushSmoothingTolerance = previousState.currentBrushSmoothingTolerance
        hasPressureInput = previousState.hasPressureInput
        brushApplyNoStroke = previousState.brushApplyNoStroke
        brushRemoveOverlap = previousState.brushRemoveOverlap
        scalingAnchor = previousState.scalingAnchor
        rotationAnchor = previousState.rotationAnchor
        shearAnchor = previousState.shearAnchor
        isHandleScalingActive = previousState.isHandleScalingActive
        zoomRequest = previousState.zoomRequest
        fontManager = previousState.fontManager
        pasteboard = previousState.pasteboard
        layerIndex = previousState.layerIndex
        directSelectedShapeIDs = previousState.directSelectedShapeIDs

        // CRITICAL: Rebuild the lookup cache after restoring unified objects
        rebuildLookupCache()

        // No need to fix ordering - undo restored the exact state that was saved
        // CRITICAL FIX: Sync legacy arrays to ensure consistency
        //syncLegacyArraysAfterUndo()

        // CRITICAL FIX: DON'T MESS WITH SELECTIONS - JUST RESTORE WHAT WAS SAVED!
        // The selection was already restored above (lines 67-69).
        // All this "validation" and "merging" logic is corrupting the restored selection.
        // If the selection was saved properly, it should be restored properly. Period.

        Log.info("⏪ UNDO: Complete - restored selectedTextIDs=\(selectedTextIDs), selectedShapeIDs=\(selectedShapeIDs), unifiedObjects.count=\(unifiedObjects.count)", category: .general)

        objectWillChange.send()
    }
    
    func redo() {
        guard !redoStack.isEmpty else { return }
        
        // Set flag to prevent reordering during redo operation
        isUndoRedoOperation = true
        defer { isUndoRedoOperation = false }
        
        // Save current state to undo stack WITHOUT clearing redo stack
        do {
            let data = try JSONEncoder().encode(self)
            let copy = try JSONDecoder().decode(VectorDocument.self, from: data)
            undoStack.append(copy)
            
            // Limit undo stack size
            if undoStack.count > maxUndoStackSize {
                undoStack.removeFirst()
            }
        } catch {
        }

        // Restore next state (double-check the stack isn't empty)
        guard !redoStack.isEmpty else {
            return
        }
        let nextState = redoStack.removeLast()
        settings = nextState.settings
        layers = nextState.layers
        customRgbSwatches = nextState.customRgbSwatches
        customCmykSwatches = nextState.customCmykSwatches
        customHsbSwatches = nextState.customHsbSwatches
        documentColorDefaults = nextState.documentColorDefaults
        selectedLayerIndex = nextState.selectedLayerIndex
        selectedShapeIDs = nextState.selectedShapeIDs
        selectedTextIDs = nextState.selectedTextIDs
        selectedObjectIDs = nextState.selectedObjectIDs

        // Text is now stored in unified system
        unifiedObjects = nextState.unifiedObjects
        currentTool = nextState.currentTool
        zoomLevel = nextState.zoomLevel
        canvasOffset = nextState.canvasOffset
        // REMOVED: View-only properties (showRulers, snapToGrid, showGrid) should NOT be part of undo/redo
        // These are UI preferences, not document content
        gridSpacing = nextState.gridSpacing
        backgroundColor = nextState.backgroundColor
        viewMode = nextState.viewMode
        defaultFillColor = nextState.defaultFillColor
        defaultStrokeColor = nextState.defaultStrokeColor
        defaultFillOpacity = nextState.defaultFillOpacity
        defaultStrokeOpacity = nextState.defaultStrokeOpacity
        defaultStrokeWidth = nextState.defaultStrokeWidth
        defaultStrokePlacement = nextState.defaultStrokePlacement
        defaultStrokeLineJoin = nextState.defaultStrokeLineJoin
        defaultStrokeLineCap = nextState.defaultStrokeLineCap
        defaultStrokeMiterLimit = nextState.defaultStrokeMiterLimit
        activeColorTarget = nextState.activeColorTarget
        colorChangeNotification = nextState.colorChangeNotification
        lastColorChangeType = nextState.lastColorChangeType
        currentBrushThickness = nextState.currentBrushThickness
        // currentBrushPressureSensitivity removed - now using global pressure curve
        // currentBrushTaper removed - tapering is now hardcoded in brush tool
        currentBrushSmoothingTolerance = nextState.currentBrushSmoothingTolerance
        hasPressureInput = nextState.hasPressureInput
        brushApplyNoStroke = nextState.brushApplyNoStroke
        brushRemoveOverlap = nextState.brushRemoveOverlap
        scalingAnchor = nextState.scalingAnchor
        rotationAnchor = nextState.rotationAnchor
        shearAnchor = nextState.shearAnchor
        isHandleScalingActive = nextState.isHandleScalingActive
        zoomRequest = nextState.zoomRequest
        fontManager = nextState.fontManager
        pasteboard = nextState.pasteboard
        layerIndex = nextState.layerIndex
        directSelectedShapeIDs = nextState.directSelectedShapeIDs
        
        // No need to fix ordering - redo restored the exact state that was saved
        // CRITICAL FIX: Sync legacy arrays to ensure consistency
        //syncLegacyArraysAfterUndo()

        // DON'T CALL syncSelectionArrays() HERE! It clears the selections we just restored!
        // syncSelectionArrays()

        // CRITICAL FIX: Force refresh of text selection state after redo
        // This ensures the Font panel properly recognizes restored text selection
        if !selectedTextIDs.isEmpty {
            // Verify text objects still exist and update their selection state
            let validTextIDs = selectedTextIDs.filter { textID in
                unifiedObjects.contains { obj in
                    if case .shape(let shape) = obj.objectType {
                        return shape.isTextObject && shape.id == textID
                    }
                    return false
                }
            }

            // Update selection to only valid text IDs
            if validTextIDs != selectedTextIDs {
                selectedTextIDs = validTextIDs
            }

            // If we restored text selection and we're in Font mode, ensure proper state
            if !validTextIDs.isEmpty && currentTool == .font {
                // Force the unified selection to be in sync
                selectedObjectIDs = Set(validTextIDs)

                // Clear shape selection when text is selected in Font mode
                selectedShapeIDs.removeAll()
            }
        }

        objectWillChange.send()
    }
    
    /// CRITICAL FIX: Ensures unified objects are properly ordered after undo/redo operations
    /// This function checks if the orderIDs are consistent with the current ordering system
    /// and fixes them if necessary without changing the actual object order
    private func fixUnifiedObjectsOrderingAfterUndo() {
        // Temporarily disable the undo/redo flag to allow this specific operation
        let wasUndoRedoOperation = isUndoRedoOperation
        isUndoRedoOperation = false
        
        defer { isUndoRedoOperation = wasUndoRedoOperation }
   
        // CRITICAL FIX: Special handling for text objects to ensure they maintain their proper order
        fixTextObjectOrderingAfterUndo()
        
        // Check if orderIDs are consistent across all layers
        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard layerObjects.count > 1 else { continue }
            
            // Get the orderIDs for this layer
            let orderIDs = layerObjects.map { $0.orderID }.sorted()
            
            // Check if orderIDs are sequential starting from 0
            let expectedOrderIDs = Array(0..<layerObjects.count)
            
            // CRITICAL FIX: Only fix when orderIDs are actually inconsistent
            // The issue is that orderIDs might be sequential but in wrong order
            let needsFixing = orderIDs != expectedOrderIDs
            
            if needsFixing {
                // CRITICAL: The issue is that the orderIDs are in the wrong order
                // We need to reverse them so that the last created object (which should be on top) gets the highest orderID
                let sortedObjects = layerObjects.sorted { $0.orderID < $1.orderID }
                
                // REVERSE THE ORDER: Last created object gets highest orderID (front), first created gets lowest (back)
                for (arrayIndex, unifiedObject) in sortedObjects.enumerated() {
                    let newOrderID = sortedObjects.count - 1 - arrayIndex // Reverse order: last item gets highest orderID (front)
                    
                    // Find and update the unified object with the correct orderID
                    if let objectIndex = unifiedObjects.firstIndex(where: { $0.id == unifiedObject.id }) {
                        switch unifiedObject.objectType {
                        case .shape(let shape):
                            unifiedObjects[objectIndex] = VectorObject(
                                shape: shape,
                                layerIndex: layerIndex,
                                orderID: newOrderID
                            )
                        // Text handled as VectorShape(let text):
                            unifiedObjects[objectIndex] = VectorObject(
                                shape: shape,
                                layerIndex: layerIndex,
                                orderID: newOrderID
                            )
                        }
                    }
                }
            }
        }

    }
    
    /// CRITICAL FIX: Special handling for text objects to ensure they maintain their proper order during undo/redo
    private func fixTextObjectOrderingAfterUndo() {
    }
    
    /// CRITICAL FIX: Sync legacy arrays after undo/redo operations to ensure consistency
//    private func syncLegacyArraysAfterUndo() {
//        // Temporarily disable the undo/redo flag to allow this specific operation
//        let wasUndoRedoOperation = isUndoRedoOperation
//        isUndoRedoOperation = false
//        isUndoRedoOperation = wasUndoRedoOperation
//    }
}
