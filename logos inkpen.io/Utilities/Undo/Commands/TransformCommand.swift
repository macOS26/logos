import Foundation
import CoreGraphics
import Combine

/// Command for transforming (moving, scaling, rotating) objects
class TransformCommand: BaseCommand {
    private let objectIDs: [UUID]
    private let oldTransforms: [UUID: CGAffineTransform]
    private let newTransforms: [UUID: CGAffineTransform]
    private let oldPositions: [UUID: CGPoint]
    private let newPositions: [UUID: CGPoint]

    init(objectIDs: [UUID],
         oldTransforms: [UUID: CGAffineTransform],
         newTransforms: [UUID: CGAffineTransform],
         oldPositions: [UUID: CGPoint],
         newPositions: [UUID: CGPoint]) {
        self.objectIDs = objectIDs
        self.oldTransforms = oldTransforms
        self.newTransforms = newTransforms
        self.oldPositions = oldPositions
        self.newPositions = newPositions
    }

    override func execute(on document: VectorDocument) {
        applyTransforms(newTransforms, positions: newPositions, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyTransforms(oldTransforms, positions: oldPositions, to: document)
    }

    private func applyTransforms(_ transforms: [UUID: CGAffineTransform],
                                  positions: [UUID: CGPoint],
                                  to document: VectorDocument) {

        for id in objectIDs {
            if let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) {
                var obj = document.unifiedObjects[index]

                if case .shape(var shape) = obj.objectType {
                    if let transform = transforms[id] {
                        shape.transform = transform
                    }
                    if let position = positions[id], shape.isTextObject {
                        shape.textPosition = position
                    }
                    obj = VectorObject(shape: shape, layerIndex: obj.layerIndex, orderID: obj.orderID)
                    document.unifiedObjects[index] = obj
                }
            }
        }

    }
}
