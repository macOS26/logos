import SwiftUI
import Combine

extension VectorDocument {
    func makeClippingMaskFromSelection() {
        guard let layerIndex = selectedLayerIndex else { return }

        let selectedObjects = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }
        let selectedShapes = selectedObjects.compactMap { unifiedObject -> VectorShape? in
            if case .shape(let shape) = unifiedObject.objectType {
                return shape
            }
            return nil
        }

        guard selectedShapes.count >= 2 else { return }
        saveToUndoStack()

        guard let maskID = selectedShapes.last?.id else { return }

        let shapes = getShapesForLayer(layerIndex)
        if let idx = shapes.firstIndex(where: { $0.id == maskID }),
           var maskShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: idx) {
            maskShape.isClippingPath = true
            setShapeAtIndex(layerIndex: layerIndex, shapeIndex: idx, shape: maskShape)
        }

        for s in selectedShapes.dropLast() {
            let shapes = getShapesForLayer(layerIndex)
            if let i = shapes.firstIndex(where: { $0.id == s.id }),
               var clippedShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: i) {
                clippedShape.clippedByShapeID = maskID
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: i, shape: clippedShape)
            }
        }

        if let maskUnifiedObject = findObject(by: maskID) {
            selectedObjectIDs = [maskUnifiedObject.id]
            syncSelectionArrays()
        }

        for (idx, _) in layers.enumerated() {
            _ = getShapesForLayer(idx)
        }

        forceResyncUnifiedObjects()

        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if shape.id == maskID {
                } else if selectedShapes.dropLast().contains(where: { $0.id == shape.id }) {
                }
            }
        }
    }

    func releaseClippingMaskForSelection() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()

        let selectedObjects = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }
        let selectedShapes = selectedObjects.compactMap { unifiedObject -> VectorShape? in
            if case .shape(let shape) = unifiedObject.objectType {
                return shape
            }
            return nil
        }

        let maskIDsToRelease: Set<UUID> = Set(selectedShapes.filter { $0.isClippingPath }.map { $0.id })

        for s in selectedShapes {
            let shapes = getShapesForLayer(layerIndex)
            if let i = shapes.firstIndex(where: { $0.id == s.id }),
               var shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: i) {
                shape.clippedByShapeID = nil
                if shape.isClippingPath { shape.isClippingPath = false }
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: i, shape: shape)
            }
        }

        if !maskIDsToRelease.isEmpty {
            let shapes = getShapesForLayer(layerIndex)
            for (idx, shape) in shapes.enumerated() {
                if let clipID = shape.clippedByShapeID, maskIDsToRelease.contains(clipID) {
                    var updatedShape = shape
                    updatedShape.clippedByShapeID = nil

                    if ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                        updatedShape.updateBounds()
                    }
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: idx, shape: updatedShape)
                }
            }
            for (idx, shape) in shapes.enumerated() {
                if maskIDsToRelease.contains(shape.id) {
                    var updatedShape = shape
                    updatedShape.isClippingPath = false
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: idx, shape: updatedShape)
                }
            }
        }

        let allShapes = getShapesForLayer(layerIndex)
        for (idx, shape) in allShapes.enumerated() {
            if shape.clippedByShapeID == nil && (ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil) {
                var updatedShape = shape
                updatedShape.updateBounds()
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: idx, shape: updatedShape)
            }
        }

        forceResyncUnifiedObjects()
    }

    func moveClippingMask(_ maskID: UUID, by offset: CGPoint) {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()

        let shapes = getShapesForLayer(layerIndex)
        guard let maskIndex = shapes.firstIndex(where: { $0.id == maskID }),
              var maskShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: maskIndex) else { return }

        maskShape.transform = maskShape.transform.translatedBy(x: offset.x, y: offset.y)
        setShapeAtIndex(layerIndex: layerIndex, shapeIndex: maskIndex, shape: maskShape)

        moveShapeByPathCoordinates(layerIndex: layerIndex, shapeIndex: maskIndex, by: offset)

        let allShapes = getShapesForLayer(layerIndex)
        for (idx, shape) in allShapes.enumerated() {
            if shape.clippedByShapeID == maskID {
                moveShapeByPathCoordinates(layerIndex: layerIndex, shapeIndex: idx, by: offset)
            }
        }

        forceResyncUnifiedObjects()
    }

    private func moveShapeByPathCoordinates(layerIndex: Int, shapeIndex: Int, by offset: CGPoint) {
        guard var shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }

        if ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
            shape.transform = shape.transform.translatedBy(x: offset.x, y: offset.y)

            var updatedElements: [PathElement] = []
            for element in shape.path.elements {
                switch element {
                case .move(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.move(to: VectorPoint(newPoint)))
                case .line(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.line(to: VectorPoint(newPoint)))
                case .curve(let to, let control1, let control2):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl1 = CGPoint(x: control1.x + offset.x, y: control1.y + offset.y)
                    let newControl2 = CGPoint(x: control2.x + offset.x, y: control2.y + offset.y)
                    updatedElements.append(.curve(
                        to: VectorPoint(newTo),
                        control1: VectorPoint(newControl1),
                        control2: VectorPoint(newControl2)
                    ))
                case .quadCurve(let to, let control):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl = CGPoint(x: control.x + offset.x, y: control.y + offset.y)
                    updatedElements.append(.quadCurve(
                        to: VectorPoint(newTo),
                        control: VectorPoint(newControl)
                    ))
                case .close:
                    updatedElements.append(.close)
                }
            }
            shape.path = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)
        } else {
            var updatedElements: [PathElement] = []
            for element in shape.path.elements {
                switch element {
                case .move(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.move(to: VectorPoint(newPoint)))
                case .line(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.line(to: VectorPoint(newPoint)))
                case .curve(let to, let control1, let control2):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl1 = CGPoint(x: control1.x + offset.x, y: control1.y + offset.y)
                    let newControl2 = CGPoint(x: control2.x + offset.x, y: control2.y + offset.y)
                    updatedElements.append(.curve(
                        to: VectorPoint(newTo),
                        control1: VectorPoint(newControl1),
                        control2: VectorPoint(newControl2)
                    ))
                case .quadCurve(let to, let control):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl = CGPoint(x: control.x + offset.x, y: control.y + offset.y)
                    updatedElements.append(.quadCurve(
                        to: VectorPoint(newTo),
                        control: VectorPoint(newControl)
                    ))
                case .close:
                    updatedElements.append(.close)
                }
            }
            shape.path = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)
        }

        shape.updateBounds()
        setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
    }

    func isShapeInClippingMask(_ shapeID: UUID) -> Bool {
        if let shape = findShape(by: shapeID) {
            return shape.isClippingPath || shape.clippedByShapeID != nil
        }
        return false
    }

    func getClippingMaskGroup(for maskID: UUID) -> [VectorShape] {
        guard let layerIndex = selectedLayerIndex else { return [] }

        var group: [VectorShape] = []

        if let maskShape = findShape(by: maskID), maskShape.isClippingPath {
            group.append(maskShape)
        }

        let shapes = getShapesForLayer(layerIndex)

        for shape in shapes {
            if shape.clippedByShapeID == maskID {
                group.append(shape)
            }
        }

        return group
    }
}
