//
//  VectorDocument+UnifiedShapeHelpers.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics

// MARK: - Unified Shape Helper Functions
extension VectorDocument {
    
    func updateEntireShapeInUnified(id: UUID, update: (inout VectorShape) -> Void) {
        // Update entire shape in unified system with a closure
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                update(&shape)
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeGradientInUnified(id: UUID, gradient: VectorGradient, target: ColorTarget) {
        // Update gradient in unified system based on target
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                switch target {
                case .fill:
                    if shape.fillStyle == nil {
                        shape.fillStyle = FillStyle(gradient: gradient, opacity: defaultFillOpacity)
                    } else {
                        shape.fillStyle?.color = .gradient(gradient)
                    }
                case .stroke:
                    if shape.strokeStyle == nil {
                        shape.strokeStyle = StrokeStyle(gradient: gradient, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        shape.strokeStyle?.color = .gradient(gradient)
                    }
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapePathUnified(id: UUID, path: VectorPath) {
        // Update shape path in unified system
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.path = path
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeCornerRadiiInUnified(id: UUID, cornerRadii: [Double], path: VectorPath) {
        // Update corner radii and path in unified system
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.cornerRadii = cornerRadii
                shape.path = path
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeTransformAndPathInUnified(id: UUID, path: VectorPath, transform: CGAffineTransform) {
        // Update both transform and path in unified system
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.path = path
                shape.transform = transform
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func createStrokeStyleInUnified(id: UUID, color: VectorColor, width: Double, placement: StrokePlacement, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: Double, opacity: Double) {
        // Create or update stroke style in unified system
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.strokeStyle = StrokeStyle(color: color, width: width, placement: placement, lineCap: lineCap, lineJoin: lineJoin, miterLimit: miterLimit, opacity: opacity)
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func createFillStyleInUnified(id: UUID, color: VectorColor, opacity: Double) {
        // Create or update fill style in unified system
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.fillStyle = FillStyle(color: color, opacity: opacity)
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeFillColorInUnified(id: UUID, color: VectorColor) {
        // Update directly in unified system
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
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeStrokeColorInUnified(id: UUID, color: VectorColor) {
        // Update directly in unified system
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
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeFillOpacityInUnified(id: UUID, opacity: Double) {
        // Update directly in unified system
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
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeStrokeWidthInUnified(id: UUID, width: Double) {
        // Update directly in unified system
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
                objectWillChange.send()
            }
        }
    }
    
    func lockShapeInUnified(id: UUID) {
        // Update directly in unified system
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
                objectWillChange.send()
            }
        }
    }
    
    func unlockShapeInUnified(id: UUID) {
        // Update directly in unified system
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
                objectWillChange.send()
            }
        }
    }
    
    func hideShapeInUnified(id: UUID) {
        // Update directly in unified system
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
                objectWillChange.send()
            }
        }
    }
    
    func showShapeInUnified(id: UUID) {
        // Update directly in unified system
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
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeStrokeOpacityInUnified(id: UUID, opacity: Double) {
        // Update directly in unified system
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
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeOpacityInUnified(id: UUID, opacity: Double) {
        // Update directly in unified system
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
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeStrokePlacementInUnified(id: UUID, placement: StrokePlacement) {
        // Update directly in unified system
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
                objectWillChange.send()
            }
        }
    }
}