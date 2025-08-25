//
//  VectorDocument+StrokeOutlining.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation

// MARK: - Stroke Outlining
extension VectorDocument {

    // MARK: - Stroke Outlining Functions

    /// This is critical for professional vector graphics workflows
    func outlineSelectedStrokes() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        
        let shapesToOutline = layers[layerIndex].shapes.filter { selectedShapeIDs.contains($0.id) && $0.strokeStyle != nil }
        var newShapeIDs: Set<UUID> = []
        var originalShapeIDs: Set<UUID> = []
        
        for shape in shapesToOutline {
            guard let strokeStyle = shape.strokeStyle,
                  PathOperations.canOutlineStroke(path: shape.path.cgPath, strokeStyle: strokeStyle) else {
                continue
            }
            
            // Create outlined stroke path
            if let outlinedPath = PathOperations.outlineStroke(
                path: shape.path.cgPath,
                strokeStyle: strokeStyle
            ) {
                // 1. Create new shape with outlined stroke path as fill
                var strokeShape = VectorShape(
                    name: "\(shape.name) Stroke",
                    path: VectorPath(cgPath: outlinedPath),
                    strokeStyle: nil, // No stroke since it's now a fill
                    fillStyle: FillStyle(
                        color: strokeStyle.color,
                        opacity: strokeStyle.opacity,
                        blendMode: strokeStyle.blendMode
                    )
                )
                
                // Preserve transform and visibility properties
                strokeShape.transform = shape.transform
                strokeShape.opacity = shape.opacity
                strokeShape.isVisible = shape.isVisible
                strokeShape.isLocked = shape.isLocked
                strokeShape.updateBounds()
                
                // 2. Create or update original shape to have just the fill (no stroke)
                if shape.fillStyle != nil && shape.fillStyle?.color != .clear {
                    // Keep the original shape with fill only
                    var fillShape = shape
                    fillShape.strokeStyle = nil // Remove stroke from original
                    fillShape.name = "\(shape.name) Fill"
                    fillShape.updateBounds()
                    
                    // Find the index of the original shape
                    if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
                        // Replace original shape with fill-only version
                        layers[layerIndex].shapes[shapeIndex] = fillShape
                        originalShapeIDs.insert(fillShape.id)
                        
                        // Add stroke shape ABOVE the fill shape
                        layers[layerIndex].shapes.insert(strokeShape, at: shapeIndex + 1)
                        newShapeIDs.insert(strokeShape.id)
                    }
                } else {
                    // No fill, just replace with stroke outline
                    if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
                        layers[layerIndex].shapes[shapeIndex] = strokeShape
                        newShapeIDs.insert(strokeShape.id)
                    }
                }
            }
        }
        
        // Select only the stroke shapes (not the fill shapes)
        selectedShapeIDs = newShapeIDs
    }
    
    /// Checks if outline stroke operation is available for current selection
    var canOutlineStrokes: Bool {
        guard let layerIndex = selectedLayerIndex else { return false }
        
        let shapesWithStrokes = layers[layerIndex].shapes.filter {
            selectedShapeIDs.contains($0.id) && $0.strokeStyle != nil
        }
        
        return !shapesWithStrokes.isEmpty && shapesWithStrokes.allSatisfy { shape in
            guard let strokeStyle = shape.strokeStyle else { return false }
            return PathOperations.canOutlineStroke(path: shape.path.cgPath, strokeStyle: strokeStyle)
        }
    }
    
    /// Gets count of selected shapes that have strokes and can be outlined
    var outlineableStrokesCount: Int {
        guard let layerIndex = selectedLayerIndex else { return 0 }
        
        return layers[layerIndex].shapes.filter { shape in
            selectedShapeIDs.contains(shape.id) &&
            shape.strokeStyle != nil &&
            PathOperations.canOutlineStroke(path: shape.path.cgPath, strokeStyle: shape.strokeStyle!)
        }.count
    }
}
