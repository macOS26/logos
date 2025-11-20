import SwiftUI
import Combine

extension VectorDocument {

    func updateShapeFillColorInUnified(id: UUID, color: VectorColor) {
        // Check if this is a group with memberIDs - update members separately
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    // Modern group: update each member shape
                    for memberID in shape.memberIDs {
                        updateShapeFillColorInUnified(id: memberID, color: color)
                    }
                    return
                }
            default:
                break
            }
        }

        updateShapeByID(id) { shape in
            // Update the shape itself
            if shape.fillStyle == nil {
                shape.fillStyle = FillStyle(color: color, opacity: defaultFillOpacity)
            } else {
                shape.fillStyle?.color = color
            }

            // If this is a legacy group with embedded children, update them
            if shape.isGroupContainer && !shape.groupedShapes.isEmpty {
                var updatedChildren: [VectorShape] = []
                for var childShape in shape.groupedShapes {
                    if childShape.fillStyle == nil {
                        childShape.fillStyle = FillStyle(color: color, opacity: defaultFillOpacity)
                    } else {
                        childShape.fillStyle?.color = color
                    }
                    updatedChildren.append(childShape)
                }
                shape.groupedShapes = updatedChildren
            }
        }
    }

    func updateShapeStrokeColorInUnified(id: UUID, color: VectorColor) {
        // Check if this is a group with memberIDs - update members separately
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    // Modern group: update each member shape
                    for memberID in shape.memberIDs {
                        updateShapeStrokeColorInUnified(id: memberID, color: color)
                    }
                    return
                }
            default:
                break
            }
        }

        updateShapeByID(id) { shape in
            // Update the shape itself
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: color, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: defaultStrokeOpacity)
            } else {
                shape.strokeStyle?.color = color
            }

            // If this is a legacy group with embedded children, update them
            if shape.isGroupContainer && !shape.groupedShapes.isEmpty {
                var updatedChildren: [VectorShape] = []
                for var childShape in shape.groupedShapes {
                    if childShape.strokeStyle == nil {
                        childShape.strokeStyle = StrokeStyle(color: color, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        childShape.strokeStyle?.color = color
                    }
                    updatedChildren.append(childShape)
                }
                shape.groupedShapes = updatedChildren
            }
        }
    }

    func updateShapeFillOpacityInUnified(id: UUID, opacity: Double) {
        // Check if this is a group with memberIDs - update members separately
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeFillOpacityInUnified(id: memberID, opacity: opacity)
                    }
                    return
                }
            default:
                break
            }
        }

        updateShapeByID(id) { shape in
            if shape.fillStyle == nil {
                shape.fillStyle = FillStyle(color: defaultFillColor, opacity: opacity)
            } else {
                shape.fillStyle?.opacity = opacity
            }
        }
    }

    func updateShapeStrokeWidthInUnified(id: UUID, width: Double) {
        // Check if this is a group with memberIDs - update members separately
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeStrokeWidthInUnified(id: memberID, width: width)
                    }
                    return
                }
            default:
                break
            }
        }

        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: width, placement: strokeDefaults.placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: defaultStrokeOpacity)
            } else {
                shape.strokeStyle?.width = width
            }
        }
    }

    func lockShapeInUnified(id: UUID) {
        updateShapeByID(id) { shape in
            shape.isLocked = true
        }
    }

    func unlockShapeInUnified(id: UUID) {
        updateShapeByID(id) { shape in
            shape.isLocked = false
        }
    }

    func hideShapeInUnified(id: UUID) {
        updateShapeByID(id) { shape in
            shape.isVisible = false
        }
    }

    func showShapeInUnified(id: UUID) {
        updateShapeByID(id) { shape in
            shape.isVisible = true
        }
    }

    func updateShapeStrokeOpacityInUnified(id: UUID, opacity: Double) {
        // Check if this is a group with memberIDs - update members separately
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeStrokeOpacityInUnified(id: memberID, opacity: opacity)
                    }
                    return
                }
            default:
                break
            }
        }

        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: opacity)
            } else {
                shape.strokeStyle?.opacity = opacity
            }
        }
    }

    func updateShapeOpacityInUnified(id: UUID, opacity: Double) {
        // Check if this is a group with memberIDs - update members separately
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeOpacityInUnified(id: memberID, opacity: opacity)
                    }
                    return
                }
            default:
                break
            }
        }

        updateShapeByID(id) { shape in
            shape.opacity = opacity
        }
    }

    func updateShapeStrokePlacementInUnified(id: UUID, placement: StrokePlacement) {
        // Check if this is a group with memberIDs - update members separately
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeStrokePlacementInUnified(id: memberID, placement: placement)
                    }
                    return
                }
            default:
                break
            }
        }

        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: defaultStrokeOpacity)
            } else {
                shape.strokeStyle?.placement = placement
            }
        }

        NotificationCenter.default.post(
            name: Notification.Name("ShapePreviewUpdate"),
            object: nil,
            userInfo: ["shapeID": id, "strokePlacement": placement.rawValue]
        )
    }
}
