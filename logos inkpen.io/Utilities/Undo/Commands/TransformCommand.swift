import Foundation
import CoreGraphics
import Combine

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
            guard let obj = document.snapshot.objects[id] else { continue }

            let updatedObj: VectorObject
            switch obj.objectType {
            case .text(var shape):
                if let transform = transforms[id] {
                    shape.transform = transform
                }
                if let position = positions[id] {
                    shape.textPosition = position
                }
                updatedObj = VectorObject(shape: shape, layerIndex: obj.layerIndex)

            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                if let transform = transforms[id] {
                    shape.transform = transform
                }
                updatedObj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
            }

            document.snapshot.objects[id] = updatedObj
        }

        document.changeNotifier.notifyLayersChanged()
    }
}
