import SwiftUI

/// High-performance spatial index for O(1) hit testing
struct SpatialIndex {
    private let gridSize: CGFloat = 50 // 50x50 pixel cells for finer granularity
    private var grid: [GridCell: Set<UUID>] = [:]
    private var objectBounds: [UUID: CGRect] = [:] // Cache bounds for fast updates

    struct GridCell: Hashable {
        let x: Int
        let y: Int
    }

    /// Rebuild the entire spatial index from document snapshot
    mutating func rebuild(from snapshot: DocumentSnapshot) {
        grid.removeAll(keepingCapacity: true)
        objectBounds.removeAll(keepingCapacity: true)

        // Build index for all visible objects
        for (id, object) in snapshot.objects {
            guard object.isVisible else { continue }

            // Check if layer is visible
            if let layer = snapshot.layers.first(where: { $0.objectIDs.contains(id) }),
               !layer.isVisible {
                continue
            }

            let bounds = object.shape.bounds.applying(object.shape.transform)
            objectBounds[id] = bounds

            let cells = cellsForBounds(bounds)
            for cell in cells {
                grid[cell, default: []].insert(id)
            }
        }
    }

    /// Update index for a single object (more efficient than full rebuild)
    mutating func updateObject(_ objectID: UUID, in snapshot: DocumentSnapshot) {
        // Remove old entries
        if let oldBounds = objectBounds[objectID] {
            let oldCells = cellsForBounds(oldBounds)
            for cell in oldCells {
                grid[cell]?.remove(objectID)
                if grid[cell]?.isEmpty == true {
                    grid.removeValue(forKey: cell)
                }
            }
        }

        // Add new entries if object exists and is visible
        if let object = snapshot.objects[objectID], object.isVisible {
            let bounds = object.shape.bounds.applying(object.shape.transform)
            objectBounds[objectID] = bounds

            let cells = cellsForBounds(bounds)
            for cell in cells {
                grid[cell, default: []].insert(objectID)
            }
        } else {
            objectBounds.removeValue(forKey: objectID)
        }
    }

    /// Get candidate objects at a specific point (fast spatial lookup)
    func candidateObjectIDs(at point: CGPoint) -> Set<UUID> {
        let cell = GridCell(
            x: Int(floor(point.x / gridSize)),
            y: Int(floor(point.y / gridSize))
        )

        return grid[cell] ?? []
    }

    /// Get candidate objects that might intersect with a rectangle
    func candidateObjectIDs(in rect: CGRect) -> Set<UUID> {
        let cells = cellsForBounds(rect)
        var candidates = Set<UUID>()

        for cell in cells {
            if let objectIDs = grid[cell] {
                candidates.formUnion(objectIDs)
            }
        }

        return candidates
    }

    /// Find the topmost object at a point using spatial index
    func hitTest(at point: CGPoint, in snapshot: DocumentSnapshot, testFunction: (VectorObject, CGPoint) -> Bool) -> VectorObject? {
        // Get candidate objects from spatial index (O(1) lookup)
        let candidateIDs = candidateObjectIDs(at: point)

        guard !candidateIDs.isEmpty else { return nil }

        // Build list of candidates with their layer order
        var candidates: [(object: VectorObject, layerIndex: Int, objectIndex: Int)] = []

        for (layerIndex, layer) in snapshot.layers.enumerated().reversed() {
            guard layer.isVisible else { continue }

            for (objectIndex, objectID) in layer.objectIDs.enumerated().reversed() {
                guard candidateIDs.contains(objectID),
                      let object = snapshot.objects[objectID] else { continue }

                candidates.append((object, layerIndex, objectIndex))
            }
        }

        // Sort by layer order (already mostly sorted)
        candidates.sort { a, b in
            if a.layerIndex != b.layerIndex {
                return a.layerIndex > b.layerIndex
            }
            return a.objectIndex > b.objectIndex
        }

        // Test candidates in order
        for candidate in candidates {
            if testFunction(candidate.object, point) {
                return candidate.object
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    private func cellsForBounds(_ bounds: CGRect) -> Set<GridCell> {
        let minX = Int(floor(bounds.minX / gridSize))
        let maxX = Int(floor(bounds.maxX / gridSize))
        let minY = Int(floor(bounds.minY / gridSize))
        let maxY = Int(floor(bounds.maxY / gridSize))

        var cells = Set<GridCell>()
        cells.reserveCapacity((maxX - minX + 1) * (maxY - minY + 1))

        for x in minX...maxX {
            for y in minY...maxY {
                cells.insert(GridCell(x: x, y: y))
            }
        }

        return cells
    }

    /// Debug information
    var debugInfo: String {
        let totalCells = grid.count
        let totalObjects = objectBounds.count
        let avgObjectsPerCell = grid.isEmpty ? 0 : grid.values.reduce(0, { $0 + $1.count }) / grid.count

        return """
        SpatialIndex Debug:
        - Grid size: \(gridSize)x\(gridSize)
        - Active cells: \(totalCells)
        - Indexed objects: \(totalObjects)
        - Avg objects/cell: \(avgObjectsPerCell)
        """
    }
}