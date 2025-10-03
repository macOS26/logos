//
//  DrawingCanvasStyleHelpers.swift
//  logos inkpen.io
//
//  Created by Assistant on 2025-09-21.
//
//  Common style getter functions used across DrawingCanvas tools

import SwiftUI

extension DrawingCanvas {
    
    // MARK: - Style Getters
    
    internal func getCurrentFillColor() -> VectorColor {
        // PRIORITY 1: If text objects are selected, use their fill color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.findText(by: firstSelectedTextID) {
            return textObject.typography.fillColor
        }
        
        // PRIORITY 2: If shapes are selected, use their color
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shape = shapes.first(where: { $0.id == firstSelectedID }),
               let fillColor = shape.fillStyle?.color {
                return fillColor
            }
        }
        
        // PRIORITY 3: Use default color for new shapes
        return document.defaultFillColor
    }
    
    internal func getCurrentFillOpacity() -> Double {
        // PRIORITY 1: If text objects are selected, use their fill opacity
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.findText(by: firstSelectedTextID) {
            return textObject.typography.fillOpacity
        }
        
        // PRIORITY 2: If shapes are selected, use their opacity
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shape = shapes.first(where: { $0.id == firstSelectedID }),
               let opacity = shape.fillStyle?.opacity {
                return opacity
            }
        }
        
        // PRIORITY 3: Use default opacity for new shapes
        return document.defaultFillOpacity
    }
    
    internal func getCurrentStrokeColor() -> VectorColor {
        // PRIORITY 1: If text objects are selected, use their stroke color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.findText(by: firstSelectedTextID) {
            return textObject.typography.strokeColor
        }
        
        // PRIORITY 2: If shapes are selected, use their color
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shape = shapes.first(where: { $0.id == firstSelectedID }),
               let strokeColor = shape.strokeStyle?.color {
                return strokeColor
            }
        }
        
        // PRIORITY 3: Use default color for new shapes
        return document.defaultStrokeColor
    }
    
    internal func getCurrentStrokeOpacity() -> Double {
        // PRIORITY 1: If text objects are selected, use their stroke opacity
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.findText(by: firstSelectedTextID) {
            return textObject.typography.strokeOpacity
        }
        
        // PRIORITY 2: If shapes are selected, use their opacity
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shape = shapes.first(where: { $0.id == firstSelectedID }),
               let opacity = shape.strokeStyle?.opacity {
                return opacity
            }
        }
        
        // PRIORITY 3: Use default opacity for new shapes
        return document.defaultStrokeOpacity
    }
    
    internal func getCurrentStrokeWidth() -> Double {
        // If shapes are selected, use their stroke width
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shape = shapes.first(where: { $0.id == firstSelectedID }),
               let width = shape.strokeStyle?.width {
                return width
            }
        }
        
        // Use default width for new shapes
        return document.defaultStrokeWidth
    }
}