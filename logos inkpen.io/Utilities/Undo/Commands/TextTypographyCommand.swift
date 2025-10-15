import Foundation
import Combine

/// Command for text typography property changes
class TextTypographyCommand: BaseCommand {
    private let textID: UUID
    private let oldTypography: TypographyProperties?
    private let newTypography: TypographyProperties?

    init(textID: UUID, oldTypography: TypographyProperties?, newTypography: TypographyProperties?) {
        self.textID = textID
        self.oldTypography = oldTypography
        self.newTypography = newTypography
    }

    override func execute(on document: VectorDocument) {
        applyTypography(newTypography, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyTypography(oldTypography, to: document)
    }

    private func applyTypography(_ typography: TypographyProperties?, to document: VectorDocument) {
        if let index = document.unifiedObjects.firstIndex(where: { $0.id == textID }) {
            let obj = document.unifiedObjects[index]
            if case .shape(var shape) = obj.objectType {
                shape.typography = typography
                document.unifiedObjects[index] = VectorObject(
                    shape: shape,
                    layerIndex: obj.layerIndex,
                    orderID: obj.orderID
                )
            }
        }
    }
}
