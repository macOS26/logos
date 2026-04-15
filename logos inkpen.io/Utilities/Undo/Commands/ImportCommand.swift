import Foundation

/// Atomic "add everything from an import" command. Unlike `AddObjectCommand`,
/// this also captures layers appended during the import and group-member
/// VectorObjects installed into `snapshot.objects` without being on any layer,
/// so Cmd+Z removes all three cleanly and redo reinstates them.
@MainActor
final class ImportCommand: BaseCommand {
    private let newLayers: [Layer]                         // appended to snapshot.layers
    private let topLevel: [VectorObject]                   // top-level objects routed to layers
    private let members: [VectorObject]                    // group members (live only in snapshot.objects)
    private var appendedLayerIndexes: [Int] = []           // filled in on execute

    init(newLayers: [Layer], topLevel: [VectorObject], members: [VectorObject]) {
        self.newLayers = newLayers
        self.topLevel = topLevel
        self.members = members
    }

    override func execute(on document: VectorDocument) {
        Log.info("📥 ImportCommand.execute: \(newLayers.count) layers, \(topLevel.count) top, \(members.count) members. Doc had \(document.snapshot.layers.count) layers, \(document.snapshot.objects.count) objects", category: .general)

        // 1. Append layers (track indexes so undo can pop them).
        appendedLayerIndexes.removeAll(keepingCapacity: true)
        for layer in newLayers {
            document.snapshot.layers.append(layer)
            appendedLayerIndexes.append(document.snapshot.layers.count - 1)
        }

        // 2. Install group members directly into snapshot.objects (not on any layer).
        for member in members {
            document.snapshot.objects[member.id] = member
        }

        // 3. Add top-level objects to their target layers.
        var affectedLayers = Set<Int>()
        for obj in topLevel {
            let layerIndex = obj.layerIndex
            guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else {
                Log.error("📥 ImportCommand: SKIPPED top obj \(obj.id) — layerIndex \(layerIndex) out of range (have \(document.snapshot.layers.count) layers)", category: .error)
                continue
            }
            document.snapshot.objects[obj.id] = obj
            if !document.snapshot.layers[layerIndex].objectIDs.contains(obj.id) {
                document.snapshot.layers[layerIndex].objectIDs.append(obj.id)
            }
            affectedLayers.insert(layerIndex)
        }
        affectedLayers.formUnion(appendedLayerIndexes)
        document.triggerLayerUpdates(for: affectedLayers)
        Log.info("📥 ImportCommand.execute DONE: doc has \(document.snapshot.layers.count) layers, \(document.snapshot.objects.count) objects, affectedLayers=\(affectedLayers.sorted())", category: .general)
    }

    override func undo(on document: VectorDocument) {
        Log.info("↩️ ImportCommand.undo: removing \(topLevel.count) top, \(members.count) members, popping layers \(appendedLayerIndexes). Doc has \(document.snapshot.layers.count) layers, \(document.snapshot.objects.count) objects", category: .general)

        var affectedLayers = Set<Int>()

        // 1. Remove top-level objects from their layers + snapshot.objects.
        for obj in topLevel {
            document.snapshot.objects.removeValue(forKey: obj.id)
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.layers[layerIndex].objectIDs.removeAll { $0 == obj.id }
                affectedLayers.insert(layerIndex)
            }
        }

        // 2. Remove group members from snapshot.objects.
        for member in members {
            document.snapshot.objects.removeValue(forKey: member.id)
        }

        // 3. Pop the appended layers (highest index first to preserve lower indexes).
        for idx in appendedLayerIndexes.sorted(by: >) {
            guard idx >= 0 && idx < document.snapshot.layers.count else { continue }
            document.snapshot.layers.remove(at: idx)
        }
        appendedLayerIndexes.removeAll(keepingCapacity: true)

        document.triggerLayerUpdates(for: affectedLayers)
        Log.info("↩️ ImportCommand.undo DONE: doc has \(document.snapshot.layers.count) layers, \(document.snapshot.objects.count) objects", category: .general)
    }
}
