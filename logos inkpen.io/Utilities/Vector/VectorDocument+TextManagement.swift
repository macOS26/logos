import SwiftUI
import CoreText
import AppKit
import Combine

extension VectorDocument {

    func addText(_ text: VectorText) {
        guard let layerIndex = selectedLayerIndex else { return }

        let oldSelection = selectedObjectIDs
        let shape = VectorShape.from(text)
        let orderID = (unifiedObjects.filter { $0.layerIndex == layerIndex }.map { $0.orderID }.max() ?? -1) + 1

        let command = TextManagementCommand(
            operation: .addText(textID: text.id, shape: shape, layerIndex: layerIndex, orderID: orderID),
            oldSelection: oldSelection,
            newSelection: [text.id]
        )

        commandManager.execute(command)

        selectedTextIDs = [text.id]
        selectedObjectIDs = [text.id]
        selectedShapeIDs.removeAll()
        syncSelectionArrays()
    }

    func addTextToLayer(_ text: VectorText, layerIndex: Int?) {
        guard let layerIndex = layerIndex,
              layerIndex >= 0 && layerIndex < layers.count else {
            addText(text)
            return
        }

        let oldSelection = selectedObjectIDs
        var modifiedText = text
        modifiedText.layerIndex = layerIndex

        let shape = VectorShape.from(modifiedText)
        let orderID = (unifiedObjects.filter { $0.layerIndex == layerIndex }.map { $0.orderID }.max() ?? -1) + 1

        let command = TextManagementCommand(
            operation: .addText(textID: text.id, shape: shape, layerIndex: layerIndex, orderID: orderID),
            oldSelection: oldSelection,
            newSelection: [text.id]
        )

        commandManager.execute(command)

        selectedTextIDs = [text.id]
        selectedObjectIDs = [text.id]
        selectedShapeIDs.removeAll()
        selectedLayerIndex = layerIndex
        syncSelectionArrays()
    }

    func removeSelectedText() {
        let oldSelection = selectedObjectIDs
        let removedObjects = unifiedObjects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return selectedTextIDs.contains(shape.id) && shape.isTextObject
            }
            return false
        }

        let command = TextManagementCommand(
            operation: .removeText(textIDs: Array(selectedTextIDs), removedObjects: removedObjects),
            oldSelection: oldSelection,
            newSelection: []
        )

        commandManager.execute(command)

        selectedTextIDs.removeAll()
    }

    func duplicateSelectedText() {
        guard !selectedTextIDs.isEmpty else { return }

        let oldSelection = selectedObjectIDs
        var newTextIDs: Set<UUID> = []
        var duplicatedObjects: [VectorObject] = []

        for textID in selectedTextIDs {
            if let originalText = findText(by: textID),
               let obj = unifiedObjects.first(where: { $0.id == textID }) {
                var duplicateText = originalText
                duplicateText.id = UUID()
                duplicateText.position = CGPoint(
                    x: originalText.position.x + 10,
                    y: originalText.position.y + 10
                )

                let shape = VectorShape.from(duplicateText)
                let layerIndex = obj.layerIndex
                let orderID = (unifiedObjects.filter { $0.layerIndex == layerIndex }.map { $0.orderID }.max() ?? -1) + 1

                let newObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
                duplicatedObjects.append(newObject)
                newTextIDs.insert(duplicateText.id)
            }
        }

        let command = TextManagementCommand(
            operation: .duplicateText(originalIDs: Array(selectedTextIDs), duplicatedObjects: duplicatedObjects),
            oldSelection: oldSelection,
            newSelection: newTextIDs
        )

        commandManager.execute(command)

        selectedTextIDs = newTextIDs
    }

    func updateTextInUnified(_ updatedText: VectorText) {
        if let unifiedIndex = unifiedObjects.firstIndex(where: { $0.id == updatedText.id }),
           case .shape(_) = unifiedObjects[unifiedIndex].objectType {

            let updatedShape = VectorShape.from(updatedText)
            unifiedObjects[unifiedIndex] = VectorObject(
                shape: updatedShape,
                layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                orderID: unifiedObjects[unifiedIndex].orderID
            )

        }
    }

    func convertSelectedTextToOutlines() {
        guard !selectedTextIDs.isEmpty else { return }

        // SaveToUndoStack was here
        // saveToUndoStack()

        let selectedTexts = selectedTextIDs.compactMap { textID in findText(by: textID) }
        var newShapeIDs: Set<UUID> = []

        let shapesBefore = unifiedObjects.compactMap { obj -> UUID? in
            if case .shape(let shape) = obj.objectType, !shape.isTextObject {
                return shape.id
            }
            return nil
        }
        let shapesBeforeSet = Set(shapesBefore)

        for textObj in selectedTexts {
            let viewModel = ProfessionalTextViewModel(textObject: textObj, document: self)
            viewModel.convertToPath()
        }

        let shapesAfter = unifiedObjects.compactMap { obj -> UUID? in
            if case .shape(let shape) = obj.objectType, !shape.isTextObject {
                return shape.id
            }
            return nil
        }
        let shapesAfterSet = Set(shapesAfter)

        newShapeIDs = shapesAfterSet.subtracting(shapesBeforeSet)

        if !newShapeIDs.isEmpty {
            unifiedObjects.removeAll { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.isTextObject && selectedTextIDs.contains(shape.id)
                }
                return false
            }

            selectedTextIDs.removeAll()
            selectedShapeIDs = newShapeIDs

            syncUnifiedSelectionFromLegacy()
        } else {
            Log.error("❌ TEXT TO OUTLINES FAILED: No new shapes were created", category: .error)
        }
    }

    func updateTextContent(_ textID: UUID, content: String) {

        updateTextContentInUnified(id: textID, content: content)
    }
}
