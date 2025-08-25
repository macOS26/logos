//
//  VectorDocument+UndoRedo.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics

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
            Log.info("Error saving to undo stack: \(error)", category: .general)
        }
    }
    
    func undo() {
        guard !undoStack.isEmpty else { return }
        
        // Set flag to prevent reordering during undo operation
        isUndoRedoOperation = true
        defer { isUndoRedoOperation = false }
        
        // Save current state to redo stack
        do {
            let data = try JSONEncoder().encode(self)
            let copy = try JSONDecoder().decode(VectorDocument.self, from: data)
            redoStack.append(copy)
        } catch {
            Log.info("Error saving to redo stack: \(error)", category: .general)
        }
        
        // Restore previous state
        let previousState = undoStack.removeLast()
        settings = previousState.settings
        layers = previousState.layers
        rgbSwatches = previousState.rgbSwatches
        cmykSwatches = previousState.cmykSwatches
        hsbSwatches = previousState.hsbSwatches
        selectedLayerIndex = previousState.selectedLayerIndex
        selectedShapeIDs = previousState.selectedShapeIDs
        selectedTextIDs = previousState.selectedTextIDs
        selectedObjectIDs = previousState.selectedObjectIDs
        textObjects = previousState.textObjects
        unifiedObjects = previousState.unifiedObjects
        currentTool = previousState.currentTool
        zoomLevel = previousState.zoomLevel
        canvasOffset = previousState.canvasOffset
        showRulers = previousState.showRulers
        snapToGrid = previousState.snapToGrid
        showGrid = previousState.showGrid
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
        currentBrushPressureSensitivity = previousState.currentBrushPressureSensitivity
        currentBrushTaper = previousState.currentBrushTaper
        currentBrushSmoothingTolerance = previousState.currentBrushSmoothingTolerance
        hasPressureInput = previousState.hasPressureInput
        brushApplyNoStroke = previousState.brushApplyNoStroke
        brushRemoveOverlap = previousState.brushRemoveOverlap
        currentMarkerPressureSensitivity = previousState.currentMarkerPressureSensitivity
        currentMarkerSmoothingTolerance = previousState.currentMarkerSmoothingTolerance
        currentMarkerTipSize = previousState.currentMarkerTipSize
        currentMarkerOpacity = previousState.currentMarkerOpacity
        currentMarkerFeathering = previousState.currentMarkerFeathering
        currentMarkerTaperStart = previousState.currentMarkerTaperStart
        currentMarkerTaperEnd = previousState.currentMarkerTaperEnd
        markerUseFillAsStroke = previousState.markerUseFillAsStroke
        markerApplyNoStroke = previousState.markerApplyNoStroke
        markerRemoveOverlap = previousState.markerRemoveOverlap
        scalingAnchor = previousState.scalingAnchor
        rotationAnchor = previousState.rotationAnchor
        shearAnchor = previousState.shearAnchor
        isHandleScalingActive = previousState.isHandleScalingActive
        zoomRequest = previousState.zoomRequest
        fontManager = previousState.fontManager
        pasteboard = previousState.pasteboard
        layerIndex = previousState.layerIndex
        directSelectedShapeIDs = previousState.directSelectedShapeIDs
        
        // CRITICAL FIX: After restoring state, ensure unified objects are properly ordered
        // but only if the orderIDs are inconsistent with the current ordering system
        fixUnifiedObjectsOrderingAfterUndo()
        
        // CRITICAL FIX: Sync legacy arrays to ensure consistency
        syncLegacyArraysAfterUndo()
        
        syncSelectionArrays()
        objectWillChange.send()
        
        Log.info("✅ Undo completed - restored state with \(unifiedObjects.count) unified objects", category: .general)
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
            Log.info("Error saving to undo stack: \(error)", category: .general)
        }
        
        // Restore next state (double-check the stack isn't empty)
        guard !redoStack.isEmpty else { 
            Log.info("Warning: Redo stack became empty during redo operation", category: .general)
            return 
        }
        let nextState = redoStack.removeLast()
        settings = nextState.settings
        layers = nextState.layers
        rgbSwatches = nextState.rgbSwatches
        cmykSwatches = nextState.cmykSwatches
        hsbSwatches = nextState.hsbSwatches
        selectedLayerIndex = nextState.selectedLayerIndex
        selectedShapeIDs = nextState.selectedShapeIDs
        selectedTextIDs = nextState.selectedTextIDs
        selectedObjectIDs = nextState.selectedObjectIDs
        textObjects = nextState.textObjects
        unifiedObjects = nextState.unifiedObjects
        currentTool = nextState.currentTool
        zoomLevel = nextState.zoomLevel
        canvasOffset = nextState.canvasOffset
        showRulers = nextState.showRulers
        snapToGrid = nextState.snapToGrid
        showGrid = nextState.showGrid
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
        currentBrushPressureSensitivity = nextState.currentBrushPressureSensitivity
        currentBrushTaper = nextState.currentBrushTaper
        currentBrushSmoothingTolerance = nextState.currentBrushSmoothingTolerance
        hasPressureInput = nextState.hasPressureInput
        brushApplyNoStroke = nextState.brushApplyNoStroke
        brushRemoveOverlap = nextState.brushRemoveOverlap
        currentMarkerPressureSensitivity = nextState.currentMarkerPressureSensitivity
        currentMarkerSmoothingTolerance = nextState.currentMarkerSmoothingTolerance
        currentMarkerTipSize = nextState.currentMarkerTipSize
        currentMarkerOpacity = nextState.currentMarkerOpacity
        currentMarkerFeathering = nextState.currentMarkerFeathering
        currentMarkerTaperStart = nextState.currentMarkerTaperStart
        currentMarkerTaperEnd = nextState.currentMarkerTaperEnd
        markerUseFillAsStroke = nextState.markerUseFillAsStroke
        markerApplyNoStroke = nextState.markerApplyNoStroke
        markerRemoveOverlap = nextState.markerRemoveOverlap
        scalingAnchor = nextState.scalingAnchor
        rotationAnchor = nextState.rotationAnchor
        shearAnchor = nextState.shearAnchor
        isHandleScalingActive = nextState.isHandleScalingActive
        zoomRequest = nextState.zoomRequest
        fontManager = nextState.fontManager
        pasteboard = nextState.pasteboard
        layerIndex = nextState.layerIndex
        directSelectedShapeIDs = nextState.directSelectedShapeIDs
        
        // CRITICAL FIX: After restoring state, ensure unified objects are properly ordered
        // but only if the orderIDs are inconsistent with the current ordering system
        fixUnifiedObjectsOrderingAfterUndo()
        
        // CRITICAL FIX: Sync legacy arrays to ensure consistency
        syncLegacyArraysAfterUndo()
        
        syncSelectionArrays()
        objectWillChange.send()
        
        Log.info("✅ Redo completed - restored state with \(unifiedObjects.count) unified objects", category: .general)
    }
    
    /// CRITICAL FIX: Ensures unified objects are properly ordered after undo/redo operations
    /// This function checks if the orderIDs are consistent with the current ordering system
    /// and fixes them if necessary without changing the actual object order
    private func fixUnifiedObjectsOrderingAfterUndo() {
        // Temporarily disable the undo/redo flag to allow this specific operation
        let wasUndoRedoOperation = isUndoRedoOperation
        isUndoRedoOperation = false
        
        defer { isUndoRedoOperation = wasUndoRedoOperation }
        
        // Debug: Log the current order state
        logCurrentOrderState("BEFORE FIX")
        
        // Check if orderIDs are consistent across all layers
        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard layerObjects.count > 1 else { continue }
            
            // Get the orderIDs for this layer
            let orderIDs = layerObjects.map { $0.orderID }.sorted()
            
            // Check if orderIDs are sequential starting from 0
            let expectedOrderIDs = Array(0..<layerObjects.count)
            
            // CRITICAL FIX: Always fix the stacking order to ensure visual consistency
            // The issue is that orderIDs might be sequential but in wrong order
            let needsFixing = orderIDs != expectedOrderIDs || layerObjects.count > 1
            
            if needsFixing {
                Log.info("🔧 UNDO FIX: OrderIDs inconsistent for layer \(layerIndex), fixing...", category: .general)
                Log.info("  Current orderIDs: \(orderIDs)", category: .general)
                Log.info("  Expected orderIDs: \(expectedOrderIDs)", category: .general)
                
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
                        case .text(let text):
                            unifiedObjects[objectIndex] = VectorObject(
                                text: text,
                                layerIndex: layerIndex,
                                orderID: newOrderID
                            )
                        }
                    }
                }
                
                Log.info("🔧 UNDO FIX: Fixed orderIDs for layer \(layerIndex) - maintained visual order", category: .general)
            }
        }
        
        // Debug: Log the order state after fixing
        logCurrentOrderState("AFTER FIX")
    }
    
    /// Debug function to log the current order state
    private func logCurrentOrderState(_ stage: String) {
        Log.info("🔍 ORDER DEBUG [\(stage)]: Unified objects order state", category: .general)
        
        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }
            
            let sortedObjects = layerObjects.sorted { $0.orderID < $1.orderID }
            let orderIDs = sortedObjects.map { $0.orderID }
            
            Log.info("  Layer \(layerIndex) (\(layers[layerIndex].name)): orderIDs=\(orderIDs)", category: .general)
            
            for (index, unifiedObject) in sortedObjects.enumerated() {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    Log.info("    [\(index)] orderID=\(unifiedObject.orderID) - Shape: \(shape.name)", category: .general)
                case .text(let text):
                    Log.info("    [\(index)] orderID=\(unifiedObject.orderID) - Text: \(text.content.prefix(20))", category: .general)
                }
            }
        }
    }
    
    /// CRITICAL FIX: Sync legacy arrays after undo/redo operations to ensure consistency
    private func syncLegacyArraysAfterUndo() {
        // Temporarily disable the undo/redo flag to allow this specific operation
        let wasUndoRedoOperation = isUndoRedoOperation
        isUndoRedoOperation = false
        
        defer { isUndoRedoOperation = wasUndoRedoOperation }
        
        // CRITICAL FIX: Preserve original objects before clearing arrays to maintain state
        let originalTextObjects = textObjects
        let originalShapes = layers.map { $0.shapes }
        
        // Clear existing legacy arrays
        for layerIndex in layers.indices {
            layers[layerIndex].shapes.removeAll()
        }
        textObjects.removeAll()
        
        // Rebuild legacy arrays from unified objects, maintaining order
        for unifiedObject in unifiedObjects.sorted(by: { $0.orderID < $1.orderID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                // Use original shape from layers array to preserve all state
                if let originalShape = originalShapes[unifiedObject.layerIndex].first(where: { $0.id == shape.id }) {
                    layers[unifiedObject.layerIndex].shapes.append(originalShape)
                } else {
                    layers[unifiedObject.layerIndex].shapes.append(shape)
                }
            case .text(let text):
                // Use original text object to preserve all state, but ensure isEditing = false
                if let originalText = originalTextObjects.first(where: { $0.id == text.id }) {
                    var updatedText = originalText
                    updatedText.isEditing = false
                    textObjects.append(updatedText)
                } else {
                    var updatedText = text
                    updatedText.isEditing = false
                    textObjects.append(updatedText)
                }
            }
        }
        
        Log.info("🔧 UNDO SYNC: Legacy arrays synced from unified objects", category: .general)
    }
}