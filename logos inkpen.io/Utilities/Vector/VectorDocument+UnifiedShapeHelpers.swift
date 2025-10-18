import SwiftUI
import Combine

extension VectorDocument {

    func updateShapeFillColorInUnified(id: UUID, color: VectorColor) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            var updatedObject = unifiedObjects[index]
            switch updatedObject.objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                // Update the shape itself
                if shape.fillStyle == nil {
                    shape.fillStyle = FillStyle(color: color, opacity: defaultFillOpacity)
                } else {
                    shape.fillStyle?.color = color
                }

                // If this is a group, update all children
                if shape.isGroupContainer {
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

                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex)
                unifiedObjects[index] = updatedObject
            case .text:
                break
            }
        }
    }

    func updateShapeStrokeColorInUnified(id: UUID, color: VectorColor) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            var updatedObject = unifiedObjects[index]
            switch updatedObject.objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                // Update the shape itself
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: color, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.color = color
                }

                // If this is a group, update all children
                if shape.isGroupContainer {
                    var updatedChildren: [VectorShape] = []
                    for var childShape in shape.groupedShapes {
                        if childShape.strokeStyle == nil {
                            childShape.strokeStyle = StrokeStyle(color: color, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                        } else {
                            childShape.strokeStyle?.color = color
                        }
                        updatedChildren.append(childShape)
                    }
                    shape.groupedShapes = updatedChildren
                }

                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex)
                unifiedObjects[index] = updatedObject
            case .text:
                break
            }
        }
    }

    func updateShapeFillOpacityInUnified(id: UUID, opacity: Double) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            var updatedObject = unifiedObjects[index]
            switch updatedObject.objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                if shape.fillStyle == nil {
                    shape.fillStyle = FillStyle(color: defaultFillColor, opacity: opacity)
                } else {
                    shape.fillStyle?.opacity = opacity
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex)
                unifiedObjects[index] = updatedObject
            case .text:
                break
            }
        }
    }

    func updateShapeStrokeWidthInUnified(id: UUID, width: Double) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            var updatedObject = unifiedObjects[index]
            switch updatedObject.objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: width, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.width = width
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex)
                unifiedObjects[index] = updatedObject
            case .text:
                break
            }
        }
    }

    func lockShapeInUnified(id: UUID) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            var updatedObject = unifiedObjects[index]
            switch updatedObject.objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.isLocked = true
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex)
                unifiedObjects[index] = updatedObject
            case .text:
                break
            }
        }
    }

    func unlockShapeInUnified(id: UUID) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            var updatedObject = unifiedObjects[index]
            switch updatedObject.objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.isLocked = false
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex)
                unifiedObjects[index] = updatedObject
            case .text:
                break
            }
        }
    }

    func hideShapeInUnified(id: UUID) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            var updatedObject = unifiedObjects[index]
            switch updatedObject.objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.isVisible = false
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex)
                unifiedObjects[index] = updatedObject
            case .text:
                break
            }
        }
    }

    func showShapeInUnified(id: UUID) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            var updatedObject = unifiedObjects[index]
            switch updatedObject.objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.isVisible = true
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex)
                unifiedObjects[index] = updatedObject
            case .text:
                break
            }
        }
    }

    func updateShapeStrokeOpacityInUnified(id: UUID, opacity: Double) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            var updatedObject = unifiedObjects[index]
            switch updatedObject.objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: opacity)
                } else {
                    shape.strokeStyle?.opacity = opacity
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex)
                unifiedObjects[index] = updatedObject
            case .text:
                break
            }
        }
    }

    func updateShapeOpacityInUnified(id: UUID, opacity: Double) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            var updatedObject = unifiedObjects[index]
            switch updatedObject.objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.opacity = opacity
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex)
                unifiedObjects[index] = updatedObject
            case .text:
                break
            }
        }
    }

    func updateShapeStrokePlacementInUnified(id: UUID, placement: StrokePlacement) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            var updatedObject = unifiedObjects[index]
            switch updatedObject.objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: placement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.placement = placement
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex)
                unifiedObjects[index] = updatedObject

                NotificationCenter.default.post(
                    name: Notification.Name("ShapePreviewUpdate"),
                    object: nil,
                    userInfo: ["shapeID": id, "strokePlacement": placement.rawValue]
                )
            case .text:
                break
            }
        }
    }
}
