
import SwiftUI

extension VectorDocument {


    func groupSelectedObjects() {
        let allSelectedIDs = selectedShapeIDs.union(selectedTextIDs)

        guard let layerIndex = selectedLayerIndex,
              allSelectedIDs.count > 1 else {
            Log.info("❌ GROUPING FAILED: layerIndex=\(selectedLayerIndex?.description ?? "nil") total selected=\(allSelectedIDs.count) (shapes=\(selectedShapeIDs.count) + text=\(selectedTextIDs.count))", category: .general)
            return
        }

        saveToUndoStack()

        let selectedShapes = getShapesForLayer(layerIndex).filter { allSelectedIDs.contains($0.id) }
        Log.info("✅ GROUPING: Found \(selectedShapes.count) shapes to group. Text objects: \(selectedShapes.filter { $0.isTextObject }.count)", category: .general)

        let groupShape = VectorShape.group(from: selectedShapes, name: "Group")
        Log.info("✅ CREATED GROUP: bounds=\(groupShape.bounds) groupBounds=\(groupShape.groupBounds)", category: .general)

        removeShapesUnified(layerIndex: layerIndex, where: { allSelectedIDs.contains($0.id) })

        appendShapeToLayerUnified(layerIndex: layerIndex, shape: groupShape)

        selectedShapeIDs = [groupShape.id]
        selectedTextIDs.removeAll()

        populateUnifiedObjectsFromLayersPreservingOrder()

        selectedObjectIDs = [groupShape.id]

    }

    func flattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }

        saveToUndoStack()

        let selectedShapes = getSelectedShapesInStackingOrder()

        var combinedBounds = CGRect.zero
        for shape in selectedShapes {
            let shapeBounds = shape.bounds
            if combinedBounds == .zero {
                combinedBounds = shapeBounds
            } else {
                combinedBounds = combinedBounds.union(shapeBounds)
            }
        }

        let flattenedShape = VectorShape(
            name: "Flattened Group",
            path: VectorPath(cgPath: CGPath(rect: combinedBounds, transform: nil)),
            strokeStyle: nil,
            fillStyle: nil,
            transform: .identity,
            isGroup: true,
            groupedShapes: selectedShapes,
            isCompoundPath: false
        )

        removeSelectedShapes()

        appendShapeToLayerUnified(layerIndex: layerIndex, shape: flattenedShape)
        selectedShapeIDs = [flattenedShape.id]

        populateUnifiedObjectsFromLayersPreservingOrder()

        selectedObjectIDs = [flattenedShape.id]

    }

    func ungroupSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              !selectedShapeIDs.isEmpty else { return }

        saveToUndoStack()

        var newSelectedShapeIDs: Set<UUID> = []
        var shapesToRemove: [UUID] = []
        var shapesToAdd: [VectorShape] = []

        for shapeID in selectedShapeIDs {
            let shapes = getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
               let shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {

                if shape.isGroupContainer {
                    for groupedShape in shape.groupedShapes {
                        shapesToAdd.append(groupedShape)
                        newSelectedShapeIDs.insert(groupedShape.id)
                    }

                    shapesToRemove.append(shapeID)

                } else {
                    newSelectedShapeIDs.insert(shapeID)
                }
            }
        }

        removeShapesUnified(layerIndex: layerIndex, where: { shapesToRemove.contains($0.id) })

        for shape in shapesToAdd {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }

        selectedShapeIDs = newSelectedShapeIDs

        populateUnifiedObjectsFromLayersPreservingOrder()

        selectedObjectIDs = newSelectedShapeIDs

    }

    func unflattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }

        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }) else { return }

        guard let flattenedGroup = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }

        guard flattenedGroup.isGroup && !flattenedGroup.groupedShapes.isEmpty else { return }

        saveToUndoStack()

        let restoredShapes = flattenedGroup.groupedShapes
        var newSelectedIDs: Set<UUID> = []

        var shapesToAdd: [VectorShape] = []
        for originalShape in restoredShapes {
            var restoredShape = originalShape
            restoredShape.id = UUID()
            shapesToAdd.append(restoredShape)
            newSelectedIDs.insert(restoredShape.id)
        }

        removeShapeAtIndexUnified(layerIndex: layerIndex, shapeIndex: shapeIndex)

        for shape in shapesToAdd {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }
        selectedShapeIDs = newSelectedIDs

        populateUnifiedObjectsFromLayersPreservingOrder()

        selectedObjectIDs = newSelectedIDs

    }


    func makeCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }

        saveToUndoStack()

        let selectedShapes = getSelectedShapesInStackingOrder()

        let compoundPath = CGMutablePath()
        for shape in selectedShapes {
            compoundPath.addPath(shape.path.cgPath)
        }

        let compoundShape = VectorShape(
            name: "Compound Path",
            path: VectorPath(cgPath: compoundPath, fillRule: .evenOdd),
            strokeStyle: selectedShapes.last?.strokeStyle,
            fillStyle: selectedShapes.last?.fillStyle,
            transform: .identity,
            isCompoundPath: true
        )

        removeSelectedShapes()

        appendShapeToLayerUnified(layerIndex: layerIndex, shape: compoundShape)
        selectedShapeIDs = [compoundShape.id]

        populateUnifiedObjectsFromLayersPreservingOrder()

        selectedObjectIDs = [compoundShape.id]

    }

    func makeLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }

        saveToUndoStack()

        let selectedShapes = getSelectedShapesInStackingOrder()

        let loopingPath = CGMutablePath()
        for shape in selectedShapes {
            loopingPath.addPath(shape.path.cgPath)
        }

        let loopingShape = VectorShape(
            name: "Looping Path",
            path: VectorPath(cgPath: loopingPath, fillRule: .winding),
            strokeStyle: selectedShapes.last?.strokeStyle,
            fillStyle: selectedShapes.last?.fillStyle,
            transform: .identity,
            isCompoundPath: true
        )

        removeSelectedShapes()

        appendShapeToLayerUnified(layerIndex: layerIndex, shape: loopingShape)
        selectedShapeIDs = [loopingShape.id]

        populateUnifiedObjectsFromLayersPreservingOrder()

        selectedObjectIDs = [loopingShape.id]

    }

    func releaseCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }

        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }),
              let compoundShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              compoundShape.isTrueCompoundPath else { return }

        saveToUndoStack()

        let subpaths = extractSubpaths(from: compoundShape.path.cgPath)

        var newShapes: [VectorShape] = []
        var newSelectedIDs: Set<UUID> = []

        for (index, subpath) in subpaths.enumerated() {
            let individualShape = VectorShape(
                name: "Path \(index + 1)",
                path: VectorPath(cgPath: subpath),
                strokeStyle: compoundShape.strokeStyle,
                fillStyle: compoundShape.fillStyle,
                transform: compoundShape.transform,
                isCompoundPath: false
            )
            newShapes.append(individualShape)
            newSelectedIDs.insert(individualShape.id)
        }

        removeShapeAtIndexUnified(layerIndex: layerIndex, shapeIndex: shapeIndex)

        for shape in newShapes {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }
        selectedShapeIDs = newSelectedIDs

        populateUnifiedObjectsFromLayersPreservingOrder()

        selectedObjectIDs = newSelectedIDs

    }

    func releaseLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }

        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }),
              let loopingShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              loopingShape.isTrueLoopingPath else { return }

        saveToUndoStack()

        let subpaths = extractSubpaths(from: loopingShape.path.cgPath)

        var newShapes: [VectorShape] = []
        var newSelectedIDs: Set<UUID> = []

        for (index, subpath) in subpaths.enumerated() {
            let individualShape = VectorShape(
                name: "Path \(index + 1)",
                path: VectorPath(cgPath: subpath),
                strokeStyle: loopingShape.strokeStyle,
                fillStyle: loopingShape.fillStyle,
                transform: loopingShape.transform,
                isCompoundPath: false
            )
            newShapes.append(individualShape)
            newSelectedIDs.insert(individualShape.id)
        }

        removeShapeAtIndexUnified(layerIndex: layerIndex, shapeIndex: shapeIndex)

        for shape in newShapes {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }
        selectedShapeIDs = newSelectedIDs

        populateUnifiedObjectsFromLayersPreservingOrder()

        selectedObjectIDs = newSelectedIDs

    }

    private func extractSubpaths(from cgPath: CGPath) -> [CGPath] {
        var subpaths: [CGPath] = []
        var currentPath = CGMutablePath()

        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee

            switch element.type {
            case .moveToPoint:
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = CGMutablePath()
                }
                currentPath.move(to: element.points[0])

            case .addLineToPoint:
                currentPath.addLine(to: element.points[0])

            case .addQuadCurveToPoint:
                currentPath.addQuadCurve(to: element.points[1], control: element.points[0])

            case .addCurveToPoint:
                currentPath.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])

            case .closeSubpath:
                currentPath.closeSubpath()

            @unknown default:
                break
            }
        }

        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }

        return subpaths
    }
}
