import SwiftUI

extension VectorDocument {
    func nudgeSelectedObjects(by nudgeAmount: CGVector) {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        let translationTransform = CGAffineTransform(translationX: nudgeAmount.dx, y: nudgeAmount.dy)

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
                             .clipMask(var shape),
                             .guide(var shape):
                            // For groups with memberIDs (new system), use applyTransformToGroup
                            if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                                applyTransformToGroup(groupID: shape.id, transform: translationTransform)
                            } else if shape.isGroupContainer {
                                // Old groupedShapes system
                                var nudgedGroupedShapes: [VectorShape] = []
                                for var groupedShape in shape.groupedShapes {
                                    groupedShape.path = nudgePath(groupedShape.path, by: nudgeAmount)
                                    groupedShape.updateBounds()
                                    nudgedGroupedShapes.append(groupedShape)
                                }
                                shape.groupedShapes = nudgedGroupedShapes
                                shape.updateBounds()

                                updateEntireShapeInUnified(id: shape.id) { updatedShape in
                                    updatedShape = shape
                                }
                            } else {
                                // Regular shape
                                shape.path = nudgePath(shape.path, by: nudgeAmount)
                                shape.updateBounds()

                                updateEntireShapeInUnified(id: shape.id) { updatedShape in
                                    updatedShape = shape
                                }
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

    /// Helper to nudge all points in a path by the given amount
    private func nudgePath(_ path: VectorPath, by nudgeAmount: CGVector) -> VectorPath {
        var nudgedElements: [PathElement] = []
        for element in path.elements {
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
        return VectorPath(elements: nudgedElements, isClosed: path.isClosed)
    }
}
