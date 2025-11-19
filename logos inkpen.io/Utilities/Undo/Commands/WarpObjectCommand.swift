import Foundation

class WarpObjectCommand: BaseCommand {
    private let affectedObjectIDs: [UUID]
    private let oldShapes: [UUID: VectorShape]
    private let newShapes: [UUID: VectorShape]
    private let layerIndices: [UUID: Int]

    init(affectedObjectIDs: [UUID],
         oldShapes: [UUID: VectorShape],
         newShapes: [UUID: VectorShape],
         layerIndices: [UUID: Int]) {
        self.affectedObjectIDs = affectedObjectIDs
        self.oldShapes = oldShapes
        self.newShapes = newShapes
        self.layerIndices = layerIndices
    }

    override func execute(on document: VectorDocument) {
        // Redo: replace old shapes with new shapes
        applyShapes(from: oldShapes, to: newShapes, document: document)
    }

    override func undo(on document: VectorDocument) {
        // Undo: replace new shapes with old shapes
        applyShapes(from: newShapes, to: oldShapes, document: document)
    }

    private func applyShapes(from sourceShapes: [UUID: VectorShape],
                              to targetShapes: [UUID: VectorShape],
                              document: VectorDocument) {
        var affectedLayers = Set<Int>()

        for oldID in affectedObjectIDs {
            guard let oldShape = sourceShapes[oldID],
                  let newShape = targetShapes[oldID],
                  let layerIndex = layerIndices[oldID],
                  layerIndex < document.snapshot.layers.count else { continue }

            // Find which ID is currently in the layer
            let layer = document.snapshot.layers[layerIndex]
            let currentID = layer.objectIDs.contains(oldShape.id) ? oldShape.id : newShape.id

            if let objectIndex = layer.objectIDs.firstIndex(of: currentID) {
                // Remove the current object from snapshot
                document.snapshot.objects.removeValue(forKey: currentID)

                // Update the layer's objectIDs array to use the new shape's ID
                document.snapshot.layers[layerIndex].objectIDs[objectIndex] = newShape.id

                // Add the new shape to snapshot
                let objectType = VectorObject.determineType(for: newShape)
                let newObject = VectorObject(id: newShape.id, layerIndex: layerIndex, objectType: objectType)
                document.snapshot.objects[newShape.id] = newObject

                // Update selection
                document.viewState.selectedObjectIDs.remove(currentID)
                document.viewState.selectedObjectIDs.insert(newShape.id)

                affectedLayers.insert(layerIndex)
            }
        }

        document.triggerLayerUpdates(for: affectedLayers)
    }
}
