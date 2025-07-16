//
//  DrawingCanvas+SelectionTap.swift
//  logos inkpen.io
//
//  Selection tap functionality
//

import SwiftUI

extension DrawingCanvas {
    // TEXT EDITING FUNCTIONS REMOVED - Starting over with simple approach
    
    internal func handleSelectionTap(at location: CGPoint) {
        // Clean up excessive logging per user request
        
        // CRITICAL: Regular Selection tool must clear direct selection
        // Professional tools have mutually exclusive selection modes
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        
        // Only handle selection for selection tool
        guard document.currentTool == .selection else { return }
        
        // CRITICAL FIX: Check for text objects FIRST (they should be selectable with selection tool!)
        if let textID = findTextAt(location: location) {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                let textObject = document.textObjects[textIndex]
                
                // Check if text is locked
                if textObject.isLocked {
                    document.selectedShapeIDs.removeAll()
                    document.selectedTextIDs.removeAll()
                    document.objectWillChange.send()
                    return
                }
                
                // Select the text object
                if isShiftPressed {
                    // SHIFT+CLICK: Add to selection
                    document.selectedTextIDs.insert(textID)
                } else if isCommandPressed {
                    // CMD+CLICK: Toggle selection
                    if document.selectedTextIDs.contains(textID) {
                        document.selectedTextIDs.remove(textID)
                    } else {
                        document.selectedTextIDs.insert(textID)
                    }
                } else {
                    // REGULAR CLICK: Replace selection
                    document.selectedTextIDs = [textID]
                    document.selectedShapeIDs.removeAll() // Clear shape selection
                }
                
                // Force UI update
                document.objectWillChange.send()
                return
            }
        }
        
        // Find shape at location across all visible layers
        var hitShape: VectorShape?
        var hitLayerIndex: Int?
        
        // Search through layers from top to bottom
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            // Search through shapes from top to bottom (reverse order)
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                // PASTEBOARD BEHAVES EXACTLY LIKE CANVAS: Allow hit testing, handle via locked behavior
                
                // FIXED: Proper hit testing logic for stroke vs filled shapes
                var isHit = false
                
                // CRITICAL FIX: Background shapes (Canvas/Pasteboard) need special handling
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    // Background shapes: Use EXACT bounds checking - no tolerance!
                    // This ensures Canvas/Pasteboard only respond to clicks EXACTLY within their bounds
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(location)
                } else {
                    // Regular shapes: Use different logic for stroke vs filled
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                    
                    if isStrokeOnly && shape.strokeStyle != nil {
                        // Method 1: Stroke-only shapes - use stroke-based hit testing only
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                    } else {
                        // Method 2: Filled shapes - use bounds + path hit testing
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -12, dy: -12)
                        
                        if expandedBounds.contains(location) {
                            isHit = true
                        } else {
                            // Fallback: precise path hit test
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                        }
                    }
                }
                
                if isHit {
                    hitShape = shape
                    hitLayerIndex = layerIndex
                    break
                }
            }
            if hitShape != nil { break }
        }
        
        if let shape = hitShape, let layerIndex = hitLayerIndex {
            // IMPROVED LOCKED BEHAVIOR: Instead of preventing interaction, deselect current selection
            if document.layers[layerIndex].isLocked || shape.isLocked {
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
                document.objectWillChange.send()
                return
            }
            
            // Hit a shape object
            document.selectedLayerIndex = layerIndex
            
            if isShiftPressed {
                // SHIFT+CLICK: Add to selection (extend selection)
                document.selectedShapeIDs.insert(shape.id)
            } else if isCommandPressed {
                // CMD+CLICK: Toggle selection (add if not selected, remove if selected)
                if document.selectedShapeIDs.contains(shape.id) {
                    document.selectedShapeIDs.remove(shape.id)
                } else {
                    document.selectedShapeIDs.insert(shape.id)
                }
            } else {
                // REGULAR CLICK: Replace selection (clear existing, select new)
                document.selectedShapeIDs = [shape.id]
                document.selectedTextIDs.removeAll() // Clear text selection
            }
        } else {
            // NO OBJECT HIT: Clicking on background or empty space
            let documentBounds = document.documentBounds
            let isOutsideDocument = !documentBounds.contains(location)
            
            if isOutsideDocument {
                // Clicking in gray background area outside document always deselects
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
            } else if !isShiftPressed && !isCommandPressed {
                // Clicking inside document bounds on empty space deselects
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
} 