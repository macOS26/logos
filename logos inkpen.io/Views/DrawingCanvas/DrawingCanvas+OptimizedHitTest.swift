import SwiftUI

extension DrawingCanvas {

    /// Optimized hit testing that uses O(1) UUID lookups instead of building arrays
    internal func findObjectAtLocationOptimized(_ location: CGPoint) -> VectorObject? {
        let validatedLocation = validateAndCorrectLocation(location)

        // Iterate layers from top to bottom (reversed for hit testing)
        for layer in document.snapshot.layers.reversed() {
            // Skip invisible or locked layers
            if !layer.isVisible || layer.isLocked { continue }

            // Iterate objects in layer from top to bottom
            for objectID in layer.objectIDs.reversed() {
                // O(1) dictionary lookup instead of array iteration!
                guard let object = document.snapshot.objects[objectID] else { continue }

                // Skip invisible objects
                if !object.isVisible { continue }

                // Skip background shapes
                let shape = object.shape
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    continue
                }

                // Perform hit test based on object type
                var isHit = false

                switch object.objectType {
                case .text(let textShape):
                    // Text hit test using transform position
                    let textPos = CGPoint(x: textShape.transform.tx, y: textShape.transform.ty)
                    let textBounds = CGRect(
                        x: textPos.x,
                        y: textPos.y,
                        width: textShape.bounds.width,
                        height: textShape.bounds.height
                    )
                    isHit = textBounds.contains(validatedLocation)

                case .shape(let shape), .warp(let shape), .group(let shape),
                     .clipGroup(let shape), .clipMask(let shape):
                    // Shape hit test
                    if shape.clippedByShapeID != nil {
                        isHit = false
                    } else {
                        isHit = performShapeHitTest(shape: shape, at: validatedLocation)
                    }
                }

                // Return first hit (topmost object)
                if isHit {
                    return object
                }
            }
        }

        return nil
    }

    /// Virtual spatial index for even faster hit testing (future optimization)
    struct SpatialIndex {
        private let gridSize: CGFloat = 100 // 100x100 pixel cells
        private var grid: [GridCell: Set<UUID>] = [:]

        struct GridCell: Hashable {
            let x: Int
            let y: Int
        }

        mutating func rebuild(from snapshot: DocumentSnapshot) {
            grid.removeAll()

            for (id, object) in snapshot.objects {
                guard object.isVisible else { continue }

                let bounds = object.shape.bounds.applying(object.shape.transform)
                let cells = cellsForBounds(bounds)

                for cell in cells {
                    grid[cell, default: []].insert(id)
                }
            }
        }

        func candidateObjects(at point: CGPoint, in snapshot: DocumentSnapshot) -> [VectorObject] {
            let cell = GridCell(
                x: Int(point.x / gridSize),
                y: Int(point.y / gridSize)
            )

            guard let objectIDs = grid[cell] else { return [] }

            return objectIDs.compactMap { snapshot.objects[$0] }
        }

        private func cellsForBounds(_ bounds: CGRect) -> [GridCell] {
            let minX = Int(bounds.minX / gridSize)
            let maxX = Int(bounds.maxX / gridSize)
            let minY = Int(bounds.minY / gridSize)
            let maxY = Int(bounds.maxY / gridSize)

            var cells: [GridCell] = []
            for x in minX...maxX {
                for y in minY...maxY {
                    cells.append(GridCell(x: x, y: y))
                }
            }
            return cells
        }
    }
}