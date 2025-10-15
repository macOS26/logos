import Foundation

/// Command for grouping/ungrouping objects
class GroupCommand: BaseCommand {
    enum GroupOperation {
        case group
        case ungroup
        case flatten
        case unflatten
        case makeCompound
        case releaseCompound
        case makeLooping
        case releaseLooping
    }

    private let operation: GroupOperation
    private let layerIndex: Int

    // For group: store removed shapes and created group
    private let removedObjectIDs: [UUID]
    private let removedShapes: [UUID: VectorShape]
    private let removedOrderIDs: [UUID: Int]

    private let addedObjectIDs: [UUID]
    private let addedShapes: [UUID: VectorShape]
    private let addedOrderIDs: [UUID: Int]

    // Selection state
    private let oldSelectedObjectIDs: Set<UUID>
    private let newSelectedObjectIDs: Set<UUID>

    init(operation: GroupOperation,
         layerIndex: Int,
         removedObjectIDs: [UUID],
         removedShapes: [UUID: VectorShape],
         removedOrderIDs: [UUID: Int],
         addedObjectIDs: [UUID],
         addedShapes: [UUID: VectorShape],
         addedOrderIDs: [UUID: Int],
         oldSelectedObjectIDs: Set<UUID>,
         newSelectedObjectIDs: Set<UUID>) {
        self.operation = operation
        self.layerIndex = layerIndex
        self.removedObjectIDs = removedObjectIDs
        self.removedShapes = removedShapes
        self.removedOrderIDs = removedOrderIDs
        self.addedObjectIDs = addedObjectIDs
        self.addedShapes = addedShapes
        self.addedOrderIDs = addedOrderIDs
        self.oldSelectedObjectIDs = oldSelectedObjectIDs
        self.newSelectedObjectIDs = newSelectedObjectIDs
    }

    override func execute(on document: VectorDocument) {
        // Remove old objects
        document.unifiedObjects.removeAll { removedObjectIDs.contains($0.id) }

        // Add new objects with proper orderIDs
        for objectID in addedObjectIDs {
            guard let shape = addedShapes[objectID],
                  let orderID = addedOrderIDs[objectID] else { continue }
            let newObject = VectorObject(
                shape: shape,
                layerIndex: layerIndex,
                orderID: orderID
            )
            document.unifiedObjects.append(newObject)
        }

        // Update selection
        document.selectedObjectIDs = newSelectedObjectIDs
        document.selectedShapeIDs = newSelectedObjectIDs.filter { id in
            if let obj = document.unifiedObjects.first(where: { $0.id == id }),
               case .shape(let shape) = obj.objectType {
                return !shape.isTextObject
            }
            return false
        }
        document.selectedTextIDs = newSelectedObjectIDs.filter { id in
            if let obj = document.unifiedObjects.first(where: { $0.id == id }),
               case .shape(let shape) = obj.objectType {
                return shape.isTextObject
            }
            return false
        }
    }

    override func undo(on document: VectorDocument) {
        // Remove added objects
        document.unifiedObjects.removeAll { addedObjectIDs.contains($0.id) }

        // Restore removed objects with original orderIDs
        for objectID in removedObjectIDs {
            guard let shape = removedShapes[objectID],
                  let orderID = removedOrderIDs[objectID] else { continue }
            let restoredObject = VectorObject(
                shape: shape,
                layerIndex: layerIndex,
                orderID: orderID
            )
            document.unifiedObjects.append(restoredObject)
        }

        // Restore selection
        document.selectedObjectIDs = oldSelectedObjectIDs
        document.selectedShapeIDs = oldSelectedObjectIDs.filter { id in
            if let obj = document.unifiedObjects.first(where: { $0.id == id }),
               case .shape(let shape) = obj.objectType {
                return !shape.isTextObject
            }
            return false
        }
        document.selectedTextIDs = oldSelectedObjectIDs.filter { id in
            if let obj = document.unifiedObjects.first(where: { $0.id == id }),
               case .shape(let shape) = obj.objectType {
                return shape.isTextObject
            }
            return false
        }
    }
}
