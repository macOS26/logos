//
//  VectorDocument+UnifiedShapeHelpers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics

// MARK: - Unified Shape Helpers
extension VectorDocument {
    // MARK: - UNIFIED SHAPE HELPERS
    
    func updateShapeFillColorInUnified(id: UUID, color: VectorColor) {
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
                    if layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: color, opacity: defaultFillOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].fillStyle?.color = color
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokeColorInUnified(id: UUID, color: VectorColor) {
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
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeFillOpacityInUnified(id: UUID, opacity: Double) {
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
                    if layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: defaultFillColor, opacity: opacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].fillStyle?.opacity = opacity
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokeWidthInUnified(id: UUID, width: Double) {
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
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: width, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.width = width
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func lockShapeInUnified(id: UUID) {
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
                    layers[layerIndex].shapes[shapeIndex].isLocked = true
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func unlockShapeInUnified(id: UUID) {
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
                    layers[layerIndex].shapes[shapeIndex].isLocked = false
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func hideShapeInUnified(id: UUID) {
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
                    layers[layerIndex].shapes[shapeIndex].isVisible = false
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func showShapeInUnified(id: UUID) {
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
                    layers[layerIndex].shapes[shapeIndex].isVisible = true
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokeOpacityInUnified(id: UUID, opacity: Double) {
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
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: defaultStrokePlacement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: opacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.opacity = opacity
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeOpacityInUnified(id: UUID, opacity: Double) {
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
                    layers[layerIndex].shapes[shapeIndex].opacity = opacity
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
    func updateShapeStrokePlacementInUnified(id: UUID, placement: StrokePlacement) {
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
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: placement, lineCap: defaultStrokeLineCap, lineJoin: defaultStrokeLineJoin, miterLimit: defaultStrokeMiterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.placement = placement
                    }
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
    
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
                    layers[layerIndex].shapes[shapeIndex].path = path
                    layers[layerIndex].shapes[shapeIndex].updateBounds()
                    updateUnifiedObjectsOptimized()
                    break
                }
            }
        }
    }
}