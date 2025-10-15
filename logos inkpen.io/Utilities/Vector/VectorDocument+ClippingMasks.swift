import SwiftUI
import Combine

extension VectorDocument {
    func makeClippingMaskFromSelection() {
        let selectedShapes = getSelectedShapesInStackingOrder()
        guard selectedShapes.count >= 2 else { return }

        // Create a clipping group: first/top shape is the clipping mask
        var shapesInOrder = selectedShapes
        let maskShape = shapesInOrder.removeFirst()  // First shape is the mask (top object)
        let contentShapes = shapesInOrder  // Rest are content
        let groupShapes = [maskShape] + contentShapes  // Mask is first in group

        // Create the clipping group
        let clippingGroup = VectorShape.group(from: groupShapes, name: "Clipping Group", isClippingGroup: true)

        // Use existing group command
        groupSelectedObjects()

        // Update the group to be a clipping group
        if let groupIndex = unifiedObjects.firstIndex(where: { $0.id == clippingGroup.id || selectedObjectIDs.contains($0.id) }),
           case .shape(var group) = unifiedObjects[groupIndex].objectType,
           group.isGroup {
            group.isClippingGroup = true
            group.name = "Clipping Group"
            unifiedObjects[groupIndex] = VectorObject(
                shape: group,
                layerIndex: unifiedObjects[groupIndex].layerIndex,
                orderID: unifiedObjects[groupIndex].orderID
            )
        }

        forceResyncUnifiedObjects()
    }

    func releaseClippingMaskForSelection() {
        // Just ungroup - much simpler with clipping groups!
        ungroupSelectedObjects()
    }

    func moveClippingMask(_ maskID: UUID, by offset: CGPoint) {
        guard let layerIndex = selectedLayerIndex else { return }

        let shapes = getShapesForLayer(layerIndex)
        guard let maskIndex = shapes.firstIndex(where: { $0.id == maskID }),
              var maskShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: maskIndex) else { return }

        // Capture old state
        var oldShapes: [UUID: VectorShape] = [:]
        var clippedShapeIDs: [UUID] = []
        oldShapes[maskID] = maskShape
        for shape in shapes {
            if shape.clippedByShapeID == maskID {
                oldShapes[shape.id] = shape
                clippedShapeIDs.append(shape.id)
            }
        }

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

        // Capture new state and create command
        var newShapes: [UUID: VectorShape] = [:]
        if let shape = findShape(by: maskID) {
            newShapes[maskID] = shape
        }
        for shapeID in clippedShapeIDs {
            if let shape = findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }
        let command = ClippingMaskCommand(operation: .moveClippingMask(
            maskID: maskID,
            clippedShapeIDs: clippedShapeIDs,
            offset: offset,
            oldShapes: oldShapes,
            newShapes: newShapes
        ))
        commandManager.execute(command)
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
