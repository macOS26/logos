//
//  DrawingCanvas+SelectionTap.swift
//  logos inkpen.io
//
//  Selection tap functionality
//

import SwiftUI
import Combine

extension DrawingCanvas {
    // TEXT EDITING FUNCTIONS REMOVED - Starting over with simple approach
    
    internal func handleSelectionTap(at location: CGPoint) {
        // Clean up excessive logging per user request

        // FIXED: Ensure coordinate system is properly synchronized
        // Add coordinate validation to catch any sync issues
        let validatedLocation = validateAndCorrectLocation(location)
        
        // OPTION+CLICK WITH ARROW TOOL: Switch to Direct Selection mode (professional behavior)
        if isOptionPressed && document.currentTool == .selection {
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
            outerHit: for unifiedObject in document.unifiedObjects.reversed() {
                if case .shape(let shape) = unifiedObject.objectType {
                    if !shape.isVisible { continue }
                    let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                    if isBackgroundShape { continue }
                    
                    // FIXED: Use zoom-aware tolerance for consistent hit detection
                    let baseTolerance: CGFloat = 8.0
                    let tolerance = max(2.0, baseTolerance / document.zoomLevel)

                    // CRITICAL FIX: Text objects have empty paths - use bounds for hit testing
                    let isHit: Bool
                    if shape.isTextObject {
                        // Use bounds for text object hit testing
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        isHit = transformedBounds.contains(validatedLocation)
                    } else {
                        isHit = PathOperations.hitTest(shape.transformedPath, point: validatedLocation, tolerance: tolerance)
                    }

                    if isHit {
                        hitShape = shape
                        hitLayerIndex = unifiedObject.layerIndex
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
            // Find the clicked shape using improved hit detection
            var clickedShape: VectorShape?
            
            // Search through unified objects from top to bottom
            for unifiedObject in document.unifiedObjects.reversed() {
                if case .shape(let shape) = unifiedObject.objectType {
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
            }
            
            // Check if the clicked shape is a rectangle-based shape that can have corner radius
            if let shape = clickedShape, isRectangleBasedShape(shape) {
                // Enable corner radius support if not already enabled
                if !shape.isRoundedRectangle {
                    // This will be handled by the toolbar when it updates the shape
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
            return
        }
        
        // REMOVED: Old text selection path - now using unified objects system only
        
        // Find object at location across all visible layers using unified system
        var hitObject: VectorObject?

        // Search through unified objects from top to bottom (reverse order for proper stacking)
        let objectsInOrder = document.getObjectsInStackingOrder()
        
        for unifiedObject in objectsInOrder.reversed() {
            // Check if the layer is visible
            if unifiedObject.layerIndex < document.layers.count {
                let layer = document.layers[unifiedObject.layerIndex]
                if !layer.isVisible {
                    continue
                }
            }
            
            var isHit = false
            
            switch unifiedObject.objectType {
            case .shape(let shape):
                if !shape.isVisible { continue }

                // Skip background shapes
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                if isBackgroundShape {
                    continue
                }
                
                // Check if this is actually a text object
                if shape.isTextObject {
                    // TEXT OBJECT HANDLING - preserve existing logic
                    if !shape.isVisible || shape.isLocked {
                        continue
                    }
                    
                    // CRITICAL FIX: Use textPosition if available, otherwise use transform for position
                    // SVG text may store position in transform instead of textPosition
                    let textPos = shape.textPosition ?? CGPoint(x: shape.transform.tx, y: shape.transform.ty)

                    // Use the same hit testing logic as findTextAt
                    let textContentArea = CGRect(
                        x: textPos.x,
                        y: textPos.y,
                        width: shape.bounds.width,
                        height: shape.bounds.height
                    )
                    
                    let contentHit = textContentArea.contains(validatedLocation)
                    
                    // CRITICAL FIX: For green text boxes, only use content hit (no bounding box)
                    // This prevents the bounding box from interfering with text movement
                    isHit = contentHit  // Only content-based selection for text objects
                } else {
                    // Check if this shape is clipped by a clipping path
                    // If so, don't allow selection - the clipping path should be selected instead
                    if shape.clippedByShapeID != nil {
                        isHit = false
                    } else if shape.isClippingPath {
                        // For clipping paths, ONLY use path-based hit testing, never bounds
                        let baseTolerance: CGFloat = 8.0
                        let tolerance = max(2.0, baseTolerance / document.zoomLevel)
                        isHit = PathOperations.hitTest(shape.transformedPath, point: validatedLocation, tolerance: tolerance)
                    } else {
                        // REGULAR SHAPE - use direct selection hit detection logic
                        isHit = performShapeHitTest(shape: shape, at: validatedLocation)
                    }
                }
            }

            if isHit {
                hitObject = unifiedObject
                break
            }
        }

        if let hitObject = hitObject {

            // No need to redirect to clipping mask anymore - we already prevent selection of clipped shapes
            let objectToSelect = hitObject

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

            // TEXT OBJECTS: Set transform origin to top-left by default
            if case .shape(let shape) = objectToSelect.objectType, shape.isTextObject {
                document.transformOrigin = .topLeft
            }

            // Update selected layer
            document.selectedLayerIndex = objectToSelect.layerIndex
            
            // CRITICAL FIX: Sync selection arrays for compatibility
            document.syncSelectionArrays()

            // NEW: Update Ink Panel with selected object's color
            if let selectedColor = document.getSelectedObjectColor() {
                if document.activeColorTarget == .stroke {
                    document.defaultStrokeColor = selectedColor
                } else {
                    document.defaultFillColor = selectedColor
                }
            }

            // Force UI update
            document.objectWillChange.send()
        } else {
            // CRITICAL FIX: If no objects found and we have text objects, try to force resync
            let hasTextObjects = document.unifiedObjects.contains { obj in
                if case .shape(let shape) = obj.objectType { return shape.isTextObject }
                return false
            }
            if hasTextObjects {
                document.forceResyncUnifiedObjects()
            }
            
            // FIXED: Enhanced deselection logic - check if click is within any selection box
            let isWithinSelectionBox = isLocationWithinSelectionBox(validatedLocation)


            if !isShiftPressed && !isCommandPressed {
                if isWithinSelectionBox {
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

                }
                document.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Improved Hit Detection Helper
    
    /// FIXED: Centralized hit detection logic with precise selection behavior
    private func performShapeHitTest(shape: VectorShape, at location: CGPoint) -> Bool {
        // CRITICAL FIX: Special handling for text objects (they have empty paths)
        if shape.isTextObject {
            // Text objects use bounds-based hit testing, not path hit testing
            // Use transform translation for position (stored in transform.tx, transform.ty)
            let textBounds = CGRect(
                x: shape.transform.tx,
                y: shape.transform.ty, 
                width: shape.bounds.width,
                height: shape.bounds.height
            )
            let isHit = textBounds.contains(location)
            return isHit
        }
        
        // OPTION KEY ENHANCEMENT: Use path-based selection when Option key is held
        if isOptionPressed {
            // Option key held: Use precise path-based hit testing only
            let baseTolerance: CGFloat = 8.0
            let tolerance = max(2.0, baseTolerance / document.zoomLevel)
            let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
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
                    return true
                } else {
                    // Fallback to path hit test for edge cases
                    let baseTolerance: CGFloat = 4.0 // Reduced tolerance for more precision
                    let tolerance = max(1.0, baseTolerance / document.zoomLevel)
                    let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
                    return isHit
                }
            } else if isStrokeOnly && shape.strokeStyle != nil {
                // CRITICAL FIX: Stroke-only shapes need proper stroke width tolerance
                let strokeWidth = shape.strokeStyle?.width ?? 1.0
                // Use stroke width + generous padding for easy selection
                let strokeTolerance = max(12.0, strokeWidth + 8.0) // Increased tolerance for better UX

                let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                return isHit
            } else {
                // Filled shapes: Use exact bounds first, then precise path hit test
                let transformedBounds = shape.bounds.applying(shape.transform)

                // FIXED: Use exact bounds for primary hit test, not expanded bounds
                if transformedBounds.contains(location) {
                    return true
                } else {
                    // Fallback: precise path hit test with reduced tolerance
                    let baseTolerance: CGFloat = 4.0 // Reduced from 8.0 to 4.0 for more precision
                    let tolerance = max(1.0, baseTolerance / document.zoomLevel)
                    let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
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
        Log.error("🚨 DEBUG SELECTION BOX CHECK: location=\(location)", category: .debug)
        Log.error("🚨 DEBUG SELECTION BOX CHECK: selectedObjectIDs=\(document.selectedObjectIDs)", category: .debug)
        
        // Check selected objects using unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    Log.error("🚨 DEBUG SHAPE: id=\(shape.id), isTextObject=\(shape.isTextObject)", category: .debug)
                    Log.error("🚨 DEBUG TRANSFORM: tx=\(shape.transform.tx), ty=\(shape.transform.ty)", category: .debug)
                    Log.error("🚨 DEBUG BOUNDS: \(shape.bounds)", category: .debug)
                    
                    // CRITICAL FIX: For text objects, only check content area, not bounding box
                    if shape.isTextObject {
                        // Only use text content area for text objects (no bounding box)
                        let textContentArea = CGRect(
                            x: CGPoint(x: shape.transform.tx, y: shape.transform.ty).x,
                            y: CGPoint(x: shape.transform.tx, y: shape.transform.ty).y,
                            width: shape.bounds.width,
                            height: shape.bounds.height
                        )
                        Log.error("🚨 DEBUG TEXT CONTENT AREA: \(textContentArea)", category: .debug)
                        let contains = textContentArea.contains(location)
                        Log.error("🚨 DEBUG TEXT CONTAINS: \(contains)", category: .debug)
                        
                        if contains {
                            Log.error("🚨 DEBUG SELECTION BOX: TEXT HIT - RETURNING TRUE", category: .debug)
                            return true
                        }
                    } else {
                        // For non-text shapes, use normal bounds checking
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let selectionBoxBounds = transformedBounds.insetBy(dx: 0, dy: 0)
                        Log.error("🚨 DEBUG SHAPE BOUNDS: \(selectionBoxBounds)", category: .debug)
                        let contains = selectionBoxBounds.contains(location)
                        Log.error("🚨 DEBUG SHAPE CONTAINS: \(contains)", category: .debug)
                        
                        if contains {
                            Log.error("🚨 DEBUG SELECTION BOX: SHAPE HIT - RETURNING TRUE", category: .debug)
                            return true
                        }
                    }
                }
            }
        }
        
        Log.error("🚨 DEBUG SELECTION BOX: NO HIT - RETURNING FALSE", category: .debug)
        return false
    }
    
    /// Helper function to find a shape by ID
    private func findShapeByID(_ shapeID: UUID) -> VectorShape? {
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               shape.id == shapeID {
                return shape
            }
        }
        return nil
    }
} 
