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
        
        // CRITICAL: Sync unified objects system after state restoration
        syncUnifiedObjectsAfterPropertyChange()
        syncSelectionArrays()
        objectWillChange.send()
        
        Log.info("✅ Undo completed - restored state with \(unifiedObjects.count) unified objects", category: .general)
    }
    
    func redo() {
        guard !redoStack.isEmpty else { return }
        
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
        
        // CRITICAL: Sync unified objects system after state restoration
        syncUnifiedObjectsAfterPropertyChange()
        syncSelectionArrays()
        objectWillChange.send()
        
        Log.info("✅ Redo completed - restored state with \(unifiedObjects.count) unified objects", category: .general)
    }
}