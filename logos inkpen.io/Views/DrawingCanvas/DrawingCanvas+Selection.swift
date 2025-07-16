//
//  DrawingCanvas+Selection.swift
//  logos inkpen.io
//
//  Selection functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func selectObjectAt(_ location: CGPoint) {
        // DETAILED LOGGING: Determine if this is canvas or pasteboard area
        let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612) // Standard canvas
        let isInCanvasArea = canvasBounds.contains(location)
        let areaType = isInCanvasArea ? "CANVAS AREA" : "PASTEBOARD AREA"
        
        print("🎯 SELECT OBJECT AT FUNCTION CALLED at: \(location) in \(areaType)")
        
        if !isInCanvasArea {
            print("🎯 PASTEBOARD: Prioritizing object selection with optimized hit testing")
            // PASTEBOARD OPTIMIZATION: Use selection tap logic directly for better object detection
            handleSelectionTap(at: location)
        } else {
            print("🎯 CANVAS: Using standard drag-based selection")
            // Reuse the selection tap logic for canvas
            handleSelectionTap(at: location)
        }
    }
}

extension DrawingCanvas {
    // Coincident smooth point handling functions moved to CoincidentPointHandling.swift
    
    internal func isDraggingSelectedObject(at location: CGPoint) -> Bool {
        // Check if the location is on any of the currently selected objects (shapes or text)
        
        // Check selected text objects first
        for textID in document.selectedTextIDs {
            if let textObj = document.textObjects.first(where: { $0.id == textID }) {
                if !textObj.isVisible || textObj.isLocked { continue }
                
                // Use exact same coordinate system as selection box
                let absoluteBounds = CGRect(
                    x: textObj.position.x + textObj.bounds.minX,
                    y: textObj.position.y + textObj.bounds.minY,
                    width: textObj.bounds.width,
                    height: textObj.bounds.height
                )
                
                if absoluteBounds.contains(location) {
                    return true
                }
            }
        }
        
        // Check selected shapes
        for layerIndex in document.layers.indices {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shapeID in document.selectedShapeIDs {
                if let shape = layer.shapes.first(where: { $0.id == shapeID }) {
                    // PASTEBOARD BEHAVES EXACTLY LIKE CANVAS: Allow hit testing, handle via locked behavior
                    
                    // Use the same improved hit testing logic as selection
                    // CRITICAL FIX: Background shapes (Canvas/Pasteboard) need special handling
                    let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                    
                    if isBackgroundShape {
                        // Background shapes: Use EXACT bounds checking - no tolerance!
                        let shapeBounds = shape.bounds.applying(shape.transform)
                        if shapeBounds.contains(location) {
                            return true
                        }
                    } else {
                        // Regular shapes: Use different logic for stroke vs filled
                        let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                        
                        if isStrokeOnly && shape.strokeStyle != nil {
                            // Use stroke width + padding for tolerance
                            let strokeWidth = shape.strokeStyle?.width ?? 1.0
                            let strokeTolerance = max(15.0, strokeWidth + 10.0)
                            
                            if PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance) {
                                return true
                            }
                        } else {
                            // Regular shapes: Use bounds + path hit testing
                            let transformedBounds = shape.bounds.applying(shape.transform)
                            let expandedBounds = transformedBounds.insetBy(dx: -12, dy: -12)
                            
                            if expandedBounds.contains(location) {
                                return true
                            } else {
                                if PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0) {
                                    return true
                                }
                            }
                        }
                    }
                }
            }
        }
        return false
    }
} 