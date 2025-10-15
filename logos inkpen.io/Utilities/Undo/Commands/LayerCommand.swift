//import Foundation
//import Combine
//
///// Command for layer operations
//class LayerCommand: BaseCommand {
//    enum Operation {
//        case rename(index: Int, oldName: String, newName: String)
//        case delete(index: Int, layer: VectorLayer, objects: [VectorObject])
//        case move(fromIndex: Int, toIndex: Int)
//        case reorder(sourceLayerId: UUID, targetLayerId: UUID)
//    }
//
//    private let operation: Operation
//
//    init(operation: Operation) {
//        self.operation = operation
//    }
//
//    override func execute(on document: VectorDocument) {
//
//        switch operation {
//        case .rename(let index, _, let newName):
//            if index < document.layers.count {
//                document.layers[index].name = newName
//            }
//
//        case .delete(let index, _, _):
//            if index < document.layers.count && index > 0 {
//                document.unifiedObjects.removeAll { $0.layerIndex == index }
//
//                for i in 0..<document.unifiedObjects.count {
//                    if document.unifiedObjects[i].layerIndex > index {
//                        let obj = document.unifiedObjects[i]
//                        if case .shape(let shape) = obj.objectType {
//                            document.unifiedObjects[i] = VectorObject(
//                                shape: shape,
//                                layerIndex: obj.layerIndex - 1,
//                                orderID: obj.orderID
//                            )
//                        }
//                    }
//                }
//
//                document.layers.remove(at: index)
//
//                if document.selectedLayerIndex == index {
//                    document.selectedLayerIndex = max(0, index - 1)
//                }
//            }
//
//        case .move(let fromIndex, let toIndex):
//            if fromIndex < document.layers.count && toIndex <= document.layers.count {
//                let movingLayer = document.layers.remove(at: fromIndex)
//                let finalIndex = toIndex > fromIndex ? toIndex - 1 : toIndex
//                document.layers.insert(movingLayer, at: finalIndex)
//
//                for i in 0..<document.unifiedObjects.count {
//                    let currentLayerIndex = document.unifiedObjects[i].layerIndex
//                    var newLayerIndex = currentLayerIndex
//
//                    if currentLayerIndex == fromIndex {
//                        newLayerIndex = finalIndex
//                    } else if toIndex > fromIndex {
//                        if currentLayerIndex > fromIndex && currentLayerIndex < toIndex {
//                            newLayerIndex = currentLayerIndex - 1
//                        }
//                    } else {
//                        if currentLayerIndex >= toIndex && currentLayerIndex < fromIndex {
//                            newLayerIndex = currentLayerIndex + 1
//                        }
//                    }
//
//                    if newLayerIndex != currentLayerIndex {
//                        let obj = document.unifiedObjects[i]
//                        if case .shape(let shape) = obj.objectType {
//                            document.unifiedObjects[i] = VectorObject(
//                                shape: shape,
//                                layerIndex: newLayerIndex,
//                                orderID: obj.orderID
//                            )
//                        }
//                    }
//                }
//            }
//
//        case .reorder(let sourceId, let targetId):
//            guard let sourceIndex = document.layers.firstIndex(where: { $0.id == sourceId }),
//                  let targetIndex = document.layers.firstIndex(where: { $0.id == targetId }) else {
//                break
//            }
//
//            let sourceLayer = document.layers.remove(at: sourceIndex)
//            let finalIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
//            document.layers.insert(sourceLayer, at: finalIndex)
//        }
//
//    }
//
//    override func undo(on document: VectorDocument) {
//
//        switch operation {
//        case .rename(let index, let oldName, _):
//            if index < document.layers.count {
//                document.layers[index].name = oldName
//            }
//
//        case .delete(let index, let layer, let objects):
//            if index <= document.layers.count {
//                document.layers.insert(layer, at: index)
//
//                for obj in objects {
//                    document.unifiedObjects.append(obj)
//                }
//            }
//
//        case .move(let fromIndex, let toIndex):
//            let reverseOp = Operation.move(fromIndex: toIndex > fromIndex ? toIndex - 1 : toIndex, toIndex: fromIndex)
//            let reverseCmd = LayerCommand(operation: reverseOp)
//            reverseCmd.execute(on: document)
//            return
//
//        case .reorder(let sourceId, let targetId):
//            let reverseOp = Operation.reorder(sourceLayerId: targetId, targetLayerId: sourceId)
//            let reverseCmd = LayerCommand(operation: reverseOp)
//            reverseCmd.execute(on: document)
//            return
//        }
//
//    }
//}
//
//extension VectorObject.ObjectType {
//    func extractShape() -> VectorShape {
//        switch self {
//        case .shape(let shape):
//            return shape
//        }
//    }
//}
