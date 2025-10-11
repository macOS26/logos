
import SwiftUI
import CoreText
import AppKit
import Combine

extension VectorDocument {

    func addText(_ text: VectorText) {
        saveToUndoStack()

        if let layerIndex = selectedLayerIndex {
            addTextToUnifiedSystem(text, layerIndex: layerIndex)
        }

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

        saveToUndoStack()

        var modifiedText = text
        modifiedText.layerIndex = layerIndex

        addTextToUnifiedSystem(modifiedText, layerIndex: layerIndex)

        selectedTextIDs = [text.id]
        selectedObjectIDs = [text.id]
        selectedShapeIDs.removeAll()
        selectedLayerIndex = layerIndex
        syncSelectionArrays()

    }

    func removeSelectedText() {
        saveToUndoStack()

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


        selectedTextIDs.removeAll()
    }

    func duplicateSelectedText() {
        guard !selectedTextIDs.isEmpty else { return }
        saveToUndoStack()

        var newTextIDs: Set<UUID> = []

        for textID in selectedTextIDs {
            if let originalText = findText(by: textID) {
                var duplicateText = originalText
                duplicateText.id = UUID()
                duplicateText.position = CGPoint(
                    x: originalText.position.x + 10,
                    y: originalText.position.y + 10
                )

                if let layerIndex = originalText.layerIndex ?? selectedLayerIndex {
                    addTextToUnifiedSystem(duplicateText, layerIndex: layerIndex)
                }
                newTextIDs.insert(duplicateText.id)
            }
        }

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

        saveToUndoStack()

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

            objectWillChange.send()
        } else {
            Log.error("❌ TEXT TO OUTLINES FAILED: No new shapes were created", category: .error)
        }

    }


    func updateTextContent(_ textID: UUID, content: String) {

        updateTextContentInUnified(id: textID, content: content)
    }
}
