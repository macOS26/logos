import SwiftUI

extension VectorDocument {
    func nudgeSelectedObjects(by nudgeAmount: CGVector) {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for objectID in viewState.selectedObjectIDs {
            if let shape = findShape(by: objectID) {
                oldShapes[objectID] = shape
                objectIDs.append(objectID)
            }
        }

        for objectID in viewState.selectedObjectIDs {
            if let unifiedObject = findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(var shape),
                     .image(var shape),
                     .warp(var shape),
                     .group(var shape),
                     .clipGroup(var shape),
                     .clipMask(var shape):
                    if shape.isGroupContainer {
                        var nudgedGroupedShapes: [VectorShape] = []
                        for var groupedShape in shape.groupedShapes {
                            var nudgedElements: [PathElement] = []
                            for element in groupedShape.path.elements {
                                switch element {
                                case .move(let to, let type):
                                    nudgedElements.append(.move(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy), pointType: type))
                                case .line(let to, let type):
                                    nudgedElements.append(.line(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy), pointType: type))
                                case .curve(let to, let c1, let c2, let type):
                                    nudgedElements.append(.curve(
                                        to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                        control1: VectorPoint(c1.x + nudgeAmount.dx, c1.y + nudgeAmount.dy),
                                        control2: VectorPoint(c2.x + nudgeAmount.dx, c2.y + nudgeAmount.dy),
                                        pointType: type
                                    ))
                                case .quadCurve(let to, let c, let type):
                                    nudgedElements.append(.quadCurve(
                                        to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                        control: VectorPoint(c.x + nudgeAmount.dx, c.y + nudgeAmount.dy),
                                        pointType: type
                                    ))
                                case .close:
                                    nudgedElements.append(.close)
                                }
                            }
                            groupedShape.path = VectorPath(elements: nudgedElements, isClosed: groupedShape.path.isClosed)
                            groupedShape.updateBounds()
                            nudgedGroupedShapes.append(groupedShape)
                        }
                        shape.groupedShapes = nudgedGroupedShapes
                        shape.updateBounds()
                    } else {
                        var nudgedElements: [PathElement] = []
                        for element in shape.path.elements {
                            switch element {
                            case .move(let to, let type):
                                nudgedElements.append(.move(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy), pointType: type))
                            case .line(let to, let type):
                                nudgedElements.append(.line(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy), pointType: type))
                            case .curve(let to, let c1, let c2, let type):
                                nudgedElements.append(.curve(
                                    to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                    control1: VectorPoint(c1.x + nudgeAmount.dx, c1.y + nudgeAmount.dy),
                                    control2: VectorPoint(c2.x + nudgeAmount.dx, c2.y + nudgeAmount.dy),
                                    pointType: type
                                ))
                            case .quadCurve(let to, let c, let type):
                                nudgedElements.append(.quadCurve(
                                    to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                    control: VectorPoint(c.x + nudgeAmount.dx, c.y + nudgeAmount.dy),
                                    pointType: type
                                ))
                            case .close:
                                nudgedElements.append(.close)
                            }
                        }
                        shape.path = VectorPath(elements: nudgedElements, isClosed: shape.path.isClosed)
                        shape.updateBounds()
                    }

                    updateEntireShapeInUnified(id: shape.id) { updatedShape in
                        updatedShape = shape
                    }
                case .text:
                    break
                }
            }
        }

        viewState.objectPositionUpdateTrigger.toggle()

        for objectID in objectIDs {
            if let updatedShape = findShape(by: objectID) {
                newShapes[objectID] = updatedShape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            commandManager.execute(command)
        }
    }
}
