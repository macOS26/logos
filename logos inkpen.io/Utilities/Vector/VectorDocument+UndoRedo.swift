import SwiftUI
import Combine

extension VectorDocument {

    func executeCommand(_ command: Command) {
        commandManager.execute(command)
    }

    func undo() {
        if commandManager.canUndo {
            commandManager.undo()
            objectWillChange.send()
            NotificationCenter.default.post(name: Notification.Name("ClearPreviewStates"), object: nil)
            return
        }

        objectWillChange.send()
        NotificationCenter.default.post(name: Notification.Name("ClearPreviewStates"), object: nil)

        cleanupImageRegistry()
    }

    func redo() {
        if commandManager.canRedo {
            commandManager.redo()
            objectWillChange.send()
            return
        }

        cleanupImageRegistry()
    }

    private func fixUnifiedObjectsOrderingAfterUndo() {
        let wasUndoRedoOperation = isUndoRedoOperation
        isUndoRedoOperation = false

        defer { isUndoRedoOperation = wasUndoRedoOperation }

        fixTextObjectOrderingAfterUndo()

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard layerObjects.count > 1 else { continue }

            let orderIDs = layerObjects.map { $0.orderID }.sorted()
            let expectedOrderIDs = Array(0..<layerObjects.count)

            let needsFixing = orderIDs != expectedOrderIDs

            if needsFixing {
                let sortedObjects = layerObjects.sorted { $0.orderID < $1.orderID }

                for (arrayIndex, unifiedObject) in sortedObjects.enumerated() {
                    let newOrderID = sortedObjects.count - 1 - arrayIndex

                    if let objectIndex = unifiedObjects.firstIndex(where: { $0.id == unifiedObject.id }) {
                        switch unifiedObject.objectType {
                        case .shape(let shape):
                            unifiedObjects[objectIndex] = VectorObject(
                                shape: shape,
                                layerIndex: layerIndex,
                                orderID: newOrderID
                            )
                            unifiedObjects[objectIndex] = VectorObject(
                                shape: shape,
                                layerIndex: layerIndex,
                                orderID: newOrderID
                            )
                        }
                    }
                }
            }
        }

    }

    private func fixTextObjectOrderingAfterUndo() {
    }

}
