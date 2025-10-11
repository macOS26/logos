
import SwiftUI

extension VectorDocument {

    func updateShapeStrokeLineJoinInUnified(id: UUID, lineJoin: CGLineJoin) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineJoin: lineJoin, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.lineJoin = LineJoin(lineJoin)
                }

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func updateShapeStrokeLineCapInUnified(id: UUID, lineCap: CGLineCap) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: lineCap, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.lineCap = LineCap(lineCap)
                }

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func updateShapeStrokeMiterLimitInUnified(id: UUID, miterLimit: CGFloat) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, miterLimit: miterLimit, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.miterLimit = miterLimit
                }

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func createFillStyleInUnified(id: UUID, color: VectorColor, opacity: Double) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.fillStyle = FillStyle(
                    color: color,
                    opacity: opacity
                )

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func createStrokeStyleInUnified(id: UUID, color: VectorColor, width: Double, placement: StrokePlacement, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: Double, opacity: Double) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.strokeStyle = StrokeStyle(
                    color: color,
                    width: width,
                    placement: placement,
                    lineCap: lineCap,
                    lineJoin: lineJoin,
                    miterLimit: miterLimit,
                    opacity: opacity
                )

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func updateShapePathUnified(id: UUID, path: VectorPath) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id && !shape.isTextObject
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.path = path
                shape.updateBounds()

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func updateShapeCornerRadiiInUnified(id: UUID, cornerRadii: [Double], path: VectorPath) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id && !shape.isTextObject
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.cornerRadii = cornerRadii
                shape.path = path
                shape.updateBounds()

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func updateShapeGradientInUnified(id: UUID, gradient: VectorGradient, target: ColorTarget) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id && !shape.isTextObject
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                switch target {
                case .fill:
                    shape.fillStyle = FillStyle(gradient: gradient, opacity: 1.0)
                case .stroke:
                    let currentStroke = shape.strokeStyle
                    shape.strokeStyle = StrokeStyle(
                        gradient: gradient,
                        width: currentStroke?.width ?? defaultStrokeWidth,
                        placement: currentStroke?.placement ?? defaultStrokePlacement,
                        lineCap: currentStroke?.lineCap.cgLineCap ?? defaultStrokeLineCap,
                        lineJoin: currentStroke?.lineJoin.cgLineJoin ?? defaultStrokeLineJoin,
                        miterLimit: currentStroke?.miterLimit ?? defaultStrokeMiterLimit,
                        opacity: currentStroke?.opacity ?? 1.0
                    )
                }

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func updateShapeTransformAndPathInUnified(id: UUID, path: VectorPath? = nil, transform: CGAffineTransform? = nil) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id && !shape.isTextObject
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                if let path = path {
                    shape.path = path
                }
                if let transform = transform {
                    shape.transform = transform
                }
                shape.updateBounds()

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }

    func updateEntireShapeInUnified(id: UUID, updater: (inout VectorShape) -> Void) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id && !shape.isTextObject
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                updater(&shape)
                shape.updateBounds()

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }
}
