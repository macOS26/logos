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
            outerHit: for unifiedObject in document.unifiedObjects.reversed() {
                if case .shape(let shape) = unifiedObject.objectType {
                    if !shape.isVisible { continue }
                    let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                    if isBackgroundShape { continue }
                    
                    // FIXED: Use zoom-aware tolerance for consistent hit detection
                    let baseTolerance: CGFloat = 8.0
                    let tolerance = max(2.0, baseTolerance / document.zoomLevel)
                    let isHit = PathOperations.hitTest(shape.transformedPath, point: validatedLocation, tolerance: tolerance)
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
        Log.info("🎯 SELECTION TAP: Found \(objectsInOrder.count) objects in stacking order", category: .selection)
        
        for unifiedObject in objectsInOrder.reversed() {
            // Check if the layer is visible
            if unifiedObject.layerIndex < document.layers.count {
                let layer = document.layers[unifiedObject.layerIndex]
                if !layer.isVisible { 
                    Log.info("🎯 SELECTION TAP: Skipping object '\(unifiedObject.id)' - layer \(unifiedObject.layerIndex) not visible", category: .selection)
                    continue 
                }
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
                
                // Check if this is actually a text object
                if shape.isTextObject {
                    // TEXT OBJECT HANDLING - preserve existing logic
                    Log.info("🎯 SELECTION TAP: Testing text object '\(String((shape.textContent ?? "").prefix(20)))'", category: .selection)
                    Log.info("  - Text ID: \(shape.id)", category: .selection)
                    Log.info("  - Text position: \(CGPoint(x: shape.transform.tx, y: shape.transform.ty))", category: .selection)
                    Log.info("  - Text bounds: \(shape.bounds)", category: .selection)
                    Log.info("  - Text isVisible: \(shape.isVisible)", category: .selection)
                    Log.info("  - Text isLocked: \(shape.isLocked)", category: .selection)
                    Log.info("  - Click location: \(validatedLocation)", category: .selection)
                    
                    if !shape.isVisible || shape.isLocked { 
                        Log.info("🎯 SELECTION TAP: Skipping text object - not visible or locked", category: .selection)
                        continue 
                    }
                    
                    // Use the same hit testing logic as findTextAt
                    let textContentArea = CGRect(
                        x: CGPoint(x: shape.transform.tx, y: shape.transform.ty).x,
                        y: CGPoint(x: shape.transform.tx, y: shape.transform.ty).y,
                        width: shape.bounds.width,
                        height: shape.bounds.height
                    )
                    
                    let exactBounds = CGRect(
                        x: CGPoint(x: shape.transform.tx, y: shape.transform.ty).x + shape.bounds.minX,
                        y: CGPoint(x: shape.transform.tx, y: shape.transform.ty).y + shape.bounds.minY,
                        width: shape.bounds.width,
                        height: shape.bounds.height
                    )
                    
                    let expandedBounds = exactBounds.insetBy(dx: 0, dy: 0)
                    
                    Log.info("  - Content area: \(textContentArea)", category: .selection)
                    Log.info("  - Exact bounds: \(exactBounds)", category: .selection)
                    Log.info("  - Expanded bounds: \(expandedBounds)", category: .selection)
                    
                    let contentHit = textContentArea.contains(validatedLocation)
                    let exactHit = exactBounds.contains(validatedLocation)
                    let expandedHit = expandedBounds.contains(validatedLocation)
                    
                    Log.info("  - Content hit: \(contentHit)", category: .selection)
                    Log.info("  - Exact hit: \(exactHit)", category: .selection)
                    Log.info("  - Expanded hit: \(expandedHit)", category: .selection)
                    
                    // CRITICAL FIX: For green text boxes, only use content hit (no bounding box)
                    // This prevents the bounding box from interfering with text movement
                    isHit = contentHit  // Only content-based selection for text objects
                    
                    if isHit {
                        Log.info("✅ TEXT HIT: Text object selected (content-only)", category: .selection)
                    } else {
                        Log.info("❌ TEXT MISS: Text object not selected", category: .selection)
                    }
                } else {
                    // Check if this shape is clipped by a clipping path
                    // If so, don't allow selection - the clipping path should be selected instead
                    if shape.clippedByShapeID != nil {
                        Log.info("🎭 SELECTION TAP: Shape '\(shape.name)' has clipping path - skipping", category: .selection)
                        isHit = false
                    } else if shape.isClippingPath {
                        // For clipping paths, ONLY use path-based hit testing, never bounds
                        Log.info("🎭 SELECTION TAP: Testing clipping path '\(shape.name)' - using path-only hit test", category: .selection)
                        let baseTolerance: CGFloat = 8.0
                        let tolerance = max(2.0, baseTolerance / document.zoomLevel)
                        isHit = PathOperations.hitTest(shape.transformedPath, point: validatedLocation, tolerance: tolerance)
                        Log.info("  - Clipping path hit: \(isHit)", category: .selection)
                    } else {
                        // REGULAR SHAPE - use direct selection hit detection logic
                        isHit = performShapeHitTest(shape: shape, at: validatedLocation)
                    }
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
            Log.info("❌ NO HIT: No objects found at location \(validatedLocation)", category: .selection)
            
            // CRITICAL FIX: If no objects found and we have text objects, try to force resync
            if !document.allTextObjects.isEmpty {
                Log.info("🔧 SELECTION FIX: No objects found but text objects exist - attempting force resync", category: .selection)
                document.forceResyncUnifiedObjects()
            }
            
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
            Log.info("  - Text object bounds hit: \(isHit) (bounds: \(textBounds))", category: .selection)
            return isHit
        }
        
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
                // CRITICAL FIX: Stroke-only shapes need proper stroke width tolerance
                let strokeWidth = shape.strokeStyle?.width ?? 1.0
                // Use stroke width + generous padding for easy selection
                let strokeTolerance = max(12.0, strokeWidth + 8.0) // Increased tolerance for better UX
                
                let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                Log.info("  - Stroke hit test: \(isHit) (stroke width: \(strokeWidth), tolerance: \(strokeTolerance))", category: .selection)
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
        Log.error("🚨 DEBUG SELECTION BOX CHECK: location=\(location)", category: .debug)
        Log.error("🚨 DEBUG SELECTION BOX CHECK: selectedObjectIDs=\(document.selectedObjectIDs)", category: .debug)
        
        // Check selected objects using unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
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
