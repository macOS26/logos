//
//  DrawingCanvas+Selection.swift
//  logos inkpen.io
//
//  Selection functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func selectObjectAt(_ location: CGPoint) {
        // Unified selection logic for all areas - no area-specific behavior needed
        handleSelectionTap(at: location)
    }

    // Coincident smooth point handling functions moved to CoincidentPointHandling.swift    
    internal func isDraggingSelectedObject(at location: CGPoint) -> Bool {
        // REFACTORED: Use unified objects system for selection checking
        
        // Check all selected objects (shapes and text) using unified objects
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    // CRITICAL FIX: Handle text objects represented as VectorShape
                    if shape.isTextObject {
                        if !shape.isVisible || shape.isLocked { continue }
                        
                        // Use exact same coordinate system as selection box for text objects
                        let position = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                        let absoluteBounds = CGRect(
                            x: position.x + shape.bounds.minX,
                            y: position.y + shape.bounds.minY,
                            width: shape.bounds.width,
                            height: shape.bounds.height
                        )
                        
                        if absoluteBounds.contains(location) {
                            return true
                        }
                        continue // Skip the regular shape handling for text objects
                    }
                    // Check if the shape is visible
                    if !shape.isVisible {
                        continue
                    }
                    
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
