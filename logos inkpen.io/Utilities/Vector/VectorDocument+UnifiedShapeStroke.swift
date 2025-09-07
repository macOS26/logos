//
//  VectorDocument+UnifiedShapeStroke.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics

// MARK: - UNIFIED SHAPE STROKE HELPERS
extension VectorDocument {
    
    func updateShapeStrokeLineJoinInUnified(id: UUID, lineJoin: CGLineJoin) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineJoin: lineJoin, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.lineJoin = lineJoin
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokeLineCapInUnified(id: UUID, lineCap: CGLineCap) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: lineCap, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.lineCap = lineCap
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokeMiterLimitInUnified(id: UUID, miterLimit: CGFloat) {
        // Check if shape exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Find in legacy layer arrays
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, miterLimit: miterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.miterLimit = miterLimit
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func createFillStyleInUnified(id: UUID, color: VectorColor, opacity: Double) {
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                        color: color,
                        opacity: opacity
                    )
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func createStrokeStyleInUnified(id: UUID, color: VectorColor, width: Double, placement: StrokePlacement, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: Double, opacity: Double) {
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == id
            }
            return false
        }) {
            for layerIndex in 0..<layers.count {
                if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                    layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(
                        color: color,
                        width: width,
                        placement: placement,
                        lineCap: lineCap,
                        lineJoin: lineJoin,
                        miterLimit: miterLimit,
                        opacity: opacity
                    )
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapePathUnified(id: UUID, path: VectorPath) {
        // Find in legacy layer arrays and update
        for layerIndex in 0..<layers.count {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                layers[layerIndex].shapes[shapeIndex].path = path
                layers[layerIndex].shapes[shapeIndex].updateBounds()
                
                // Update the specific unified object
                if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
                    if case .shape(let shape) = obj.objectType {
                        return shape.id == id && !shape.isTextObject
                    }
                    return false
                }) {
                    let updatedShape = layers[layerIndex].shapes[shapeIndex]
                    unifiedObjects[unifiedIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: layerIndex,
                        orderID: unifiedObjects[unifiedIndex].orderID
                    )
                }
                break
            }
        }
    }
    
    func updateShapeCornerRadiiInUnified(id: UUID, cornerRadii: [Double], path: VectorPath) {
        // Find in legacy layer arrays and update
        for layerIndex in 0..<layers.count {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                layers[layerIndex].shapes[shapeIndex].cornerRadii = cornerRadii
                layers[layerIndex].shapes[shapeIndex].path = path
                layers[layerIndex].shapes[shapeIndex].updateBounds()
                
                // Update the specific unified object
                if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
                    if case .shape(let shape) = obj.objectType {
                        return shape.id == id && !shape.isTextObject
                    }
                    return false
                }) {
                    let updatedShape = layers[layerIndex].shapes[shapeIndex]
                    unifiedObjects[unifiedIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: layerIndex,
                        orderID: unifiedObjects[unifiedIndex].orderID
                    )
                }
                break
            }
        }
    }
    
    func updateShapeGradientInUnified(id: UUID, gradient: VectorGradient, target: ColorTarget) {
        // Find in legacy layer arrays and update
        for layerIndex in 0..<layers.count {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                switch target {
                case .fill:
                    layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(gradient: gradient, opacity: 1.0)
                case .stroke:
                    let currentStroke = layers[layerIndex].shapes[shapeIndex].strokeStyle
                    layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(
                        gradient: gradient, 
                        width: currentStroke?.width ?? defaultStrokeWidth,
                        placement: currentStroke?.placement ?? defaultStrokePlacement,
                        lineCap: currentStroke?.lineCap ?? defaultStrokeLineCap,
                        lineJoin: currentStroke?.lineJoin ?? defaultStrokeLineJoin,
                        miterLimit: currentStroke?.miterLimit ?? defaultStrokeMiterLimit,
                        opacity: currentStroke?.opacity ?? 1.0
                    )
                }
                
                // Update the specific unified object
                if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
                    if case .shape(let shape) = obj.objectType {
                        return shape.id == id && !shape.isTextObject
                    }
                    return false
                }) {
                    let updatedShape = layers[layerIndex].shapes[shapeIndex]
                    unifiedObjects[unifiedIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: layerIndex,
                        orderID: unifiedObjects[unifiedIndex].orderID
                    )
                }
                break
            }
        }
    }
    
    /// Generic shape update helper for complex transformations
    func updateShapeTransformAndPathInUnified(id: UUID, path: VectorPath? = nil, transform: CGAffineTransform? = nil) {
        // Find in legacy layer arrays and update
        for layerIndex in 0..<layers.count {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                if let path = path {
                    layers[layerIndex].shapes[shapeIndex].path = path
                }
                if let transform = transform {
                    layers[layerIndex].shapes[shapeIndex].transform = transform
                }
                layers[layerIndex].shapes[shapeIndex].updateBounds()
                
                // Update the specific unified object
                if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
                    if case .shape(let shape) = obj.objectType {
                        return shape.id == id && !shape.isTextObject
                    }
                    return false
                }) {
                    let updatedShape = layers[layerIndex].shapes[shapeIndex]
                    unifiedObjects[unifiedIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: layerIndex,
                        orderID: unifiedObjects[unifiedIndex].orderID
                    )
                }
                break
            }
        }
    }
    
    /// Update entire shape object in unified system (use sparingly)
    func updateEntireShapeInUnified(id: UUID, updater: (inout VectorShape) -> Void) {
        // Find in legacy layer arrays and update
        for layerIndex in 0..<layers.count {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id }) {
                updater(&layers[layerIndex].shapes[shapeIndex])
                layers[layerIndex].shapes[shapeIndex].updateBounds()
                
                // Update the specific unified object
                if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
                    if case .shape(let shape) = obj.objectType {
                        return shape.id == id && !shape.isTextObject
                    }
                    return false
                }) {
                    let updatedShape = layers[layerIndex].shapes[shapeIndex]
                    unifiedObjects[unifiedIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: layerIndex,
                        orderID: unifiedObjects[unifiedIndex].orderID
                    )
                }
                break
            }
        }
    }
}