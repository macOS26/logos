import SwiftUI

extension VectorDocument {

    func lockTextInUnified(id: UUID) {
        if let obj = snapshot.objects[id],
           case .text(var shape) = obj.objectType {
            shape.isLocked = true

            let updatedObject = VectorObject(
                id: shape.id,
                layerIndex: obj.layerIndex,
                objectType: .text(shape)
            )
            snapshot.objects[id] = updatedObject
        }
    }

    func unlockTextInUnified(id: UUID) {
        if let obj = snapshot.objects[id],
           case .text(var shape) = obj.objectType {
            shape.isLocked = false

            let updatedObject = VectorObject(
                id: shape.id,
                layerIndex: obj.layerIndex,
                objectType: .text(shape)
            )
            snapshot.objects[id] = updatedObject
        }
    }

    func hideTextInUnified(id: UUID) {
        if let obj = snapshot.objects[id],
           case .text(var shape) = obj.objectType {
            shape.isVisible = false

            let updatedObject = VectorObject(
                id: shape.id,
                layerIndex: obj.layerIndex,
                objectType: .text(shape)
            )
            snapshot.objects[id] = updatedObject
        }
    }

    func showTextInUnified(id: UUID) {
        if let obj = snapshot.objects[id],
           case .text(var shape) = obj.objectType {
            shape.isVisible = true

            let updatedObject = VectorObject(
                id: shape.id,
                layerIndex: obj.layerIndex,
                objectType: .text(shape)
            )
            snapshot.objects[id] = updatedObject
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
        let textIDs = snapshot.objects.values.compactMap { obj -> UUID? in
            if case .text(let shape) = obj.objectType {
                return shape.id
            }
            return nil
        }

        for textID in textIDs {
            translateTextInUnified(id: textID, delta: delta)
        }
    }

    func setTextEditingInUnified(id: UUID, isEditing: Bool) {
        // print("🔴 setTextEditingInUnified: id=\(id), isEditing=\(isEditing)")
        if isEditing {
            // Starting editing - initialize live preview with current content
            if let object = snapshot.objects[id],
               case .text(let shape) = object.objectType,
               let vectorText = VectorText.from(shape) {
                viewState.liveTextContent[id] = vectorText.content
                viewState.isEditingText.insert(id)
            }
        } else {
            // Ending editing - clear live preview state
            viewState.liveTextContent.removeValue(forKey: id)
            viewState.isEditingText.remove(id)
        }

        updateShapeByID(id) { shape in
            // print("🔴 setTextEditingInUnified: inside update block, setting shape.isEditing=\(isEditing)")
            shape.isEditing = isEditing
        }
        // print("🔴 setTextEditingInUnified: after updateShapeByID")
    }

    func updateTextLayerInUnified(id: UUID, layerIndex: Int) {
        if let obj = snapshot.objects[id],
           case .text(let shape) = obj.objectType {

            let updatedObject = VectorObject(
                id: shape.id,
                layerIndex: layerIndex,
                objectType: .text(shape)
            )
            snapshot.objects[id] = updatedObject
        }
    }
}
