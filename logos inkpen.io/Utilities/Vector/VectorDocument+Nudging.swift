import SwiftUI

extension VectorDocument {
    func nudgeSelectedObjects(by nudgeAmount: CGVector) {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        modifySelectedShapesWithUndo(
            preCapture: {
                for objectID in viewState.selectedObjectIDs {
                    if let vectorObject = findObject(by: objectID) {
                        switch vectorObject.objectType {
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
                                        case .move(let to):
                                            nudgedElements.append(.move(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                                        case .line(let to):
                                            nudgedElements.append(.line(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                                        case .curve(let to, let c1, let c2):
                                            nudgedElements.append(.curve(
                                                to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                                control1: VectorPoint(c1.x + nudgeAmount.dx, c1.y + nudgeAmount.dy),
                                                control2: VectorPoint(c2.x + nudgeAmount.dx, c2.y + nudgeAmount.dy)
                                            ))
                                        case .quadCurve(let to, let c):
                                            nudgedElements.append(.quadCurve(
                                                to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                                control: VectorPoint(c.x + nudgeAmount.dx, c.y + nudgeAmount.dy)
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
                                    case .move(let to):
                                        nudgedElements.append(.move(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                                    case .line(let to):
                                        nudgedElements.append(.line(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                                    case .curve(let to, let c1, let c2):
                                        nudgedElements.append(.curve(
                                            to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                            control1: VectorPoint(c1.x + nudgeAmount.dx, c1.y + nudgeAmount.dy),
                                            control2: VectorPoint(c2.x + nudgeAmount.dx, c2.y + nudgeAmount.dy)
                                        ))
                                    case .quadCurve(let to, let c):
                                        nudgedElements.append(.quadCurve(
                                            to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                            control: VectorPoint(c.x + nudgeAmount.dx, c.y + nudgeAmount.dy)
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
            }
        )
    }
}
