import Foundation
import Combine

class ObjectReorderCommand: BaseCommand {
    enum ReorderType {
        case moveObjectToLayer(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int, oldIndex: Int, newIndex: Int)
        case moveUp(objectIDs: [UUID], oldIndices: [UUID: Int], newIndices: [UUID: Int])
        case moveDown(objectIDs: [UUID], oldIndices: [UUID: Int], newIndices: [UUID: Int])
        case reorderBetween(sourceID: UUID, targetID: UUID, oldIndex: Int, newIndex: Int)
        case bringToFront(objectID: UUID, oldIndex: Int, newIndex: Int, layerIndex: Int)
        case sendToBack(objectID: UUID, oldIndex: Int, newIndex: Int, layerIndex: Int)
    }

    private let reorderType: ReorderType

    init(reorderType: ReorderType) {
        self.reorderType = reorderType
    }

    override func execute(on document: VectorDocument) {
        applyReorder(forward: true, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyReorder(forward: false, to: document)
    }

    private func applyReorder(forward: Bool, to document: VectorDocument) {
        switch reorderType {
        case .moveObjectToLayer(let objectID, let oldLayerIndex, let newLayerIndex, let oldIndex, let newIndex):
            let targetLayer = forward ? newLayerIndex : oldLayerIndex
            let targetIndex = forward ? newIndex : oldIndex

            if let currentIndex = document.unifiedObjects.firstIndex(where: { $0.id == objectID }),
               case .shape(let shape) = document.unifiedObjects[currentIndex].objectType {
                _ = document.unifiedObjects.remove(at: currentIndex)
                let updatedObj = VectorObject(
                    shape: shape,
                    layerIndex: targetLayer
                )
                document.unifiedObjects.insert(updatedObj, at: min(targetIndex, document.unifiedObjects.count))
            }

        case .moveUp(let objectIDs, let oldIndices, let newIndices):
            let indexDict = forward ? newIndices : oldIndices
            moveObjectsToIndices(objectIDs: objectIDs, targetIndices: indexDict, document: document)

        case .moveDown(let objectIDs, let oldIndices, let newIndices):
            let indexDict = forward ? newIndices : oldIndices
            moveObjectsToIndices(objectIDs: objectIDs, targetIndices: indexDict, document: document)

        case .reorderBetween(let sourceID, _, let oldIndex, let newIndex):
            let targetIndex = forward ? newIndex : oldIndex

            if let currentIndex = document.unifiedObjects.firstIndex(where: { $0.id == sourceID }) {
                let obj = document.unifiedObjects.remove(at: currentIndex)
                document.unifiedObjects.insert(obj, at: min(targetIndex, document.unifiedObjects.count))
            }

        case .bringToFront(let objectID, let oldIndex, let newIndex, _):
            let targetIndex = forward ? newIndex : oldIndex

            if let currentIndex = document.unifiedObjects.firstIndex(where: { $0.id == objectID }) {
                let obj = document.unifiedObjects.remove(at: currentIndex)
                document.unifiedObjects.insert(obj, at: min(targetIndex, document.unifiedObjects.count))
            }

        case .sendToBack(let objectID, let oldIndex, let newIndex, _):
            let targetIndex = forward ? newIndex : oldIndex

            if let currentIndex = document.unifiedObjects.firstIndex(where: { $0.id == objectID }) {
                let obj = document.unifiedObjects.remove(at: currentIndex)
                document.unifiedObjects.insert(obj, at: min(targetIndex, document.unifiedObjects.count))
            }
        }
    }

    private func moveObjectsToIndices(objectIDs: [UUID], targetIndices: [UUID: Int], document: VectorDocument) {
        var objects = document.unifiedObjects
        var affectedObjects: [(UUID, VectorObject)] = []

        for id in objectIDs {
            if let index = objects.firstIndex(where: { $0.id == id }) {
                affectedObjects.append((id, objects[index]))
                objects.remove(at: index)
            }
        }

        for (id, obj) in affectedObjects {
            if let targetIndex = targetIndices[id] {
                let insertIndex = min(targetIndex, objects.count)
                objects.insert(obj, at: insertIndex)
            }
        }

        document.unifiedObjects = objects
    }
}
