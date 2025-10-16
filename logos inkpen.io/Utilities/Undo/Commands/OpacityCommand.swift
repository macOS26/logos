import Foundation
import Combine

class OpacityCommand: BaseCommand {
    enum OpacityTarget {
        case fill
        case stroke
    }

    private let objectIDs: [UUID]
    private let target: OpacityTarget
    private let oldOpacities: [UUID: Double]
    private let newOpacities: [UUID: Double]

    init(objectIDs: [UUID], target: OpacityTarget, oldOpacities: [UUID: Double], newOpacities: [UUID: Double]) {
        self.objectIDs = objectIDs
        self.target = target
        self.oldOpacities = oldOpacities
        self.newOpacities = newOpacities
    }

    override func execute(on document: VectorDocument) {
        applyOpacities(newOpacities, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyOpacities(oldOpacities, to: document)
    }

    private func applyOpacities(_ opacities: [UUID: Double], to document: VectorDocument) {

        for id in objectIDs {
            guard let opacity = opacities[id],
                  let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) else { continue }
            var obj = document.unifiedObjects[index]

            if case .shape(var shape) = obj.objectType {
                if shape.isTextObject {
                    if var typography = shape.typography {
                        switch target {
                        case .fill:
                            typography.fillOpacity = opacity
                        case .stroke:
                            typography.strokeOpacity = opacity
                        }
                        shape.typography = typography
                    }
                } else {
                    switch target {
                    case .fill:
                        shape.fillStyle?.opacity = opacity
                    case .stroke:
                        shape.strokeStyle?.opacity = opacity
                    }
                }
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.unifiedObjects[index] = obj
            }
        }

    }
}
