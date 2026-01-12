import Foundation
import CoreGraphics

/// Axis options for alignment operations
enum AlignmentAxis {
    case both      // Align X and Y
    case xOnly     // Align X axis only (horizontal)
    case yOnly     // Align Y axis only (vertical)
}

extension VectorDocument {

    /// Align selected objects by their individual transform origins (both axes).
    /// The first selected object stays in place; other objects move to align.
    func alignSelectedObjectsByOrigin() {
        alignSelectedObjectsByOrigin(axis: .both)
    }

    /// Align selected objects horizontally by their transform origins (X axis only).
    /// The first selected object stays in place; other objects move horizontally to align.
    func alignSelectedObjectsByOriginX() {
        alignSelectedObjectsByOrigin(axis: .xOnly)
    }

    /// Align selected objects vertically by their transform origins (Y axis only).
    /// The first selected object stays in place; other objects move vertically to align.
    func alignSelectedObjectsByOriginY() {
        alignSelectedObjectsByOrigin(axis: .yOnly)
    }

    /// Internal helper for alignment with axis control
    private func alignSelectedObjectsByOrigin(axis: AlignmentAxis) {
        let orderedIDs = viewState.orderedSelectedObjectIDs
        guard orderedIDs.count >= 2 else { return }

        // Get the anchor object (first selected)
        guard let anchorID = orderedIDs.first,
              let anchorObj = snapshot.objects[anchorID] else { return }

        let anchorShape = anchorObj.shape
        let anchorOrigin = anchorShape.transformOrigin ?? .center
        let anchorBounds = anchorShape.isGroupContainer ? anchorShape.groupBounds : anchorShape.bounds

        // Calculate anchor point position
        let anchorPoint = CGPoint(
            x: anchorBounds.minX + anchorBounds.width * anchorOrigin.point.x,
            y: anchorBounds.minY + anchorBounds.height * anchorOrigin.point.y
        )

        // Move other objects to align their origins with anchor point
        modifySelectedShapesWithUndo(
            preCapture: {
                for objectID in orderedIDs.dropFirst() {
                    guard let obj = snapshot.objects[objectID] else { continue }
                    var shape = obj.shape
                    let shapeOrigin = shape.transformOrigin ?? .center
                    let shapeBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds

                    // Calculate current origin point position
                    let currentOriginPoint = CGPoint(
                        x: shapeBounds.minX + shapeBounds.width * shapeOrigin.point.x,
                        y: shapeBounds.minY + shapeBounds.height * shapeOrigin.point.y
                    )

                    // Calculate offset needed to align based on axis
                    let offsetX: CGFloat
                    let offsetY: CGFloat

                    switch axis {
                    case .both:
                        offsetX = anchorPoint.x - currentOriginPoint.x
                        offsetY = anchorPoint.y - currentOriginPoint.y
                    case .xOnly:
                        offsetX = anchorPoint.x - currentOriginPoint.x
                        offsetY = 0
                    case .yOnly:
                        offsetX = 0
                        offsetY = anchorPoint.y - currentOriginPoint.y
                    }

                    // Skip if no movement needed
                    guard abs(offsetX) > 0.001 || abs(offsetY) > 0.001 else { continue }

                    // Move the shape by translating all path points
                    if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                        // Modern groups with memberIDs - use applyTransformToGroup
                        let translationTransform = CGAffineTransform(translationX: offsetX, y: offsetY)
                        applyTransformToGroup(groupID: shape.id, transform: translationTransform)
                        // applyTransformToGroup handles all updates, so continue
                        continue
                    } else if shape.isGroupContainer {
                        // Legacy groups with embedded groupedShapes
                        for i in shape.groupedShapes.indices {
                            var groupedShape = shape.groupedShapes[i]
                            translateShapePath(&groupedShape, dx: offsetX, dy: offsetY)
                            shape.groupedShapes[i] = groupedShape
                        }
                        shape.updateBounds()
                    } else if shape.typography != nil {
                        // Move text by updating position
                        if let pos = shape.textPosition {
                            shape.textPosition = CGPoint(x: pos.x + offsetX, y: pos.y + offsetY)
                            shape.transform = CGAffineTransform(translationX: shape.textPosition!.x, y: shape.textPosition!.y)
                        }
                    } else {
                        // Move regular shape
                        translateShapePath(&shape, dx: offsetX, dy: offsetY)
                    }

                    // Update in document (for legacy groups, text, and regular shapes)
                    updateShapeByID(objectID, silent: false) { s in
                        s = shape
                    }
                }
            }
        )
    }

    /// Helper to translate all points in a shape's path
    private func translateShapePath(_ shape: inout VectorShape, dx: CGFloat, dy: CGFloat) {
        var translatedElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                translatedElements.append(.move(to: VectorPoint(CGPoint(x: to.x + dx, y: to.y + dy))))
            case .line(let to):
                translatedElements.append(.line(to: VectorPoint(CGPoint(x: to.x + dx, y: to.y + dy))))
            case .curve(let to, let control1, let control2):
                translatedElements.append(.curve(
                    to: VectorPoint(CGPoint(x: to.x + dx, y: to.y + dy)),
                    control1: VectorPoint(CGPoint(x: control1.x + dx, y: control1.y + dy)),
                    control2: VectorPoint(CGPoint(x: control2.x + dx, y: control2.y + dy))
                ))
            case .quadCurve(let to, let control):
                translatedElements.append(.quadCurve(
                    to: VectorPoint(CGPoint(x: to.x + dx, y: to.y + dy)),
                    control: VectorPoint(CGPoint(x: control.x + dx, y: control.y + dy))
                ))
            case .close:
                translatedElements.append(.close)
            }
        }
        shape.path = VectorPath(elements: translatedElements)
        shape.updateBounds()
    }
}
