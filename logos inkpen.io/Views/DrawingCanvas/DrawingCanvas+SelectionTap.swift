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
        
        // FIXED: Ensure coordinate system is properly synchronized
        // Add coordinate validation to catch any sync issues
        let validatedLocation = validateAndCorrectLocation(location)
        if validatedLocation != location {
            Log.info("🎯 COORDINATE CORRECTION: Adjusted from \(location) to \(validatedLocation)", category: .selection)
        }
        
        // OPTION+CLICK WITH ARROW TOOL: Switch to Direct Selection mode (professional behavior)
        if isOptionPressed && document.currentTool == .selection {
            Log.info("🎯 OPTION+CLICK: Switching to Direct Selection tool and performing direct selection", category: .selection)
            document.currentTool = .directSelection
            // Perform direct selection at the click location
            handleDirectSelectionTap(at: validatedLocation)
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
                    
                    // FIXED: Use zoom-aware tolerance for consistent hit detection
                    let baseTolerance: CGFloat = 8.0
                    let tolerance = max(2.0, baseTolerance / document.zoomLevel)
                    let isHit = PathOperations.hitTest(shape.transformedPath, point: validatedLocation, tolerance: tolerance)
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
            Log.info("🎯 CONTROL+CLICK: Checking for corner radius editing...", category: .selection)
            
            // Find the clicked shape using improved hit detection
            var clickedShape: VectorShape?
            
            // Search through layers from top to bottom
            for layerIndex in document.layers.indices.reversed() {
                let layer = document.layers[layerIndex]
                if !layer.isVisible { continue }
                
                for shape in layer.shapes.reversed() {
                    if !shape.isVisible { continue }
                    
                    // Skip background shapes
                    let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                    if isBackgroundShape { continue }
                    
                    // FIXED: Use consistent hit detection logic
                    let isHit = performShapeHitTest(shape: shape, at: validatedLocation)
                    
                    if isHit {
                        clickedShape = shape
                        break
                    }
                }
                
                if clickedShape != nil { break }
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
        if (document.currentTool == .selection || document.currentTool == .font), let textID = findTextAt(location: validatedLocation) {
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
        
        Log.info("🎯 SELECTION TAP: Looking for shapes at location \(validatedLocation)", category: .selection)
        
        // Search through layers from top to bottom
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            Log.info("🎯 SELECTION TAP: Checking layer \(layerIndex) (\(layer.name))", category: .selection)
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                Log.info("🎯 SELECTION TAP: Testing shape '\(shape.name)'", category: .selection)
                
                // Skip background shapes
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                if isBackgroundShape {
                    Log.info("🎯 SELECTION TAP: Skipping background shape", category: .selection)
                    continue
                }
                
                // FIXED: Use improved hit detection with consistent logic
                let isHit = performShapeHitTest(shape: shape, at: validatedLocation)
                
                if isHit {
                    hitShape = shape
                    hitLayerIndex = layerIndex
                    Log.info("✅ SELECTION TAP: Hit shape '\(shape.name)' on layer \(layerIndex)", category: .selection)
                    break
                }
            }
            
            if hitShape != nil { break }
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
            Log.info("❌ NO HIT: No objects found at location \(validatedLocation)", category: .selection)
            
            // FIXED: Enhanced deselection logic - check if click is within any selection box
            let isWithinSelectionBox = isLocationWithinSelectionBox(validatedLocation)
            
            if !isShiftPressed && !isCommandPressed {
                let wasSelected = !document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty
                
                if isWithinSelectionBox {
                    Log.info("🎯 CLICKED WITHIN SELECTION BOX: Keeping current selection", category: .selection)
                } else {
                    // Clicked outside all selection boxes - deselect everything
                    document.selectedShapeIDs.removeAll()
                    document.selectedTextIDs.removeAll()
                    
                    // Clear other selection modes when deselecting
                    selectedPoints.removeAll()
                    selectedHandles.removeAll()
                    directSelectedShapeIDs.removeAll()
                    syncDirectSelectionWithDocument()
                    isCornerRadiusEditMode = false
                    
                    if wasSelected {
                        Log.info("🎯 DESELECTED: Cleared all selections - clicked outside selection boxes", category: .selection)
                    }
                }
                document.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Improved Hit Detection Helper
    
    /// FIXED: Centralized hit detection logic with precise selection behavior
    private func performShapeHitTest(shape: VectorShape, at location: CGPoint) -> Bool {
        // OPTION KEY ENHANCEMENT: Use path-based selection when Option key is held
        if isOptionPressed {
            // Option key held: Use precise path-based hit testing only
            let baseTolerance: CGFloat = 8.0
            let tolerance = max(2.0, baseTolerance / document.zoomLevel)
            let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
            Log.info("  - ⌥ Option path-only hit test: \(isHit)", category: .selection)
            return isHit
        } else {
            // FIXED: More precise selection behavior - only select when clicking exactly on objects
            let isImageShape = ImageContentRegistry.containsImage(shape)
            let isStrokeOnly = (shape.fillStyle?.color == .clear || shape.fillStyle == nil)
            
            if isImageShape {
                // Treat images as filled rectangles for hit-testing
                let transformedBounds = shape.bounds.applying(shape.transform)
                // FIXED: Use exact bounds, not expanded bounds for precise selection
                if transformedBounds.contains(location) {
                    Log.info("  - Image exact bounds hit: YES", category: .selection)
                    return true
                } else {
                    // Fallback to path hit test for edge cases
                    let baseTolerance: CGFloat = 4.0 // Reduced tolerance for more precision
                    let tolerance = max(1.0, baseTolerance / document.zoomLevel)
                    let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
                    Log.info("  - Image path hit: \(isHit)", category: .selection)
                    return isHit
                }
            } else if isStrokeOnly && shape.strokeStyle != nil {
                // Stroke-only shapes: Use precise stroke-based hit testing
                let strokeWidth = shape.strokeStyle?.width ?? 1.0
                // FIXED: Reduced tolerance for more precise selection
                let strokeTolerance = max(8.0, strokeWidth + 5.0) // Reduced from 15.0 to 8.0
                
                let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                Log.info("  - Precise stroke hit test: \(isHit) (tolerance: \(strokeTolerance))", category: .selection)
                return isHit
            } else {
                // Filled shapes: Use exact bounds first, then precise path hit test
                let transformedBounds = shape.bounds.applying(shape.transform)
                
                // FIXED: Use exact bounds for primary hit test, not expanded bounds
                if transformedBounds.contains(location) {
                    Log.info("  - Exact bounds hit: YES", category: .selection)
                    return true
                } else {
                    // Fallback: precise path hit test with reduced tolerance
                    let baseTolerance: CGFloat = 4.0 // Reduced from 8.0 to 4.0 for more precision
                    let tolerance = max(1.0, baseTolerance / document.zoomLevel)
                    let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
                    Log.info("  - Precise path hit test: \(isHit) (tolerance: \(tolerance))", category: .selection)
                    return isHit
                }
            }
        }
    }
    
         // MARK: - Coordinate System Validation
     
     /// FIXED: Validate and correct coordinate system issues
     private func validateAndCorrectLocation(_ location: CGPoint) -> CGPoint {
         // Check for NaN or infinite values that could cause selection issues
         if location.x.isNaN || location.y.isNaN || location.x.isInfinite || location.y.isInfinite {
             Log.error("❌ INVALID COORDINATES: \(location) - using zero point", category: .error)
             return .zero
         }
         
         // Check for extreme values that might indicate coordinate system corruption
         let maxReasonableValue: CGFloat = 1000000.0
         if abs(location.x) > maxReasonableValue || abs(location.y) > maxReasonableValue {
             Log.error("❌ EXTREME COORDINATES: \(location) - using zero point", category: .error)
             return .zero
         }
         
         return location
     }
     
         /// Check if a shape is a rectangle-based shape that can have corner radius
    private func isRectangleBasedShape(_ shape: VectorShape) -> Bool {
        let shapeName = shape.name.lowercased()
        return shapeName == "rectangle" || shapeName == "square" ||
               shapeName == "rounded rectangle" || shapeName == "pill"
    }
    
    /// FIXED: Check if a location is within any existing selection box
    private func isLocationWithinSelectionBox(_ location: CGPoint) -> Bool {
        // Check selected shapes
        for shapeID in document.selectedShapeIDs {
            if let shape = findShapeByID(shapeID) {
                let transformedBounds = shape.bounds.applying(shape.transform)
                // Use a small tolerance for selection box detection
                let selectionBoxBounds = transformedBounds.insetBy(dx: -2, dy: -2)
                if selectionBoxBounds.contains(location) {
                    return true
                }
            }
        }
        
        // Check selected text objects
        for textID in document.selectedTextIDs {
            if let textObj = document.textObjects.first(where: { $0.id == textID }) {
                let textBounds = CGRect(
                    x: textObj.position.x + textObj.bounds.minX,
                    y: textObj.position.y + textObj.bounds.minY,
                    width: textObj.bounds.width,
                    height: textObj.bounds.height
                )
                // Use a small tolerance for selection box detection
                let selectionBoxBounds = textBounds.insetBy(dx: -2, dy: -2)
                if selectionBoxBounds.contains(location) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Helper function to find a shape by ID
    private func findShapeByID(_ shapeID: UUID) -> VectorShape? {
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == shapeID }) {
                return shape
            }
        }
        return nil
    }
} 