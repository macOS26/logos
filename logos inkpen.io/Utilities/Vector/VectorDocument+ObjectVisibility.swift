
import SwiftUI

extension VectorDocument {


    func lockSelectedObjects() {
        guard !selectedShapeIDs.isEmpty || !selectedTextIDs.isEmpty else { return }

        saveToUndoStack()

        for layerIndex in layers.indices {
            let shapes = getShapesForLayer(layerIndex)
            for (shapeIndex, shape) in shapes.enumerated() {
                if selectedShapeIDs.contains(shape.id) {
                    var updatedShape = shape
                    updatedShape.isLocked = true
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                }
            }
        }

        for textID in selectedTextIDs {
            lockTextInUnified(id: textID)
        }


        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()
    }

    func unlockAllObjects() {
        guard let layerIndex = selectedLayerIndex else { return }

        saveToUndoStack()

        var unlockedCount = 0

        let shapes = getShapesForLayer(layerIndex)
        for (shapeIndex, shape) in shapes.enumerated() {
            if shape.isLocked {
                var updatedShape = shape
                updatedShape.isLocked = false
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                unlockedCount += 1
            }
        }

        for unifiedObj in unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject, shape.isLocked == true {
                unlockTextInUnified(id: shape.id)
                unlockedCount += 1
            }
        }

    }


    func hideSelectedObjects() {
        guard !selectedShapeIDs.isEmpty || !selectedTextIDs.isEmpty else { return }

        saveToUndoStack()

        for layerIndex in layers.indices {
            let shapes = getShapesForLayer(layerIndex)
            for (shapeIndex, shape) in shapes.enumerated() {
                if selectedShapeIDs.contains(shape.id) {
                    var updatedShape = shape
                    updatedShape.isVisible = false
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                }
            }
        }

        for textID in selectedTextIDs {
            hideTextInUnified(id: textID)
        }


        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()
    }

    func showAllObjects() {
        guard let layerIndex = selectedLayerIndex else { return }

        saveToUndoStack()

        var shownCount = 0

        let shapes = getShapesForLayer(layerIndex)
        for (shapeIndex, shape) in shapes.enumerated() {
            if !shape.isVisible {
                var updatedShape = shape
                updatedShape.isVisible = true
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                shownCount += 1
            }
        }

        for unifiedObj in unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject, shape.isVisible == false {
                showTextInUnified(id: shape.id)
                shownCount += 1
            }
        }

    }
}
