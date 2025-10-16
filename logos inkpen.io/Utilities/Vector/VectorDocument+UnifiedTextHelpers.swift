import SwiftUI

extension VectorDocument {

    func lockTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isLocked = true

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func unlockTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isLocked = false

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func hideTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isVisible = false

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func showTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isVisible = true

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func updateTextFillOpacityInUnified(id: UUID, opacity: Double) {
        updateShapeByID(id) { shape in
            shape.typography?.fillOpacity = opacity
        }
    }

    func updateTextStrokeWidthInUnified(id: UUID, width: Double) {
        updateShapeByID(id) { shape in
            shape.typography?.strokeWidth = width
            shape.typography?.hasStroke = width > 0
        }
    }

    func translateTextInUnified(id: UUID, delta: CGPoint) {
        updateShapeByID(id) { shape in
            shape.transform.tx += delta.x
            shape.transform.ty += delta.y

            if let textPos = shape.textPosition {
                shape.textPosition = CGPoint(x: textPos.x + delta.x, y: textPos.y + delta.y)
            }
        }
    }

    func translateAllTextInUnified(delta: CGPoint) {
        let textIDs = unifiedObjects.compactMap { obj -> UUID? in
            if case .shape(let shape) = obj.objectType, shape.isTextObject {
                return shape.id
            }
            return nil
        }

        for textID in textIDs {
            translateTextInUnified(id: textID, delta: delta)
        }
    }

    func setTextEditingInUnified(id: UUID, isEditing: Bool) {
        updateShapeByID(id) { shape in
            shape.isEditing = isEditing
        }
    }

    func updateTextLayerInUnified(id: UUID, layerIndex: Int) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            let existingObject = unifiedObjects[objectIndex]
            if case .shape(let shape) = existingObject.objectType {

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex,
                )

                syncShapeToLayer(shape, at: layerIndex)
            }
        }
    }
}
