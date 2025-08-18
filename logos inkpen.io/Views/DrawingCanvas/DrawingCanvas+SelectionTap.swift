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
        
        Log.info("🎯 SELECTION TAP: Starting selection at location \(location)", category: .selection)
        Log.info("🎯 SELECTION TAP: Current tool is \(document.currentTool.rawValue)", category: .selection)
        
        // OPTION+CLICK WITH ARROW TOOL: Switch to Direct Selection mode (professional behavior)
        if isOptionPressed && document.currentTool == .selection {
            Log.info("🎯 OPTION+CLICK: Switching to Direct Selection tool and performing direct selection", category: .selection)
            document.currentTool = .directSelection
            // Perform direct selection at the click location
            handleDirectSelectionTap(at: location)
            return
        }
        
        // COMMAND+CLICK WITH ARROW TOOL: Temporary direct selection on second click of already selected object
        // First click with Command shows blue outline (already handled by outline view). If the user clicks again while holding Command,
        // switch to direct selection for that object (points/handles visible). Release Command to return to normal selection.
        if isCommandPressed && document.currentTool == .selection {
            var hitShape: VectorShape?
            var hitLayerIndex: Int?
            // STRICT OBJECT-BASED hit test (no bounds fallback) when Command is held
            outerHit: for layerIndex in document.layers.indices.reversed() {
                let layer = document.layers[layerIndex]
                if !layer.isVisible { continue }
                for shape in layer.shapes.reversed() {
                    if !shape.isVisible { continue }
                    let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                    if isBackgroundShape { continue }
                    let tolerance: CGFloat = 8.0
                    let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
                    if isHit {
                        hitShape = shape
                        hitLayerIndex = layerIndex
                        break outerHit
                    }
                }
            }
            if let shape = hitShape, let layerIndex = hitLayerIndex {
                // If this shape is already selected, Command-click toggles to temporary direct selection
                let isAlreadySelected = document.selectedShapeIDs.contains(shape.id)
                if isAlreadySelected {
                    // Enter direct selection mode for this shape
                    document.currentTool = .directSelection
                    directSelectedShapeIDs = [shape.id]
                    selectedPoints.removeAll()
                    selectedHandles.removeAll()
                    syncDirectSelectionWithDocument()
                    document.selectedLayerIndex = layerIndex
                    document.objectWillChange.send()
                    Log.info("⌘ COMMAND+CLICK: Temporarily switched to Direct Selection for shape \(shape.name)", category: .selection)
                } else {
                    // If not yet selected, toggle/add selection strictly by object hit
                    document.selectedTextIDs.removeAll()
                    if isShiftPressed {
                        document.selectedShapeIDs.insert(shape.id)
                    } else {
                        document.selectedShapeIDs = [shape.id]
                    }
                    document.selectedLayerIndex = layerIndex
                    document.objectWillChange.send()
                }
            }
            // IMPORTANT: Do not fall back to bounds-based regular selection while Command is held
            // If nothing was hit by object, leave selection unchanged
            return
        }
        
        // CONTROL+CLICK WITH ARROW TOOL: Enter corner radius editing mode (professional style)
        if isControlPressed && document.currentTool == .selection {
            Log.info("🎯 CONTROL+CLICK: Checking for rounded rectangle to enter corner radius mode", category: .selection)
            
            // Find the clicked shape first
            var clickedShape: VectorShape? = nil
            
            // Search through layers from top to bottom (same logic as regular selection)
            outerLoop: for layerIndex in document.layers.indices.reversed() {
                let layer = document.layers[layerIndex]
                if !layer.isVisible { continue }
                
                for shape in layer.shapes.reversed() {
                    if !shape.isVisible { continue }
                    
                    // Skip background shapes
                    let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                    if isBackgroundShape { continue }
                    
                    // Simple bounds-based hit test for Control-Click
                    let transformedBounds = shape.bounds.applying(shape.transform)
                    let expandedBounds = transformedBounds.insetBy(dx: -12, dy: -12)
                    
                    if expandedBounds.contains(location) {
                        clickedShape = shape
                        break outerLoop
                    }
                }
            }
            
            // Check if the clicked shape is a rectangle-based shape that can have corner radius
            if let shape = clickedShape, isRectangleBasedShape(shape) {
                Log.info("🎯 CONTROL+CLICK: Entering corner radius edit mode for rectangle-based shape: \(shape.name)", category: .selection)
                
                // Enable corner radius support if not already enabled
                if !shape.isRoundedRectangle {
                    // This will be handled by the toolbar when it updates the shape
                    Log.info("🎯 CONTROL+CLICK: Shape will be converted to corner-radius-enabled when editing begins", category: .selection)
                }
                
                // Select the shape and enter corner radius mode
                document.selectedShapeIDs = [shape.id]
                isCornerRadiusEditMode = true
                
                // Clear other selection modes
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                directSelectedShapeIDs.removeAll()
                
                return
            } else if clickedShape != nil {
                Log.info("🎯 CONTROL+CLICK: Clicked shape (\(clickedShape?.name ?? "unknown")) is not a rectangle-based shape", category: .selection)
            } else {
                Log.info("🎯 CONTROL+CLICK: No shape found at click location", category: .selection)
            }
        }
        
        // CRITICAL: Regular Selection tool must clear direct selection and corner radius mode
        // Professional tools have mutually exclusive selection modes
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        syncDirectSelectionWithDocument()
        isCornerRadiusEditMode = false // Exit corner radius mode when doing regular selection
        
        // Only handle selection for selection and transform tools
        guard document.currentTool == .selection || 
              document.currentTool == .scale || 
              document.currentTool == .rotate || 
              document.currentTool == .shear || 
              document.currentTool == .warp else { 
            Log.info("🚫 SELECTION TAP: Wrong tool - early return", category: .selection)
            return 
        }
        
        Log.info("🔍 SELECTION TAP: Tool check passed, looking for objects...", category: .selection)
        
        // Check for text objects when using selection tool or font tool
        if (document.currentTool == .selection || document.currentTool == .font), let textID = findTextAt(location: location) {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                let textObject = document.textObjects[textIndex]
                
                // PRINT TEXT BOX SETTINGS AS REQUESTED BY USER
                Log.info("🎯 ARROW TOOL SELECTED TEXT BOX UUID: \(textID.uuidString.prefix(8))", category: .selection)
                Log.info("📝 CONTENT: '\(textObject.content)'", category: .selection)
                Log.info("🎨 TYPOGRAPHY SETTINGS:", category: .selection)
                Log.info("  - Font: \(textObject.typography.fontFamily) \(textObject.typography.fontWeight.rawValue) \(textObject.typography.fontStyle.rawValue)", category: .selection)
                Log.info("  - Size: \(textObject.typography.fontSize)pt", category: .selection)
                Log.info("  - Line Height: \(textObject.typography.lineHeight)pt", category: .selection)
                Log.info("  - Line Spacing: \(textObject.typography.lineSpacing)pt", category: .selection)
                Log.info("  - Alignment: \(textObject.typography.alignment.rawValue)", category: .selection)
                Log.info("  - Fill Color: \(textObject.typography.fillColor)", category: .selection)
                Log.info("📦 BOUNDS: \(textObject.bounds)", category: .selection)
                Log.info("📍 POSITION: \(textObject.position)", category: .selection)
                Log.info("🔄 STATES: isEditing=\(textObject.isEditing), isVisible=\(textObject.isVisible), isLocked=\(textObject.isLocked)", category: .selection)
                
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
        
        Log.info("🎯 SELECTION TAP: Looking for shapes at location \(location)", category: .selection)
        
        // Search through layers from top to bottom
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            Log.info("🎯 SELECTION TAP: Checking layer \(layerIndex): '\(layer.name)' with \(layer.shapes.count) shapes", category: .selection)
            
            // Search through shapes from top to bottom (reverse order)
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                Log.info("🎯 SELECTION TAP: Testing shape '\(shape.name)' (group: \(shape.isGroupContainer))", category: .selection)
                
                // PASTEBOARD BEHAVES EXACTLY LIKE CANVAS: Allow hit testing, handle via locked behavior
                
                // FIXED: Proper hit testing logic for stroke vs filled shapes
                var isHit = false
                
                // CRITICAL FIX: Background shapes (Canvas/Pasteboard) should NEVER be selectable
                // They should always trigger deselection like clicking on empty space
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    // SKIP background shapes entirely - they should not be selectable
                    // This ensures clicking on Canvas/Pasteboard always deselects, never selects
                    Log.info("  - Background shape '\(shape.name)' SKIPPED - not selectable", category: .selection)
                    continue
                } else if shape.isGroupContainer {
                    // GROUP HIT TESTING FIX: Check if we hit any of the grouped shapes
                    Log.info("  - Group container: checking \(shape.groupedShapes.count) grouped shapes", category: .selection)
                    for groupedShape in shape.groupedShapes {
                        if !groupedShape.isVisible { continue }
                        
                        Log.info("    - Testing grouped shape '\(groupedShape.name)'", category: .selection)
                        
                        // OPTION KEY ENHANCEMENT: Use path-based selection for grouped shapes too
                        if isOptionPressed {
                            // Option key held: Use precise path-based hit testing only
                            let tolerance: CGFloat = 8.0
                            if PathOperations.hitTest(groupedShape.transformedPath, point: location, tolerance: tolerance) {
                                isHit = true
                                Log.info("      - ⌥ Option group path hit: YES", category: .selection)
                                break
                            } else {
                                Log.info("      - ⌥ Option group path hit: NO", category: .selection)
                            }
                        } else {
                            // Regular selection: Apply the same hit testing logic to grouped shapes
                            let isStrokeOnly = groupedShape.fillStyle?.color == .clear || groupedShape.fillStyle == nil
                            
                            if isStrokeOnly && groupedShape.strokeStyle != nil {
                                // Stroke-only shapes: Use stroke-based hit testing
                                let strokeWidth = groupedShape.strokeStyle?.width ?? 1.0
                                let strokeTolerance = max(15.0, strokeWidth + 10.0)
                                if PathOperations.hitTest(groupedShape.transformedPath, point: location, tolerance: strokeTolerance) {
                                    isHit = true
                                    Log.info("      - Stroke hit: YES", category: .selection)
                                    break
                                } else {
                                    Log.info("      - Stroke hit: NO", category: .selection)
                                }
                            } else {
                                // Regular grouped shapes: Use bounds + path hit testing
                                let transformedBounds = groupedShape.bounds.applying(groupedShape.transform)
                                let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                                
                                if expandedBounds.contains(location) {
                                    isHit = true
                                    Log.info("      - Bounds hit: YES", category: .selection)
                                    break
                                } else if PathOperations.hitTest(groupedShape.transformedPath, point: location, tolerance: 8.0) {
                                    isHit = true
                                    Log.info("      - Path hit: YES", category: .selection)
                                    break
                                } else {
                                    Log.info("      - Bounds hit: NO, Path hit: NO", category: .selection)
                                }
                            }
                        }
                    }
                    Log.info("  - Group overall hit result: \(isHit)", category: .selection)
                } else {
                    // OPTION KEY ENHANCEMENT: Use path-based selection when Option key is held
                    if isOptionPressed {
                        // Option key held: Use precise path-based hit testing only
                        let tolerance: CGFloat = 8.0
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
                        Log.info("  - ⌥ Option path-only hit test: \(isHit)", category: .selection)
                } else {
                    // Regular selection: Use different logic for stroke vs filled
                    // SPECIAL CASE: Raster image shapes should behave like filled rectangles (click inside selects)
                    let isImageShape = ImageContentRegistry.containsImage(shape)
                    let isStrokeOnly = (shape.fillStyle?.color == .clear || shape.fillStyle == nil)
                    
                    if isImageShape {
                        // Treat images as filled rectangles for hit-testing
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -12, dy: -12)
                        if expandedBounds.contains(location) {
                            isHit = true
                            Log.info("  - Image bounds hit: YES", category: .selection)
                        } else {
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                            Log.info("  - Image path hit: \(isHit)", category: .selection)
                        }
                    } else if isStrokeOnly && shape.strokeStyle != nil {
                        // Method 1: Stroke-only shapes - use stroke-based hit testing only
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                        Log.info("  - Regular stroke hit test: \(isHit)", category: .selection)
                    } else {
                        // Method 2: Filled shapes - use bounds + path hit testing
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -12, dy: -12)
                        
                        if expandedBounds.contains(location) {
                            isHit = true
                            Log.info("  - Regular bounds hit test: \(isHit)", category: .selection)
                        } else {
                            // Fallback: precise path hit test
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                            Log.info("  - Regular path hit test: \(isHit)", category: .selection)
                        }
                    }
                }
                }
                
                if isHit {
                    hitShape = shape
                    hitLayerIndex = layerIndex
                    Log.info("🎯 SELECTION TAP: FOUND HIT - Shape '\(shape.name)' in layer \(layerIndex)", category: .selection)
                    
                    // Check if shape is locked BEFORE setting it as hit
                    if layer.isLocked || shape.isLocked {
                        let lockType = layer.isLocked ? "locked layer" : "locked object"
                        Log.info("🚫 Shape '\(shape.name)' is on \(lockType) - deselecting everything", category: .selection)
                        document.selectedShapeIDs.removeAll()
                        document.selectedTextIDs.removeAll()
                        document.objectWillChange.send()
                        return
                    }
                    
                    break
                }
            }
            if hitShape != nil { break }
        }
        
        if hitShape == nil {
            Log.info("🎯 SELECTION TAP: NO SHAPE HIT - will deselect", category: .selection)
        }
        
        if let shape = hitShape, let layerIndex = hitLayerIndex {
            Log.info("✅ SELECTION SUCCESS: Selected shape '\(shape.name)' on layer \(layerIndex)", category: .selection)
            
            // CRITICAL FIX: Clear text selection when selecting shapes
            document.selectedTextIDs.removeAll()
            
            // CLIPPING MASK SELECTION LOGIC: If this shape is clipped by another shape, select the mask instead
            var shapeToSelect = shape
            if let clippedByShapeID = shape.clippedByShapeID {
                // This shape is clipped by another shape - find the mask shape
                if let maskShape = document.layers[layerIndex].shapes.first(where: { $0.id == clippedByShapeID }) {
                    Log.info("🎭 CLIPPING MASK: Shape '\(shape.name)' is clipped by '\(maskShape.name)' - selecting mask instead", category: .selection)
                    shapeToSelect = maskShape
                }
            }
            
            if isShiftPressed {
                // SHIFT+CLICK: Add to selection
                document.selectedShapeIDs.insert(shapeToSelect.id)
            } else if isCommandPressed {
                // CMD+CLICK: Toggle selection
                if document.selectedShapeIDs.contains(shapeToSelect.id) {
                    document.selectedShapeIDs.remove(shapeToSelect.id)
                } else {
                    document.selectedShapeIDs.insert(shapeToSelect.id)
                }
            } else {
                // REGULAR CLICK: Replace selection
                document.selectedShapeIDs = [shapeToSelect.id]
            }
            
            // Update selected layer
            document.selectedLayerIndex = layerIndex
            
            // Force UI update
            document.objectWillChange.send()
        } else {
            Log.info("❌ NO HIT: No objects found at location \(location)", category: .selection)
            
            // DESELECT ALL: Tap on empty area with selection tool
            let wasSelected = !document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs.removeAll()
            isCornerRadiusEditMode = false // Exit corner radius mode when clicking empty space
            syncDirectSelectionWithDocument()
            
            if wasSelected {
                Log.info("🎯 DESELECTED: Cleared selection due to empty area tap", category: .selection)
                document.objectWillChange.send()
            }
        }
    }
    
    /// Check if a shape is a rectangle-based shape that can have corner radius
    private func isRectangleBasedShape(_ shape: VectorShape) -> Bool {
        let shapeName = shape.name.lowercased()
        return shapeName == "rectangle" || shapeName == "square" ||
               shapeName == "rounded rectangle" || shapeName == "pill"
    }
} 