import SwiftUI
import Combine

extension VectorDocument {
    func saveToUndoStack() {
        do {
            let data = try JSONEncoder().encode(self)
            let copy = try JSONDecoder().decode(VectorDocument.self, from: data)
            undoStack.append(copy)

            if undoStack.count > maxUndoStackSize {
                undoStack.removeFirst()
            }

            redoStack.removeAll()
        } catch {
        }
    }

    func undo() {
        guard !undoStack.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(self)
            let copy = try JSONDecoder().decode(VectorDocument.self, from: data)
            redoStack.append(copy)
        } catch {
            Log.error("❌ UNDO: Failed to save current state to redo - \(error)", category: .error)
        }

        let previousState = undoStack.removeLast()

        isUndoRedoOperation = true

        var transaction = Transaction()
        transaction.disablesAnimations = true
        transaction.animation = nil

        withTransaction(transaction) {
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

            unifiedObjects = previousState.unifiedObjects
            currentTool = previousState.currentTool
            zoomLevel = previousState.zoomLevel
            canvasOffset = previousState.canvasOffset
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
            warpEnvelopeCorners = previousState.warpEnvelopeCorners
            warpBounds = previousState.warpBounds

            rebuildLookupCache()
        }

        isUndoRedoOperation = false
        objectWillChange.send()
    }

    func redo() {
        guard !redoStack.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(self)
            let copy = try JSONDecoder().decode(VectorDocument.self, from: data)
            undoStack.append(copy)

            if undoStack.count > maxUndoStackSize {
                undoStack.removeFirst()
            }
        } catch {
        }

        guard !redoStack.isEmpty else {
            return
        }
        let nextState = redoStack.removeLast()

        isUndoRedoOperation = true

        var transaction = Transaction()
        transaction.disablesAnimations = true
        transaction.animation = nil

        withTransaction(transaction) {
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

            unifiedObjects = nextState.unifiedObjects
            currentTool = nextState.currentTool
            zoomLevel = nextState.zoomLevel
            canvasOffset = nextState.canvasOffset
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
            warpEnvelopeCorners = nextState.warpEnvelopeCorners
            warpBounds = nextState.warpBounds

            rebuildLookupCache()
        }

        isUndoRedoOperation = false
        objectWillChange.send()
    }

    private func fixUnifiedObjectsOrderingAfterUndo() {
        let wasUndoRedoOperation = isUndoRedoOperation
        isUndoRedoOperation = false

        defer { isUndoRedoOperation = wasUndoRedoOperation }

        fixTextObjectOrderingAfterUndo()

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard layerObjects.count > 1 else { continue }

            let orderIDs = layerObjects.map { $0.orderID }.sorted()

            let expectedOrderIDs = Array(0..<layerObjects.count)

            let needsFixing = orderIDs != expectedOrderIDs

            if needsFixing {
                let sortedObjects = layerObjects.sorted { $0.orderID < $1.orderID }

                for (arrayIndex, unifiedObject) in sortedObjects.enumerated() {
                    let newOrderID = sortedObjects.count - 1 - arrayIndex

                    if let objectIndex = unifiedObjects.firstIndex(where: { $0.id == unifiedObject.id }) {
                        switch unifiedObject.objectType {
                        case .shape(let shape):
                            unifiedObjects[objectIndex] = VectorObject(
                                shape: shape,
                                layerIndex: layerIndex,
                                orderID: newOrderID
                            )
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

    private func fixTextObjectOrderingAfterUndo() {
    }

}
