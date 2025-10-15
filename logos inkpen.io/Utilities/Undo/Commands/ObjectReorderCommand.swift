import Foundation
import Combine

class ObjectReorderCommand: BaseCommand {
    enum ReorderType {
        case moveObjectToLayer(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int, oldOrderID: Int, newOrderID: Int)
        case moveUp(objectIDs: [UUID], oldOrderIDs: [UUID: Int], newOrderIDs: [UUID: Int])
        case moveDown(objectIDs: [UUID], oldOrderIDs: [UUID: Int], newOrderIDs: [UUID: Int])
        case reorderBetween(sourceID: UUID, targetID: UUID, oldOrderID: Int, newOrderID: Int)
        case bringToFront(objectID: UUID, oldOrderID: Int, newOrderID: Int, layerIndex: Int)
        case sendToBack(objectID: UUID, oldOrderID: Int, newOrderID: Int, layerIndex: Int)
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
        case .moveObjectToLayer(let objectID, let oldLayerIndex, let newLayerIndex, let oldOrderID, let newOrderID):
            let targetLayer = forward ? newLayerIndex : oldLayerIndex
            let targetOrder = forward ? newOrderID : oldOrderID

            if let index = document.unifiedObjects.firstIndex(where: { $0.id == objectID }),
               case .shape(let shape) = document.unifiedObjects[index].objectType {
                document.unifiedObjects[index] = VectorObject(
                    shape: shape,
                    layerIndex: targetLayer,
                    orderID: targetOrder
                )
            }

        case .moveUp(let objectIDs, let oldOrderIDs, let newOrderIDs):
            let orderDict = forward ? newOrderIDs : oldOrderIDs
            for objectID in objectIDs {
                if let index = document.unifiedObjects.firstIndex(where: { $0.id == objectID }),
                   let newOrder = orderDict[objectID],
                   case .shape(let shape) = document.unifiedObjects[index].objectType {
                    document.unifiedObjects[index] = VectorObject(
                        shape: shape,
                        layerIndex: document.unifiedObjects[index].layerIndex,
                        orderID: newOrder
                    )
                }
            }

        case .moveDown(let objectIDs, let oldOrderIDs, let newOrderIDs):
            let orderDict = forward ? newOrderIDs : oldOrderIDs
            for objectID in objectIDs {
                if let index = document.unifiedObjects.firstIndex(where: { $0.id == objectID }),
                   let newOrder = orderDict[objectID],
                   case .shape(let shape) = document.unifiedObjects[index].objectType {
                    document.unifiedObjects[index] = VectorObject(
                        shape: shape,
                        layerIndex: document.unifiedObjects[index].layerIndex,
                        orderID: newOrder
                    )
                }
            }

        case .reorderBetween(let sourceID, _, let oldOrderID, let newOrderID):
            let targetOrder = forward ? newOrderID : oldOrderID

            if let index = document.unifiedObjects.firstIndex(where: { $0.id == sourceID }),
               case .shape(let shape) = document.unifiedObjects[index].objectType {
                document.unifiedObjects[index] = VectorObject(
                    shape: shape,
                    layerIndex: document.unifiedObjects[index].layerIndex,
                    orderID: targetOrder
                )
            }

        case .bringToFront(let objectID, let oldOrderID, let newOrderID, let layerIndex):
            let targetOrder = forward ? newOrderID : oldOrderID

            for i in 0..<document.unifiedObjects.count {
                let obj = document.unifiedObjects[i]
                if obj.layerIndex == layerIndex {
                    if obj.id == objectID {
                        if case .shape(let shape) = obj.objectType {
                            document.unifiedObjects[i] = VectorObject(
                                shape: shape,
                                layerIndex: layerIndex,
                                orderID: targetOrder
                            )
                        }
                    }
                }
            }

        case .sendToBack(let objectID, let oldOrderID, let newOrderID, let layerIndex):
            let targetOrder = forward ? newOrderID : oldOrderID

            for i in 0..<document.unifiedObjects.count {
                let obj = document.unifiedObjects[i]
                if obj.layerIndex == layerIndex {
                    if obj.id == objectID {
                        if case .shape(let shape) = obj.objectType {
                            document.unifiedObjects[i] = VectorObject(
                                shape: shape,
                                layerIndex: layerIndex,
                                orderID: targetOrder
                            )
                        }
                    }
                }
            }
        }

    }
}
