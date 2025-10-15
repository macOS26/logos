import Foundation

/// Command for clipping mask operations
class ClippingMaskCommand: BaseCommand {
    private let layerIndex: Int
    private let oldShapes: [UUID: VectorShape]
    private let newShapes: [UUID: VectorShape]
    private let oldSelectedObjectIDs: Set<UUID>
    private let newSelectedObjectIDs: Set<UUID>

    init(layerIndex: Int,
         oldShapes: [UUID: VectorShape],
         newShapes: [UUID: VectorShape],
         oldSelectedObjectIDs: Set<UUID>,
         newSelectedObjectIDs: Set<UUID>) {
        self.layerIndex = layerIndex
        self.oldShapes = oldShapes
        self.newShapes = newShapes
        self.oldSelectedObjectIDs = oldSelectedObjectIDs
        self.newSelectedObjectIDs = newSelectedObjectIDs
    }

    override func execute(on document: VectorDocument) {
        applyShapes(newShapes, to: document)
        document.selectedObjectIDs = newSelectedObjectIDs
        document.syncSelectionArrays()
    }

    override func undo(on document: VectorDocument) {
        applyShapes(oldShapes, to: document)
        document.selectedObjectIDs = oldSelectedObjectIDs
        document.syncSelectionArrays()
    }

    private func applyShapes(_ shapes: [UUID: VectorShape], to document: VectorDocument) {
        for (shapeID, shape) in shapes {
            if let index = document.unifiedObjects.firstIndex(where: { $0.id == shapeID }),
               case .shape(_) = document.unifiedObjects[index].objectType {
                document.unifiedObjects[index] = VectorObject(
                    shape: shape,
                    layerIndex: document.unifiedObjects[index].layerIndex,
                    orderID: document.unifiedObjects[index].orderID
                )
            }
        }
        document.forceResyncUnifiedObjects()
    }
}
