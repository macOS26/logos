import Foundation
import CoreGraphics

extension VectorDocument {

    // MARK: - New Structure Sync Helpers
    // Keep newLayers[].objectIDs and objects dictionary in sync

    // MARK: - Spatial Index Helpers

    /// Calculate bounding box for an object
    private func calculateBounds(for object: VectorObject) -> CGRect {
        return object.shape.bounds
    }

    /// Update spatial index for an object
    private func updateSpatialIndex(for objectID: UUID) {
        guard let object = snapshot.objects[objectID] else {
            spatialIndex.remove(objectID: objectID)
            return
        }
        let bounds = calculateBounds(for: object)
        spatialIndex.update(objectID: objectID, bounds: bounds)
    }

    /// Add object to new structure
    func addObjectToNewStructure(_ object: VectorObject, layerID: UUID) {
        guard let layerIndex = snapshot.layers.firstIndex(where: { $0.id == layerID }) else { return }

        // Update object's layerIndex to match layer position
        let updatedObject = VectorObject(shape: object.shape, layerIndex: layerIndex)

        // Add to objects dictionary
        snapshot.objects[updatedObject.id] = updatedObject

        // Add UUID to layer's objectIDs array (at end = top of draw order)
        if !snapshot.layers[layerIndex].objectIDs.contains(updatedObject.id) {
            snapshot.layers[layerIndex].objectIDs.append(updatedObject.id)
        }

        // Update spatial index
        updateSpatialIndex(for: updatedObject.id)
    }

    /// Remove object from new structure
    func removeObjectFromNewStructure(objectID: UUID) {
        // Remove from spatial index
        spatialIndex.remove(objectID: objectID)

        // Remove from objects dictionary
        snapshot.objects.removeValue(forKey: objectID)

        // Find and remove UUID from whichever layer contains it
        for index in snapshot.layers.indices {
            snapshot.layers[index].objectIDs.removeAll { $0 == objectID }
        }
    }

    /// Move object between layers
    func moveObjectInNewStructure(objectID: UUID, fromLayerID: UUID, toLayerID: UUID) {
        guard let fromIndex = snapshot.layers.firstIndex(where: { $0.id == fromLayerID }) else { return }
        guard let toIndex = snapshot.layers.firstIndex(where: { $0.id == toLayerID }) else { return }
        guard let object = snapshot.objects[objectID] else { return }

        // Update object's layerIndex to match new layer position
        let updatedObject = VectorObject(shape: object.shape, layerIndex: toIndex)
        snapshot.objects[objectID] = updatedObject

        // Remove UUID from source layer's objectIDs
        snapshot.layers[fromIndex].objectIDs.removeAll { $0 == objectID }

        // Add UUID to target layer's objectIDs
        if !snapshot.layers[toIndex].objectIDs.contains(objectID) {
            snapshot.layers[toIndex].objectIDs.append(objectID)
        }
    }

    /// Reorder object within its layer
    func reorderObjectInNewStructure(objectID: UUID, layerID: UUID, toIndex: Int) {
        guard let layerIndex = snapshot.layers.firstIndex(where: { $0.id == layerID }) else { return }
        guard let fromIndex = snapshot.layers[layerIndex].objectIDs.firstIndex(of: objectID) else { return }

        // Move UUID within layer's objectIDs array (layerIndex doesn't change)
        snapshot.layers[layerIndex].objectIDs.remove(at: fromIndex)
        let safeIndex = min(toIndex, snapshot.layers[layerIndex].objectIDs.count)
        snapshot.layers[layerIndex].objectIDs.insert(objectID, at: safeIndex)
    }

    /// Update object in dictionary (for modifications like color, position, etc)
    func updateObjectInNewStructure(_ object: VectorObject) {
        snapshot.objects[object.id] = object

        // Update spatial index with new bounds
        updateSpatialIndex(for: object.id)
    }

    /// Find which layer contains an object
    func findLayerContaining(objectID: UUID) -> UUID? {
        return snapshot.layers.first { $0.objectIDs.contains(objectID) }?.id
    }
}
