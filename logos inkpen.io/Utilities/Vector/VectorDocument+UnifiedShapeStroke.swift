//
//  VectorDocument+UnifiedShapeStroke.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics

// MARK: - Unified Shape Stroke Management
extension VectorDocument {
    
    func updateShapeStrokeLineCapInUnified(id: UUID, lineCap: CGLineCap) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: lineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.lineCap = lineCap
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeStrokeLineJoinInUnified(id: UUID, lineJoin: CGLineJoin) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: lineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.lineJoin = lineJoin
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeStrokeMiterLimitInUnified(id: UUID, miterLimit: Double) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: miterLimit, opacity: defaultStrokeOpacity)
                } else {
                    shape.strokeStyle?.miterLimit = miterLimit
                }
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeStrokeDashPatternInUnified(id: UUID, dashPattern: [Double]) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                }
                shape.strokeStyle?.dashPattern = dashPattern
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeStrokeDashPhaseInUnified(id: UUID, dashPhase: Double) {
        // Dash phase is not currently stored on StrokeStyle
        // This would need to be added to StrokeStyle to support advanced dash patterns
        objectWillChange.send()
    }
    
    func updateShapeNameInUnified(id: UUID, name: String) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.name = name
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeBlendModeInUnified(id: UUID, blendMode: BlendMode) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.blendMode = blendMode
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapeTransformInUnified(id: UUID, transform: CGAffineTransform) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.transform = transform
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateShapePathInUnified(id: UUID, path: VectorPath) {
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
    
    func updateShapeBoundsInUnified(id: UUID, bounds: CGRect) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.bounds = bounds
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
}