import Foundation
import Combine

class VisibilityCommand: BaseCommand {
    enum Property {
        case visibility
        case locked
    }
    
    private let objectIDs: [UUID]
    private let property: Property
    private let oldValues: [UUID: Bool]
    private let newValues: [UUID: Bool]
    
    init(objectIDs: [UUID], property: Property, oldValues: [UUID: Bool], newValues: [UUID: Bool]) {
        self.objectIDs = objectIDs
        self.property = property
        self.oldValues = oldValues
        self.newValues = newValues
    }
    
    override func execute(on document: VectorDocument) {
        applyValues(newValues, to: document)
    }
    
    override func undo(on document: VectorDocument) {
        applyValues(oldValues, to: document)
    }
    
    private func applyValues(_ values: [UUID: Bool], to document: VectorDocument) {
        var affectedLayers = Set<Int>()

        for id in objectIDs {
            guard let index = document.unifiedObjects.firstIndex(where: { $0.id == id }),
                  let value = values[id] else { continue }
            var obj = document.unifiedObjects[index]

            if case .shape(var shape) = obj.objectType {
                switch property {
                case .visibility:
                    shape.isVisible = value
                case .locked:
                    shape.isLocked = value
                }
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.unifiedObjects[index] = obj

                // Update snapshot
                document.snapshot.objects[id] = obj

                // Track affected layer
                affectedLayers.insert(obj.layerIndex)
            }
        }

        // Trigger update for each affected layer
        for layerIndex in affectedLayers {
            guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { continue }
            let layerID = document.snapshot.layers[layerIndex].id
            document.viewState.layerUpdateTriggers[layerID, default: 0] &+= 1
        }
    }
}
