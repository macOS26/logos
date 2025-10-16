import Foundation
import Combine

class StrokeWidthCommand: BaseCommand {
    private let objectIDs: [UUID]
    private let oldWidths: [UUID: Double]
    private let newWidths: [UUID: Double]

    init(objectIDs: [UUID], oldWidths: [UUID: Double], newWidths: [UUID: Double]) {
        self.objectIDs = objectIDs
        self.oldWidths = oldWidths
        self.newWidths = newWidths
    }

    override func execute(on document: VectorDocument) {
        applyWidths(newWidths, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyWidths(oldWidths, to: document)
    }

    private func applyWidths(_ widths: [UUID: Double], to document: VectorDocument) {

        for id in objectIDs {
            guard let width = widths[id],
                  let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) else { continue }
            var obj = document.unifiedObjects[index]

            if case .shape(var shape) = obj.objectType {
                if shape.isTextObject {
                    if var typography = shape.typography {
                        typography.strokeWidth = width
                        shape.typography = typography
                    }
                } else {
                    shape.strokeStyle?.width = width
                }
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.unifiedObjects[index] = obj
            }
        }

    }
}
