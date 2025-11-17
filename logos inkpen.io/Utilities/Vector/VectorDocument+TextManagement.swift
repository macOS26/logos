import SwiftUI
import CoreText
import AppKit
import Combine

extension VectorDocument {

    func addText(_ text: VectorText) {
        guard let layerIndex = selectedLayerIndex else { return }

        let oldSelection = viewState.selectedObjectIDs
        let shape = VectorShape.from(text)
        let command = TextManagementCommand(
            operation: .addText(textID: text.id, shape: shape, layerIndex: layerIndex),
            oldSelection: oldSelection,
            newSelection: [text.id]
        )

        commandManager.execute(command)

        viewState.selectedObjectIDs = [text.id]

    }

    func addTextToLayer(_ text: VectorText, layerIndex: Int?) {
        guard let layerIndex = layerIndex,
              layerIndex >= 0 && layerIndex < snapshot.layers.count else {
            addText(text)
            return
        }

        let oldSelection = viewState.selectedObjectIDs
        var modifiedText = text
        modifiedText.layerIndex = layerIndex

        let shape = VectorShape.from(modifiedText)
        let command = TextManagementCommand(
            operation: .addText(textID: text.id, shape: shape, layerIndex: layerIndex),
            oldSelection: oldSelection,
            newSelection: [text.id]
        )

        commandManager.execute(command)

        viewState.selectedObjectIDs = [text.id]
        selectedLayerIndex = layerIndex

    }

    func removeSelectedText() {
        let oldSelection = viewState.selectedObjectIDs
        var removedObjects: [UUID: VectorObject] = [:]

        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID],
               case .text = obj.objectType {
                removedObjects[objectID] = obj
            }
        }

        let command = TextManagementCommand(
            operation: .removeText(textIDs: Array(viewState.selectedObjectIDs), removedObjects: removedObjects),
            oldSelection: oldSelection,
            newSelection: []
        )

        commandManager.execute(command)

        viewState.selectedObjectIDs.removeAll()
    }

    func duplicateSelectedText() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        let oldSelection = viewState.selectedObjectIDs
        var newTextIDs: Set<UUID> = []
        var duplicatedObjects: [UUID: VectorObject] = [:]

        for textID in viewState.selectedObjectIDs {
            if let originalText = findText(by: textID),
               let obj = snapshot.objects[textID] {
                var duplicateText = originalText
                duplicateText.id = UUID()
                duplicateText.position = CGPoint(
                    x: originalText.position.x + 10,
                    y: originalText.position.y + 10
                )

                let shape = VectorShape.from(duplicateText)
                let layerIndex = obj.layerIndex
                let newObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: .text(shape))
                duplicatedObjects[shape.id] = newObject
                newTextIDs.insert(duplicateText.id)
            }
        }

        let command = TextManagementCommand(
            operation: .duplicateText(originalIDs: Array(viewState.selectedObjectIDs), duplicatedObjects: duplicatedObjects),
            oldSelection: oldSelection,
            newSelection: newTextIDs
        )

        commandManager.execute(command)

        viewState.selectedObjectIDs = newTextIDs
    }

    func updateTextInUnified(_ updatedText: VectorText) {
        if let obj = snapshot.objects[updatedText.id],
           case .text = obj.objectType {

            let updatedShape = VectorShape.from(updatedText)
            let updatedObject = VectorObject(
                id: updatedShape.id,
                layerIndex: obj.layerIndex,
                objectType: .text(updatedShape)
            )
            snapshot.objects[updatedText.id] = updatedObject
        }
    }

    func convertSelectedTextToOutlines() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        let selectedTexts = viewState.selectedObjectIDs.compactMap { textID -> VectorText? in
            guard let obj = snapshot.objects[textID],
                  case .text(let shape) = obj.objectType else { return nil }
            return VectorText.from(shape)
        }

        // Save old state for undo
        let oldSelection = viewState.selectedObjectIDs
        let removedTextIDs = Array(viewState.selectedObjectIDs)
        var removedTextObjects: [UUID: VectorObject] = [:]
        for uuid in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[uuid] {
                removedTextObjects[uuid] = obj
            }
        }

        var newShapeIDs: Set<UUID> = []
        let shapesBefore = snapshot.objects.values.compactMap { obj -> UUID? in
            switch obj.objectType {
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.id
            case .text:
                return nil
            }
        }
        let shapesBeforeSet = Set(shapesBefore)

        for textObj in selectedTexts {
            let viewModel = ProfessionalTextViewModel(textObject: textObj, document: self)
            viewModel.convertToPath()
        }

        let shapesAfter = snapshot.objects.values.compactMap { obj -> UUID? in
            switch obj.objectType {
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.id
            case .text:
                return nil
            }
        }
        let shapesAfterSet = Set(shapesAfter)

        newShapeIDs = shapesAfterSet.subtracting(shapesBeforeSet)

        if !newShapeIDs.isEmpty {
            // Capture new shape objects for undo
            var addedShapeObjects: [UUID: VectorObject] = [:]
            for uuid in newShapeIDs {
                if let obj = snapshot.objects[uuid] {
                    addedShapeObjects[uuid] = obj
                }
            }

            // Remove text objects from snapshot
            for textID in removedTextIDs {
                snapshot.objects.removeValue(forKey: textID)
            }

            viewState.selectedObjectIDs.removeAll()
            viewState.selectedObjectIDs = newShapeIDs
            

            // Use command system for undo/redo
            let command = TextManagementCommand(
                operation: .convertToOutlines(
                    removedTextIDs: removedTextIDs,
                    removedObjects: removedTextObjects,
                    addedShapeIDs: Array(newShapeIDs),
                    addedObjects: addedShapeObjects
                ),
                oldSelection: oldSelection,
                newSelection: newShapeIDs
            )
            commandManager.execute(command)
        } else {
            Log.error("❌ TEXT TO OUTLINES FAILED: No new shapes were created", category: .error)
        }
    }

    func updateTextContent(_ textID: UUID, content: String) {

        updateTextContentInUnified(id: textID, content: content)
    }
}
