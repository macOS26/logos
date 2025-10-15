import Foundation

/// Command that wraps another command and also manages selection state
class SelectionCommand: BaseCommand {
    private let wrappedCommand: Command
    private let oldSelectedObjectIDs: Set<UUID>
    private let newSelectedObjectIDs: Set<UUID>
    private let oldSelectedLayerIndex: Int?
    private let newSelectedLayerIndex: Int?

    init(wrappedCommand: Command,
         oldSelectedObjectIDs: Set<UUID>,
         newSelectedObjectIDs: Set<UUID>,
         oldSelectedLayerIndex: Int? = nil,
         newSelectedLayerIndex: Int? = nil) {
        self.wrappedCommand = wrappedCommand
        self.oldSelectedObjectIDs = oldSelectedObjectIDs
        self.newSelectedObjectIDs = newSelectedObjectIDs
        self.oldSelectedLayerIndex = oldSelectedLayerIndex
        self.newSelectedLayerIndex = newSelectedLayerIndex
    }

    override func execute(on document: VectorDocument) {
        wrappedCommand.execute(on: document)
        applySelection(document: document, objectIDs: newSelectedObjectIDs, layerIndex: newSelectedLayerIndex)
    }

    override func undo(on document: VectorDocument) {
        wrappedCommand.undo(on: document)
        applySelection(document: document, objectIDs: oldSelectedObjectIDs, layerIndex: oldSelectedLayerIndex)
    }

    private func applySelection(document: VectorDocument, objectIDs: Set<UUID>, layerIndex: Int?) {
        document.selectedObjectIDs = objectIDs

        // Update shape/text selection sets
        document.selectedShapeIDs = objectIDs.filter { id in
            if let obj = document.unifiedObjects.first(where: { $0.id == id }),
               case .shape(let shape) = obj.objectType {
                return !shape.isTextObject
            }
            return false
        }

        document.selectedTextIDs = objectIDs.filter { id in
            if let obj = document.unifiedObjects.first(where: { $0.id == id }),
               case .shape(let shape) = obj.objectType {
                return shape.isTextObject
            }
            return false
        }

        if let layerIndex = layerIndex {
            document.selectedLayerIndex = layerIndex
        }
    }
}
