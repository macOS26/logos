import Foundation
import Combine

/// Command to add objects at a specific position in the layer's objectIDs array
class AddObjectAtPositionCommand: BaseCommand {
    private let objectsToAdd: [UUID: VectorObject]  // Store by UUID for O(1) lookup
    private let insertPosition: InsertPosition

    enum InsertPosition {
        case front  // Insert at index 0
        case back   // Append to end
        case afterSelection(Set<UUID>)  // Insert after highest index of selected objects
    }

    init(objects: [VectorObject], position: InsertPosition = .back) {
        var dict: [UUID: VectorObject] = [:]
        for obj in objects {
            dict[obj.id] = obj
        }
        self.objectsToAdd = dict
        self.insertPosition = position
    }

    override func execute(on document: VectorDocument) {
        var affectedLayers = Set<Int>()

        // Group objects by layer
        var objectsByLayer: [Int: [(UUID, VectorObject)]] = [:]
        for (uuid, obj) in objectsToAdd {
            objectsByLayer[obj.layerIndex, default: []].append((uuid, obj))
        }

        // Process each layer
        for (layerIndex, layerObjects) in objectsByLayer {
            guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { continue }

            // Add objects to snapshot.objects dictionary
            for (uuid, obj) in layerObjects {
                document.snapshot.objects[uuid] = obj
            }

            // Determine insertion index
            let insertIndex: Int
            switch insertPosition {
            case .front:
                insertIndex = 0

            case .back:
                insertIndex = document.snapshot.layers[layerIndex].objectIDs.count

            case .afterSelection(let selectedIDs):
                // Find the highest index of any selected object in this layer
                let objectIDs = document.snapshot.layers[layerIndex].objectIDs
                var maxIndex = -1
                for (index, objID) in objectIDs.enumerated() {
                    if selectedIDs.contains(objID) {
                        maxIndex = max(maxIndex, index)
                    }
                }
                // Insert after the highest selected object, or at front if no selection
                insertIndex = maxIndex >= 0 ? maxIndex + 1 : 0
            }

            // Insert the object IDs at the determined position
            for (uuid, _) in layerObjects.reversed() {
                if !document.snapshot.layers[layerIndex].objectIDs.contains(uuid) {
                    let safeIndex = min(insertIndex, document.snapshot.layers[layerIndex].objectIDs.count)
                    document.snapshot.layers[layerIndex].objectIDs.insert(uuid, at: safeIndex)
                }
            }

            affectedLayers.insert(layerIndex)
        }

        document.triggerLayerUpdates(for: affectedLayers)
    }

    override func undo(on document: VectorDocument) {
        var affectedLayers = Set<Int>()

        for (uuid, obj) in objectsToAdd {
            document.snapshot.objects.removeValue(forKey: uuid)
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.layers[layerIndex].objectIDs.removeAll { $0 == uuid }
                affectedLayers.insert(layerIndex)
            }
        }

        document.triggerLayerUpdates(for: affectedLayers)
    }
}
