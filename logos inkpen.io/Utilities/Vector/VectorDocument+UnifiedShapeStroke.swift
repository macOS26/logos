import SwiftUI

extension VectorDocument {

    func updateShapeStrokeLineJoinInUnified(id: UUID, lineJoin: CGLineJoin) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            switch unifiedObjects[objectIndex].objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineJoin: lineJoin, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.lineJoin = LineJoin(lineJoin)
                }

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                // Notify granular change for live updates
                changeNotifier.notifyObjectChanged(id)

            case .text:
                break
            }
        }
    }

    func updateShapeStrokeLineCapInUnified(id: UUID, lineCap: CGLineCap) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            switch unifiedObjects[objectIndex].objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineCap: lineCap, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.lineCap = LineCap(lineCap)
                }

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                // Notify granular change for live updates
                changeNotifier.notifyObjectChanged(id)

            case .text:
                break
            }
        }
    }

    func updateShapeStrokeMiterLimitInUnified(id: UUID, miterLimit: CGFloat) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            switch unifiedObjects[objectIndex].objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: strokeDefaults.placement, miterLimit: miterLimit, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.miterLimit = miterLimit
                }

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                // Notify granular change for live updates
                changeNotifier.notifyObjectChanged(id)

            case .text:
                break
            }
        }
    }

    func createFillStyleInUnified(id: UUID, color: VectorColor, opacity: Double) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            switch unifiedObjects[objectIndex].objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.fillStyle = FillStyle(
                    color: color,
                    opacity: opacity
                )

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                // Notify granular change for live updates
                changeNotifier.notifyObjectChanged(id)

            case .text:
                break
            }
        }
    }

    func createStrokeStyleInUnified(id: UUID, color: VectorColor, width: Double, placement: StrokePlacement, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: Double, opacity: Double) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            switch unifiedObjects[objectIndex].objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
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
                )

                // Notify granular change for live updates
                changeNotifier.notifyObjectChanged(id)

            case .text:
                break
            }
        }
    }

    func updateShapePathUnified(id: UUID, path: VectorPath) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            switch unifiedObjects[objectIndex].objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.path = path
                shape.updateBounds()

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                // Notify granular change for live updates
                changeNotifier.notifyObjectChanged(id)

            case .text:
                break
            }
        }
    }

    func updateShapeCornerRadiiInUnified(id: UUID, cornerRadii: [Double], path: VectorPath) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            switch unifiedObjects[objectIndex].objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.cornerRadii = cornerRadii
                shape.path = path
                shape.updateBounds()

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                // Notify granular change for live updates
                changeNotifier.notifyObjectChanged(id)

            case .text:
                break
            }
        }
    }

    func updateShapeGradientInUnified(id: UUID, gradient: VectorGradient, target: ColorTarget) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            switch unifiedObjects[objectIndex].objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                switch target {
                case .fill:
                    shape.fillStyle = FillStyle(gradient: gradient, opacity: 1.0)
                case .stroke:
                    let currentStroke = shape.strokeStyle
                    shape.strokeStyle = StrokeStyle(
                        gradient: gradient,
                        width: currentStroke?.width ?? defaultStrokeWidth,
                        placement: currentStroke?.placement ?? strokeDefaults.placement,
                        lineCap: currentStroke?.lineCap.cgLineCap ?? strokeDefaults.lineCap,
                        lineJoin: currentStroke?.lineJoin.cgLineJoin ?? strokeDefaults.lineJoin,
                        miterLimit: currentStroke?.miterLimit ?? strokeDefaults.miterLimit,
                        opacity: currentStroke?.opacity ?? 1.0
                    )
                }

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                // Notify granular change for live updates
                changeNotifier.notifyObjectChanged(id)

            case .text:
                break
            }
        }
    }

    func updateShapeTransformAndPathInUnified(id: UUID, path: VectorPath? = nil, transform: CGAffineTransform? = nil) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            switch unifiedObjects[objectIndex].objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
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
                )

                // Notify granular change for live updates
                changeNotifier.notifyObjectChanged(id)

            case .text:
                break
            }
        }
    }

    func updateEntireShapeInUnified(id: UUID, updater: (inout VectorShape) -> Void) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.id == id
            case .text:
                return false
            }
        }) {
            switch unifiedObjects[objectIndex].objectType {
            case .shape(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                updater(&shape)
                shape.updateBounds()

                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                )

                // Notify granular change for live updates
                changeNotifier.notifyObjectChanged(id)

            case .text:
                break
            }
        }
    }
}
