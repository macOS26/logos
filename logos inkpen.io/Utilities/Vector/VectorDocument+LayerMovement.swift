import SwiftUI

extension VectorDocument {

    func moveShapeToLayer(shapeId: UUID, fromLayerIndex: Int, toLayerIndex: Int) {
        guard fromLayerIndex >= 0 && fromLayerIndex < layers.count,
              toLayerIndex >= 0 && toLayerIndex < layers.count,
              fromLayerIndex != toLayerIndex else {
            Log.error("❌ Invalid layer indices for shape move: from=\(fromLayerIndex), to=\(toLayerIndex)", category: .error)
            return
        }

        if layers[toLayerIndex].isLocked {
            return
        }

        if layers[fromLayerIndex].isLocked {
            return
        }

        let shapes = getShapesForLayer(fromLayerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == shapeId }) else {
            Log.error("❌ Shape not found in source layer \(fromLayerIndex)", category: .error)
            return
        }

        guard let shape = getShapeAtIndex(layerIndex: fromLayerIndex, shapeIndex: shapeIndex) else {
            Log.error("❌ Failed to get shape from source layer", category: .error)
            return
        }

        removeShapeAtIndexUnified(layerIndex: fromLayerIndex, shapeIndex: shapeIndex)
        appendShapeToLayerUnified(layerIndex: toLayerIndex, shape: shape)

        selectedShapeIDs = [shapeId]
        selectedLayerIndex = toLayerIndex

    }

    func moveTextToLayer(textId: UUID, toLayerIndex: Int) {
        guard toLayerIndex >= 0 && toLayerIndex < layers.count else {
            Log.error("❌ Invalid layer index for text move: \(toLayerIndex)", category: .error)
            return
        }

        if layers[toLayerIndex].isLocked {
            return
        }

        guard findText(by: textId) != nil else {
            Log.error("❌ Text object not found", category: .error)
            return
        }

        updateTextLayerInUnified(id: textId, layerIndex: toLayerIndex)

        selectedTextIDs = [textId]
        selectedShapeIDs.removeAll()
        selectedLayerIndex = toLayerIndex

    }

    func handleObjectDrop(_ draggableObject: DraggableVectorObject, ontoLayerIndex: Int) {
        switch draggableObject.objectType {
        case .shape:
            moveShapeToLayer(
                shapeId: draggableObject.objectId,
                fromLayerIndex: draggableObject.sourceLayerIndex,
                toLayerIndex: ontoLayerIndex
            )
        case .text:
            moveTextToLayer(
                textId: draggableObject.objectId,
                toLayerIndex: ontoLayerIndex
            )
        }
    }
}
