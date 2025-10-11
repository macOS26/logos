
import SwiftUI
import Combine

extension VectorDocument {


    func outlineSelectedStrokes() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()

        let shapesToOutline = getShapesForLayer(layerIndex).filter { selectedShapeIDs.contains($0.id) && $0.strokeStyle != nil }
        var newShapeIDs: Set<UUID> = []
        var originalShapeIDs: Set<UUID> = []

        for shape in shapesToOutline {
            guard let strokeStyle = shape.strokeStyle,
                  PathOperations.canOutlineStroke(path: shape.path.cgPath, strokeStyle: strokeStyle) else {
                continue
            }

            if let outlinedPath = PathOperations.outlineStroke(
                path: shape.path.cgPath,
                strokeStyle: strokeStyle
            ) {
                var strokeShape = VectorShape(
                    name: "\(shape.name) Stroke",
                    path: VectorPath(cgPath: outlinedPath),
                    strokeStyle: nil,
                    fillStyle: FillStyle(
                        color: strokeStyle.color,
                        opacity: strokeStyle.opacity,
                        blendMode: strokeStyle.blendMode
                    )
                )

                strokeShape.transform = shape.transform
                strokeShape.opacity = shape.opacity
                strokeShape.isVisible = shape.isVisible
                strokeShape.isLocked = shape.isLocked
                strokeShape.updateBounds()

                if shape.fillStyle != nil && shape.fillStyle?.color != .clear {
                    var fillShape = shape
                    fillShape.strokeStyle = nil
                    fillShape.name = "\(shape.name) Fill"
                    fillShape.updateBounds()

                    let shapes = getShapesForLayer(layerIndex)
                    if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {
                        setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: fillShape)
                        originalShapeIDs.insert(fillShape.id)

                        insertShapeUnified(layerIndex: layerIndex, shape: strokeShape, at: shapeIndex + 1)
                        addShapeToUnifiedSystem(strokeShape, layerIndex: layerIndex)
                        newShapeIDs.insert(strokeShape.id)
                    }
                } else {
                    let shapes = getShapesForLayer(layerIndex)
                    if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {
                        setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: strokeShape)
                        addShapeToUnifiedSystem(strokeShape, layerIndex: layerIndex)
                        newShapeIDs.insert(strokeShape.id)
                    }
                }
            }
        }

        selectedObjectIDs = newShapeIDs

        updateUnifiedObjectsOptimized()

        objectWillChange.send()
    }

    var canOutlineStrokes: Bool {
        guard let layerIndex = selectedLayerIndex else { return false }

        let shapesWithStrokes = getShapesForLayer(layerIndex).filter {
            selectedShapeIDs.contains($0.id) && $0.strokeStyle != nil
        }

        return !shapesWithStrokes.isEmpty && shapesWithStrokes.allSatisfy { shape in
            guard let strokeStyle = shape.strokeStyle else { return false }
            return PathOperations.canOutlineStroke(path: shape.path.cgPath, strokeStyle: strokeStyle)
        }
    }

    var outlineableStrokesCount: Int {
        guard let layerIndex = selectedLayerIndex else { return 0 }

        return getShapesForLayer(layerIndex).filter { shape in
            selectedShapeIDs.contains(shape.id) &&
            shape.strokeStyle != nil &&
            PathOperations.canOutlineStroke(path: shape.path.cgPath, strokeStyle: shape.strokeStyle!)
        }.count
    }
}
