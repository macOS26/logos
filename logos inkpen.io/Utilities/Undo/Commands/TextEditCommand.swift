import Foundation
import Combine

/// Command for editing text content
class TextEditCommand: BaseCommand {
    private let textID: UUID
    private let oldContent: String
    private let newContent: String

    init(textID: UUID, oldContent: String, newContent: String) {
        self.textID = textID
        self.oldContent = oldContent
        self.newContent = newContent
    }

    override func execute(on document: VectorDocument) {
        applyContent(newContent, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyContent(oldContent, to: document)
    }

    private func applyContent(_ content: String, to document: VectorDocument) {

        if let index = document.unifiedObjects.firstIndex(where: { $0.id == textID }) {
            var obj = document.unifiedObjects[index]

            if case .shape(var shape) = obj.objectType, shape.isTextObject {
                shape.textContent = content
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex, orderID: obj.orderID)
                document.unifiedObjects[index] = obj
            }
        }

    }

    func mergeWith(_ other: Command) -> Command? {
        // Merge consecutive text edits on the same text object
        guard let otherTextEdit = other as? TextEditCommand,
              otherTextEdit.textID == self.textID else {
            return nil
        }

        // Create merged command with original old content and new new content
        return TextEditCommand(
            textID: textID,
            oldContent: self.oldContent,
            newContent: otherTextEdit.newContent
        )
    }
}
