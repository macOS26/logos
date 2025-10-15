import SwiftUI
import Combine

extension VectorDocument {

    func updateShapeFillColorInUnified(id: UUID, color: VectorColor) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                if shape.fillStyle == nil {
                    shape.fillStyle = FillStyle(color: color, opacity: defaultFillOpacity)
                } else {
                    shape.fillStyle?.color = color
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
            }
        }
    }

    func updateShapeStrokeColorInUnified(id: UUID, color: VectorColor) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: color, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.color = color
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
            }
        }
    }

    func updateShapeFillOpacityInUnified(id: UUID, opacity: Double) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                if shape.fillStyle == nil {
                    shape.fillStyle = FillStyle(color: defaultFillColor, opacity: opacity)
                } else {
                    shape.fillStyle?.opacity = opacity
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
            }
        }
    }

    func updateShapeStrokeWidthInUnified(id: UUID, width: Double) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: width, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.width = width
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
            }
        }
    }

    func lockShapeInUnified(id: UUID) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.isLocked = true
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
            }
        }
    }

    func unlockShapeInUnified(id: UUID) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.isLocked = false
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
            }
        }
    }

    func hideShapeInUnified(id: UUID) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.isVisible = false
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
            }
        }
    }

    func showShapeInUnified(id: UUID) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.isVisible = true
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
            }
        }
    }

    func updateShapeStrokeOpacityInUnified(id: UUID, opacity: Double) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: opacity)
                } else {
                    shape.strokeStyle?.opacity = opacity
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
            }
        }
    }

    func updateShapeOpacityInUnified(id: UUID, opacity: Double) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.opacity = opacity
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
            }
        }
    }

    func updateShapeStrokePlacementInUnified(id: UUID, placement: StrokePlacement) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: placement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.placement = placement
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject

                NotificationCenter.default.post(
                    name: Notification.Name("ShapePreviewUpdate"),
                    object: nil,
                    userInfo: ["shapeID": id, "strokePlacement": placement.rawValue]
                )
            }
        }
    }
}
