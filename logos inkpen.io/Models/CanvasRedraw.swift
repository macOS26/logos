import Foundation
import Combine

/// Centralized notification system for Canvas redraws
/// Allows targeted updates by layer, object, or full canvas refresh
class CanvasRedraw: ObservableObject {

    // MARK: - Published Triggers

    /// Toggle to force full canvas redraw across all layers
    @Published var fullCanvasRefresh: Bool = false

    /// Set of layer UUIDs that need redrawing
    @Published var layersNeedingRedraw: Set<UUID> = []

    /// Set of object UUIDs that changed (for granular updates)
    @Published var objectsChanged: Set<UUID> = []

    /// Timestamp for last update (for .id() modifier)
    @Published var lastUpdateTimestamp: Date = Date()

    // MARK: - Notification Methods

    /// Trigger a full canvas refresh (all layers, all objects)
    func refreshFullCanvas() {
        fullCanvasRefresh.toggle()
        lastUpdateTimestamp = Date()
    }

    /// Notify that specific layer needs redrawing
    func refreshLayer(_ layerID: UUID) {
        layersNeedingRedraw.insert(layerID)
        lastUpdateTimestamp = Date()

        // Auto-clear after a frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            self?.layersNeedingRedraw.remove(layerID)
        }
    }

    /// Notify that multiple layers need redrawing
    func refreshLayers(_ layerIDs: [UUID]) {
        layerIDs.forEach { layersNeedingRedraw.insert($0) }
        lastUpdateTimestamp = Date()

        // Auto-clear after a frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            layerIDs.forEach { self?.layersNeedingRedraw.remove($0) }
        }
    }

    /// Notify that specific object changed (and needs redraw)
    func objectDidChange(_ objectID: UUID) {
        objectsChanged.insert(objectID)
        lastUpdateTimestamp = Date()

        // Auto-clear after a frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            self?.objectsChanged.remove(objectID)
        }
    }

    /// Notify that multiple objects changed
    func objectsDidChange(_ objectIDs: [UUID]) {
        objectIDs.forEach { objectsChanged.insert($0) }
        lastUpdateTimestamp = Date()

        // Auto-clear after a frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            objectIDs.forEach { self?.objectsChanged.remove($0) }
        }
    }

    /// Check if a specific object needs redrawing
    func needsRedraw(objectID: UUID) -> Bool {
        return objectsChanged.contains(objectID) || fullCanvasRefresh
    }

    /// Check if a specific layer needs redrawing
    func needsRedraw(layerID: UUID) -> Bool {
        return layersNeedingRedraw.contains(layerID) || fullCanvasRefresh
    }

    /// Clear all redraw flags
    func clearAll() {
        layersNeedingRedraw.removeAll()
        objectsChanged.removeAll()
    }
}
