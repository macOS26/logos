import SwiftUI
import CoreText
import AppKit
import Combine

extension VectorDocument {

    func addText(_ text: VectorText) {
        guard let layerIndex = selectedLayerIndex else { return }

        // Create the unified object
        let shape = VectorShape.from(text)
        let orderID = (unifiedObjects.filter { $0.layerIndex == layerIndex }.map { $0.orderID }.max() ?? -1) + 1
        let newObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)

        // Apply the change
        addTextToUnifiedSystem(text, layerIndex: layerIndex)

        // Create command with selection tracking
        let addCommand = AddObjectCommand(object: newObject)
        let command = SelectionCommand(
            wrappedCommand: addCommand,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: [text.id]
        )

        selectedTextIDs = [text.id]
        selectedObjectIDs = [text.id]
        selectedShapeIDs.removeAll()
        syncSelectionArrays()

        executeCommand(command)
    }

    func addTextToLayer(_ text: VectorText, layerIndex: Int?) {
        guard let layerIndex = layerIndex,
              layerIndex >= 0 && layerIndex < layers.count else {
            addText(text)
            return
        }

        var modifiedText = text
        modifiedText.layerIndex = layerIndex

        // Create the unified object
        let shape = VectorShape.from(modifiedText)
        let orderID = (unifiedObjects.filter { $0.layerIndex == layerIndex }.map { $0.orderID }.max() ?? -1) + 1
        let newObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)

        // Apply the change
        addTextToUnifiedSystem(modifiedText, layerIndex: layerIndex)

        // Create command with selection tracking
        let addCommand = AddObjectCommand(object: newObject)
        let command = SelectionCommand(
            wrappedCommand: addCommand,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: [text.id],
            oldSelectedLayerIndex: selectedLayerIndex,
            newSelectedLayerIndex: layerIndex
        )

        selectedTextIDs = [text.id]
        selectedObjectIDs = [text.id]
        selectedShapeIDs.removeAll()
        selectedLayerIndex = layerIndex
        syncSelectionArrays()

        executeCommand(command)
    }

    func removeSelectedText() {
        guard !selectedTextIDs.isEmpty else { return }

        // Capture objects to remove
        let objectsToRemove = unifiedObjects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return selectedTextIDs.contains(shape.id) && shape.isTextObject
            }
            return false
        }

        // Apply the change
        for textID in selectedTextIDs {
            for layerIndex in layers.indices {
                removeShapesUnified(layerIndex: layerIndex, where: { $0.id == textID && $0.isTextObject })
            }
        }

        unifiedObjects.removeAll { obj in
            if case .shape(let shape) = obj.objectType {
                return selectedTextIDs.contains(shape.id) && shape.isTextObject
            }
            return false
        }

        // Create command
        let deleteCommand = DeleteObjectCommand(objects: objectsToRemove)
        let command = SelectionCommand(
            wrappedCommand: deleteCommand,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: []
        )

        selectedTextIDs.removeAll()

        executeCommand(command)
    }

    func duplicateSelectedText() {
        guard !selectedTextIDs.isEmpty else { return }

        var newTextIDs: Set<UUID> = []
        var newObjects: [VectorObject] = []

        for textID in selectedTextIDs {
            if let originalText = findText(by: textID) {
                var duplicateText = originalText
                duplicateText.id = UUID()
                duplicateText.position = CGPoint(
                    x: originalText.position.x + 10,
                    y: originalText.position.y + 10
                )

                if let layerIndex = originalText.layerIndex ?? selectedLayerIndex {
                    let shape = VectorShape.from(duplicateText)
                    let orderID = (unifiedObjects.filter { $0.layerIndex == layerIndex }.map { $0.orderID }.max() ?? -1) + 1
                    let newObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
                    newObjects.append(newObject)

                    addTextToUnifiedSystem(duplicateText, layerIndex: layerIndex)
                }
                newTextIDs.insert(duplicateText.id)
            }
        }

        // Create command
        let addCommand = AddObjectCommand(objects: newObjects)
        let command = SelectionCommand(
            wrappedCommand: addCommand,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newTextIDs
        )

        selectedTextIDs = newTextIDs

        executeCommand(command)
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

        // Capture text objects to remove
        let textObjectsToRemove = unifiedObjects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return selectedTextIDs.contains(shape.id) && shape.isTextObject
            }
            return false
        }

        let selectedTexts = selectedTextIDs.compactMap { textID in findText(by: textID) }
        var newShapeIDs: Set<UUID> = []

        let shapesBefore = unifiedObjects.compactMap { obj -> UUID? in
            if case .shape(let shape) = obj.objectType, !shape.isTextObject {
                return shape.id
            }
            return nil
        }
        let shapesBeforeSet = Set(shapesBefore)

        // Convert text to paths
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
            // Capture newly created shape objects
            let newShapeObjects = unifiedObjects.filter { obj in
                newShapeIDs.contains(obj.id)
            }

            // Remove text objects
            unifiedObjects.removeAll { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.isTextObject && selectedTextIDs.contains(shape.id)
                }
                return false
            }

            // Create compound command (delete text + add shapes)
            // Using GroupCommand to handle both removal and addition
            let command = SelectionCommand(
                wrappedCommand: GroupCommand(
                    operation: .releaseCompound, // Reusing enum, just need a placeholder
                    layerIndex: selectedLayerIndex ?? 0,
                    removedObjectIDs: textObjectsToRemove.map { $0.id },
                    removedShapes: Dictionary(uniqueKeysWithValues: textObjectsToRemove.compactMap { obj in
                        if case .shape(let shape) = obj.objectType {
                            return (obj.id, shape)
                        }
                        return nil
                    }),
                    removedOrderIDs: Dictionary(uniqueKeysWithValues: textObjectsToRemove.map { ($0.id, $0.orderID) }),
                    addedObjectIDs: newShapeObjects.map { $0.id },
                    addedShapes: Dictionary(uniqueKeysWithValues: newShapeObjects.compactMap { obj in
                        if case .shape(let shape) = obj.objectType {
                            return (obj.id, shape)
                        }
                        return nil
                    }),
                    addedOrderIDs: Dictionary(uniqueKeysWithValues: newShapeObjects.map { ($0.id, $0.orderID) }),
                    oldSelectedObjectIDs: selectedObjectIDs,
                    newSelectedObjectIDs: newShapeIDs
                ),
                oldSelectedObjectIDs: selectedObjectIDs,
                newSelectedObjectIDs: newShapeIDs
            )

            selectedTextIDs.removeAll()
            selectedShapeIDs = newShapeIDs
            syncUnifiedSelectionFromLegacy()

            executeCommand(command)
        } else {
            Log.error("❌ TEXT TO OUTLINES FAILED: No new shapes were created", category: .error)
        }
    }


    func updateTextContent(_ textID: UUID, content: String) {

        updateTextContentInUnified(id: textID, content: content)
    }
}
