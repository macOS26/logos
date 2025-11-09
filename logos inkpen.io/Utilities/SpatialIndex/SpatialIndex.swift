import SwiftUI

/// High-performance spatial index for O(1) hit testing
struct SpatialIndex {
    private let gridSize: CGFloat = 50 // 50x50 pixel cells for finer granularity
    private var grid: [GridCell: Set<UUID>] = [:]
    private var objectBounds: [UUID: CGRect] = [:] // Cache bounds for fast updates

    // Per-layer spatial index cache for O(1) layer lookups
    private var layerGrids: [UUID: [GridCell: [UUID]]] = [:] // layerID -> grid -> objectIDs in order

    struct GridCell: Hashable {
        let x: Int
        let y: Int
    }

    /// Rebuild the entire spatial index from document snapshot
    mutating func rebuild(from snapshot: DocumentSnapshot) {
        grid.removeAll(keepingCapacity: true)
        objectBounds.removeAll(keepingCapacity: true)
        layerGrids.removeAll(keepingCapacity: true)

        // Build set of child IDs that are inside groups - DON'T index these from layer.objectIDs
        // (they have stale bounds in snapshot.objects)
        var groupedChildIDs = Set<UUID>()
        for object in snapshot.objects.values {
            switch object.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                for childShape in groupShape.groupedShapes {
                    groupedChildIDs.insert(childShape.id)
                }
            default:
                break
            }
        }

        // Build per-layer spatial indexes
        for layer in snapshot.layers {
            guard layer.isVisible else { continue }

            var layerGrid: [GridCell: [UUID]] = [:]

            for objectID in layer.objectIDs {
                // SKIP child IDs - they're stale in snapshot.objects, causing phantom hits
                if groupedChildIDs.contains(objectID) { continue }

                guard let object = snapshot.objects[objectID], object.isVisible else { continue }

                // For groups, index BOTH the group AND its children (from groupedShapes, not snapshot.objects)
                if object.shape.isGroupContainer {
                    // Index the GROUP at its groupBounds
                    let groupBounds = object.shape.groupBounds
                    objectBounds[objectID] = groupBounds

                    let groupCells = cellsForBounds(groupBounds)
                    for cell in groupCells {
                        grid[cell, default: []].insert(objectID)
                        layerGrid[cell, default: []].append(objectID)
                    }

                    // ALSO index each child from groupedShapes (correct positions)
                    switch object.objectType {
                    case .group(let groupShape), .clipGroup(let groupShape):
                        for childShape in groupShape.groupedShapes {
                            guard childShape.isVisible else { continue }
                            let childBounds = childShape.bounds.applying(childShape.transform)
                            objectBounds[childShape.id] = childBounds

                            let childCells = cellsForBounds(childBounds)
                            for cell in childCells {
                                grid[cell, default: []].insert(childShape.id)
                                layerGrid[cell, default: []].append(childShape.id)
                            }
                        }
                    default:
                        break
                    }
                } else {
                    // Regular objects (including text) - index normally
                    let bounds: CGRect
                    switch object.objectType {
                    case .text(let shape):
                        // Text uses position + bounds, not transform
                        bounds = CGRect(
                            x: shape.transform.tx,
                            y: shape.transform.ty,
                            width: shape.bounds.width,
                            height: shape.bounds.height
                        )
                    case .shape(let shape),
                         .image(let shape),
                         .warp(let shape),
                         .clipMask(let shape):
                        bounds = shape.bounds.applying(shape.transform)
                    case .group, .clipGroup:
                        // Already handled above
                        continue
                    }

                    objectBounds[objectID] = bounds

                    let cells = cellsForBounds(bounds)
                    for cell in cells {
                        grid[cell, default: []].insert(objectID)
                        layerGrid[cell, default: []].append(objectID)
                    }
                }
            }

            layerGrids[layer.id] = layerGrid
        }
    }

    /// Rebuild spatial index for specific layers only (O(n) where n = objects in those layers)
    mutating func rebuildLayers(_ layerIDs: Set<UUID>, from snapshot: DocumentSnapshot) {
        guard !layerIDs.isEmpty else { return }

        // Remove all objects from these layers from the grids
        for layerID in layerIDs {
            if let layerGrid = layerGrids[layerID] {
                for (cell, objectIDs) in layerGrid {
                    for objectID in objectIDs {
                        grid[cell]?.remove(objectID)
                        if grid[cell]?.isEmpty == true {
                            grid.removeValue(forKey: cell)
                        }
                        objectBounds.removeValue(forKey: objectID)
                    }
                }
            }
            layerGrids.removeValue(forKey: layerID)
        }

        // Build set of child IDs that are inside groups
        var groupedChildIDs = Set<UUID>()
        for object in snapshot.objects.values {
            switch object.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                for childShape in groupShape.groupedShapes {
                    groupedChildIDs.insert(childShape.id)
                }
            default:
                break
            }
        }

        // Rebuild only the specified layers
        for layer in snapshot.layers where layerIDs.contains(layer.id) {
            guard layer.isVisible else { continue }

            var layerGrid: [GridCell: [UUID]] = [:]

            for objectID in layer.objectIDs {
                // SKIP child IDs - they're stale
                if groupedChildIDs.contains(objectID) { continue }

                guard let object = snapshot.objects[objectID], object.isVisible else { continue }

                // For groups, index BOTH the group AND its children
                if object.shape.isGroupContainer {
                    // Index the GROUP at its groupBounds
                    let groupBounds = object.shape.groupBounds
                    objectBounds[objectID] = groupBounds

                    let groupCells = cellsForBounds(groupBounds)
                    for cell in groupCells {
                        grid[cell, default: []].insert(objectID)
                        layerGrid[cell, default: []].append(objectID)
                    }

                    // ALSO index each child from groupedShapes
                    switch object.objectType {
                    case .group(let groupShape), .clipGroup(let groupShape):
                        for childShape in groupShape.groupedShapes {
                            guard childShape.isVisible else { continue }
                            let childBounds = childShape.bounds.applying(childShape.transform)
                            objectBounds[childShape.id] = childBounds

                            let childCells = cellsForBounds(childBounds)
                            for cell in childCells {
                                grid[cell, default: []].insert(childShape.id)
                                layerGrid[cell, default: []].append(childShape.id)
                            }
                        }
                    default:
                        break
                    }
                } else {
                    // Regular objects (including text)
                    let bounds: CGRect
                    switch object.objectType {
                    case .text(let shape):
                        // Text uses position + bounds, not transform
                        bounds = CGRect(
                            x: shape.transform.tx,
                            y: shape.transform.ty,
                            width: shape.bounds.width,
                            height: shape.bounds.height
                        )
                    case .shape(let shape),
                         .image(let shape),
                         .warp(let shape),
                         .clipMask(let shape):
                        bounds = shape.bounds.applying(shape.transform)
                    case .group, .clipGroup:
                        // Already handled above
                        continue
                    }

                    objectBounds[objectID] = bounds

                    let cells = cellsForBounds(bounds)
                    for cell in cells {
                        grid[cell, default: []].insert(objectID)
                        layerGrid[cell, default: []].append(objectID)
                    }
                }
            }

            layerGrids[layer.id] = layerGrid
        }
    }

    /// Update index for a single object (more efficient than full rebuild)
    mutating func updateObject(_ objectID: UUID, in snapshot: DocumentSnapshot) {
        // Find which layer this object belongs to
        var targetLayerID: UUID?
        for layer in snapshot.layers {
            if layer.objectIDs.contains(objectID) {
                targetLayerID = layer.id
                break
            }
        }

        // Remove old entries from global grid
        if let oldBounds = objectBounds[objectID] {
            let oldCells = cellsForBounds(oldBounds)
            for cell in oldCells {
                grid[cell]?.remove(objectID)
                if grid[cell]?.isEmpty == true {
                    grid.removeValue(forKey: cell)
                }

                // Remove from all layer grids
                for layerID in layerGrids.keys {
                    layerGrids[layerID]?[cell]?.removeAll { $0 == objectID }
                }
            }
        }

        // Add new entries if object exists and is visible
        if let object = snapshot.objects[objectID], object.isVisible, let layerID = targetLayerID {
            let bounds = object.shape.bounds.applying(object.shape.transform)
            objectBounds[objectID] = bounds

            let cells = cellsForBounds(bounds)
            for cell in cells {
                grid[cell, default: []].insert(objectID)
                layerGrids[layerID, default: [:]][cell, default: []].append(objectID)
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

    /// Find the topmost object at a point using per-layer spatial cache (O(1))
    func hitTest(at point: CGPoint, in snapshot: DocumentSnapshot, testFunction: (VectorObject, CGPoint) -> Bool) -> VectorObject? {
        let cell = GridCell(
            x: Int(floor(point.x / gridSize)),
            y: Int(floor(point.y / gridSize))
        )

        // Iterate layers from top to bottom (reversed)
        for layer in snapshot.layers.reversed() {
            guard layer.isVisible else { continue }

            // O(1) lookup in layer's spatial grid
            guard let objectIDs = layerGrids[layer.id]?[cell] else { continue }

            // Test objects in reverse order (top to bottom within layer)
            for objectID in objectIDs.reversed() {
                guard let object = snapshot.objects[objectID] else { continue }

                if testFunction(object, point) {
                    return object
                }
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

    /// Get all cached bounds for debug visualization
    func getAllCachedBounds() -> [UUID: CGRect] {
        return objectBounds
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