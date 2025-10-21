import SwiftUI
import Combine

extension VectorDocument {

    func updateShapeFillColorInUnified(id: UUID, color: VectorColor) {
        print("🔴 UPDATE FILL: Called for shape \(id), color=\(color)")
        updateShapeByID(id) { shape in
            print("🔴 UPDATE FILL: Found shape, isGroupContainer=\(shape.isGroupContainer)")
            // Update the shape itself
            if shape.fillStyle == nil {
                shape.fillStyle = FillStyle(color: color, opacity: defaultFillOpacity)
            } else {
                shape.fillStyle?.color = color
            }

            // If this is a group, update all children
            if shape.isGroupContainer {
                print("🔴 UPDATE FILL: Updating \(shape.groupedShapes.count) children")
                var updatedChildren: [VectorShape] = []
                for var childShape in shape.groupedShapes {
                    print("🔴 UPDATE FILL: Updating child \(childShape.id)")
                    if childShape.fillStyle == nil {
                        childShape.fillStyle = FillStyle(color: color, opacity: defaultFillOpacity)
                    } else {
                        childShape.fillStyle?.color = color
                    }
                    updatedChildren.append(childShape)
                }
                shape.groupedShapes = updatedChildren
                print("🔴 UPDATE FILL: Updated children saved back to group")
            }
            print("🔴 UPDATE FILL: Updated shape saved to snapshot")
        }
    }

    func updateShapeStrokeColorInUnified(id: UUID, color: VectorColor) {
        print("🟠 UPDATE STROKE: Called for shape \(id), color=\(color)")
        updateShapeByID(id) { shape in
            print("🟠 UPDATE STROKE: Found shape, isGroupContainer=\(shape.isGroupContainer)")
            // Update the shape itself
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: color, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: defaultStrokeOpacity)
            } else {
                shape.strokeStyle?.color = color
            }

            // If this is a group, update all children
            if shape.isGroupContainer {
                print("🟠 UPDATE STROKE: Updating \(shape.groupedShapes.count) children")
                var updatedChildren: [VectorShape] = []
                for var childShape in shape.groupedShapes {
                    print("🟠 UPDATE STROKE: Updating child \(childShape.id)")
                    if childShape.strokeStyle == nil {
                        childShape.strokeStyle = StrokeStyle(color: color, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        childShape.strokeStyle?.color = color
                    }
                    updatedChildren.append(childShape)
                }
                shape.groupedShapes = updatedChildren
                print("🟠 UPDATE STROKE: Updated children saved back to group")
            }
            print("🟠 UPDATE STROKE: Updated shape saved to snapshot")
        }
    }

    func updateShapeFillOpacityInUnified(id: UUID, opacity: Double) {
        updateShapeByID(id) { shape in
            if shape.fillStyle == nil {
                shape.fillStyle = FillStyle(color: defaultFillColor, opacity: opacity)
            } else {
                shape.fillStyle?.opacity = opacity
            }
        }
    }

    func updateShapeStrokeWidthInUnified(id: UUID, width: Double) {
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
        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: opacity)
            } else {
                shape.strokeStyle?.opacity = opacity
            }
        }
    }

    func updateShapeOpacityInUnified(id: UUID, opacity: Double) {
        updateShapeByID(id) { shape in
            shape.opacity = opacity
        }
    }

    func updateShapeStrokePlacementInUnified(id: UUID, placement: StrokePlacement) {
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
