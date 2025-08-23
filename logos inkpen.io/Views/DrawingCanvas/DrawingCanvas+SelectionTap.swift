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
        
        // REMOVED: Old text selection path - now using unified objects system only
        
        // Find object at location across all visible layers using unified system
        var hitObject: VectorObject?
        
        Log.info("🎯 SELECTION TAP: Looking for objects at location \(validatedLocation)", category: .selection)
        
        // Search through unified objects from top to bottom (reverse order for proper stacking)
        let objectsInOrder = document.getObjectsInStackingOrder()
        for unifiedObject in objectsInOrder.reversed() {
            // Check if the layer is visible
            if unifiedObject.layerIndex < document.layers.count {
                let layer = document.layers[unifiedObject.layerIndex]
                if !layer.isVisible { continue }
            }
            
            Log.info("🎯 SELECTION TAP: Testing object '\(unifiedObject.id)' on layer \(unifiedObject.layerIndex)", category: .selection)
            
            var isHit = false
            
            switch unifiedObject.objectType {
            case .shape(let shape):
                if !shape.isVisible { continue }
                
                Log.info("🎯 SELECTION TAP: Testing shape '\(shape.name)'", category: .selection)
                
                // Skip background shapes
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                if isBackgroundShape {
                    Log.info("🎯 SELECTION TAP: Skipping background shape", category: .selection)
                    continue
                }
                
                // Use improved hit detection with consistent logic
                isHit = performShapeHitTest(shape: shape, at: validatedLocation)
                
            case .text(let text):
                if !text.isVisible || text.isLocked { continue }
                
                Log.info("🎯 SELECTION TAP: Testing text object '\(text.content.prefix(20))'", category: .selection)
                Log.info("  - Text ID: \(text.id)", category: .selection)
                Log.info("  - Text position: \(text.position)", category: .selection)
                Log.info("  - Text bounds: \(text.bounds)", category: .selection)
                Log.info("  - Click location: \(validatedLocation)", category: .selection)
                
                // Use the same hit testing logic as findTextAt
                let textContentArea = CGRect(
                    x: text.position.x,
                    y: text.position.y,
                    width: max(text.bounds.width, 200.0),
                    height: max(text.bounds.height, 60.0)
                )
                
                let exactBounds = CGRect(
                    x: text.position.x + text.bounds.minX,
                    y: text.position.y + text.bounds.minY,
                    width: text.bounds.width,
                    height: text.bounds.height
                )
                
                let expandedBounds = exactBounds.insetBy(dx: -30, dy: -20)
                
                Log.info("  - Content area: \(textContentArea)", category: .selection)
                Log.info("  - Exact bounds: \(exactBounds)", category: .selection)
                Log.info("  - Expanded bounds: \(expandedBounds)", category: .selection)
                
                let contentHit = textContentArea.contains(validatedLocation)
                let exactHit = exactBounds.contains(validatedLocation)
                let expandedHit = expandedBounds.contains(validatedLocation)
                
                Log.info("  - Content hit: \(contentHit)", category: .selection)
                Log.info("  - Exact hit: \(exactHit)", category: .selection)
                Log.info("  - Expanded hit: \(expandedHit)", category: .selection)
                
                isHit = contentHit || exactHit || expandedHit
                
                if isHit {
                    Log.info("✅ TEXT HIT: Text object selected", category: .selection)
                } else {
                    Log.info("❌ TEXT MISS: Text object not selected", category: .selection)
                }
            }
            
            if isHit {
                hitObject = unifiedObject
                Log.info("✅ SELECTION TAP: Hit object '\(unifiedObject.id)' on layer \(unifiedObject.layerIndex)", category: .selection)
                break
            }
        }
        
        if let hitObject = hitObject {
            Log.info("✅ SELECTION SUCCESS: Selected object '\(hitObject.id)' on layer \(hitObject.layerIndex)", category: .selection)
            
            var objectToSelect = hitObject
            
            // Handle clipping mask logic for shapes
            if case .shape(let shape) = hitObject.objectType {
                if let clippedByShapeID = shape.clippedByShapeID {
                    // This shape is clipped by another shape - find the mask shape in unified objects
                    if let maskObject = document.unifiedObjects.first(where: { 
                        if case .shape(let maskShape) = $0.objectType {
                            return maskShape.id == clippedByShapeID
                        }
                        return false
                    }) {
                        Log.info("🎭 CLIPPING MASK: Shape is clipped by another shape - selecting mask instead", category: .selection)
                        objectToSelect = maskObject
                    }
                }
            }
            
            if isShiftPressed {
                // SHIFT+CLICK: Add to selection
                document.selectedObjectIDs.insert(objectToSelect.id)
            } else if isCommandPressed {
                // CMD+CLICK: Toggle selection
                if document.selectedObjectIDs.contains(objectToSelect.id) {
                    document.selectedObjectIDs.remove(objectToSelect.id)
                } else {
                    document.selectedObjectIDs.insert(objectToSelect.id)
                }
            } else {
                // REGULAR CLICK: Replace selection
                document.selectedObjectIDs = [objectToSelect.id]
            }
            
            // Update selected layer
            document.selectedLayerIndex = objectToSelect.layerIndex
            
            // CRITICAL FIX: Sync selection arrays for compatibility
            document.syncSelectionArrays()
            
            // Force UI update
            document.objectWillChange.send()
        } else {
            Log.info("❌ NO HIT: No objects found at location \(validatedLocation)", category: .selection)
            
            // FIXED: Enhanced deselection logic - check if click is within any selection box
            let isWithinSelectionBox = isLocationWithinSelectionBox(validatedLocation)
            
            if !isShiftPressed && !isCommandPressed {
                let wasSelected = !document.selectedObjectIDs.isEmpty
                
                if isWithinSelectionBox {
                    Log.info("🎯 CLICKED WITHIN SELECTION BOX: Keeping current selection", category: .selection)
                } else {
                    // Clicked outside all selection boxes - deselect everything
                    document.selectedObjectIDs.removeAll()
                    
                    // Sync selection arrays for compatibility
                    document.syncSelectionArrays()
                    
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
        // Check selected objects using unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    let transformedBounds = shape.bounds.applying(shape.transform)
                    // Use a small tolerance for selection box detection
                    let selectionBoxBounds = transformedBounds.insetBy(dx: -2, dy: -2)
                    if selectionBoxBounds.contains(location) {
                        return true
                    }
                    
                case .text(let text):
                    let textBounds = CGRect(
                        x: text.position.x + text.bounds.minX,
                        y: text.position.y + text.bounds.minY,
                        width: text.bounds.width,
                        height: text.bounds.height
                    )
                    // Use a small tolerance for selection box detection
                    let selectionBoxBounds = textBounds.insetBy(dx: -2, dy: -2)
                    if selectionBoxBounds.contains(location) {
                        return true
                    }
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