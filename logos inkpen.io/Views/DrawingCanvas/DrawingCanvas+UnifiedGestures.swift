//
//  DrawingCanvas+UnifiedGestures.swift
//  logos inkpen.io
//
//  Unified gesture management for Drawing Canvas and Pasteboard
//  Uses Drawing Canvas approach as the ideal template
//

import SwiftUI
import AppKit

extension DrawingCanvas {
    
    // MARK: - Advanced Click Detection
    
    /// Detect and log advanced click types (option+click, command+click, double click)
    /// Shows current tool and green text box detection
    internal func detectAdvancedClickTypes(at location: CGPoint, geometry: GeometryProxy, clickType: String) {
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        
        // Check for green text box (text that is selected but not editing)
        let greenTextDetected = findTextAt(location: canvasLocation) != nil
        
        // Get current tool name
        let currentToolName = document.currentTool.rawValue
        
        // Log the click detection
        print("🎯 ADVANCED CLICK DETECTION:")
        print("  - Click Type: \(clickType)")
        print("  - Current Tool: \(currentToolName)")
        print("  - Green Text Box Detected: \(greenTextDetected ? "YES" : "NO")")
        print("  - Location: (\(String(format: "%.1f", canvasLocation.x)), \(String(format: "%.1f", canvasLocation.y)))")
        print("  - Modifier Keys:")
        print("    - Option (⌥): \(isOptionPressed ? "PRESSED" : "not pressed")")
        print("    - Command (⌘): \(isCommandPressed ? "PRESSED" : "not pressed")")
        print("    - Shift (⇧): \(isShiftPressed ? "PRESSED" : "not pressed")")
        print("    - Control (⌃): \(isControlPressed ? "PRESSED" : "not pressed")")
        
        // Additional details for text detection
        if greenTextDetected {
            if let textID = findTextAt(location: canvasLocation),
               let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                let textObj = document.textObjects[textIndex]
                print("  - Text Content: '\(textObj.content.prefix(50))'")
                print("  - Text State: \(textObj.isEditing ? "BLUE (editing)" : "GREEN (selected)")")
            }
        }
        
        print("  - End Detection Report")
        print("")
    }
    
    /// Handle double-click events with advanced detection
    internal func handleDoubleClick(at location: CGPoint, geometry: GeometryProxy) {
        // DETECT ADVANCED CLICK TYPES FOR DOUBLE CLICK
        var clickType = "Double Click"
        if isOptionPressed && isCommandPressed {
            clickType = "Option+Command+Double Click"
        } else if isOptionPressed {
            clickType = "Option+Double Click"
        } else if isCommandPressed {
            clickType = "Command+Double Click"
        }
        
        // Call the advanced click detection
        detectAdvancedClickTypes(at: location, geometry: geometry, clickType: clickType)
        
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        
        // Check if we're clicking on a text box
        if let textID = findTextAt(location: canvasLocation) {
            // 1. Switch to Font tool (Aa)
            document.currentTool = .font
            Log.info("🎯 DOUBLE CLICK: Switched to Font tool", category: .selection)
            
            // 2. Turn text box to blue edit mode
            startEditingText(textID: textID, at: canvasLocation)
            Log.info("🎯 DOUBLE CLICK: Activated blue edit mode for text", category: .selection)
            
            // 3. Activate I-beam cursor at click location
            #if os(macOS)
            NSCursor.iBeam.set()
            Log.info("🎯 DOUBLE CLICK: Set I-beam cursor at location (\(String(format: "%.1f", canvasLocation.x)), \(String(format: "%.1f", canvasLocation.y)))", category: .selection)
            #endif
            
            // Additional: Position cursor in text at click location
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                let textObj = document.textObjects[textIndex]
                
                // Calculate relative position within the text box
                let relativeX = canvasLocation.x - textObj.position.x
                let relativeY = canvasLocation.y - textObj.position.y
                
                Log.info("🎯 DOUBLE CLICK: Text cursor positioned at relative coordinates (\(String(format: "%.1f", relativeX)), \(String(format: "%.1f", relativeY)))", category: .selection)
                Log.info("🎯 DOUBLE CLICK: Text content: '\(textObj.content)'", category: .selection)
            }
        } else {
            // If not clicking on text, just log the double-click
            Log.info("🎯 DOUBLE CLICK: No text box at location (\(String(format: "%.1f", canvasLocation.x)), \(String(format: "%.1f", canvasLocation.y)))", category: .selection)
        }
    }
    
    // MARK: - Unified Gesture System
    
    /// UNIFIED TAP HANDLER - Works consistently for all areas (Canvas + Pasteboard)
    /// Uses Drawing Canvas logic as the ideal template
    internal func handleUnifiedTap(at location: CGPoint, geometry: GeometryProxy) {
        // FIXED: Ensure coordinate system is properly synchronized
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        
        // Validate coordinates to catch any sync issues
        let validatedCanvasLocation = validateCanvasLocation(canvasLocation)
        if validatedCanvasLocation != canvasLocation {
            Log.info("🎯 COORDINATE VALIDATION: Adjusted canvas location from \(canvasLocation) to \(validatedCanvasLocation)", category: .selection)
        }
        
        // DOUBLE-CLICK DETECTION
        let currentTime = Date()
        let timeSinceLastClick = currentTime.timeIntervalSince(lastClickTime)
        let distanceFromLastClick = distance(location, lastClickLocation)
        let isDoubleClick = timeSinceLastClick < doubleClickTimeout && distanceFromLastClick < 10.0 // 10px tolerance
        
        // Update click tracking
        lastClickTime = currentTime
        lastClickLocation = location
        
        // DETECT ADVANCED CLICK TYPES
        var clickType = "Single Click"
        if isDoubleClick {
            if isOptionPressed && isCommandPressed {
                clickType = "Option+Command+Double Click"
            } else if isOptionPressed {
                clickType = "Option+Double Click"
            } else if isCommandPressed {
                clickType = "Command+Double Click"
            } else {
                clickType = "Double Click"
            }
            
            // Handle double-click immediately
            Log.info("🎯 DOUBLE CLICK DETECTED at: \(location)", category: .selection)
            handleDoubleClick(at: location, geometry: geometry)
            return // Exit early for double-clicks
        } else {
            // Single click with modifiers
            if isOptionPressed && isCommandPressed {
                clickType = "Option+Command+Click"
            } else if isOptionPressed {
                clickType = "Option+Click"
            } else if isCommandPressed {
                clickType = "Command+Click"
            }
        }
        
        // Call the advanced click detection
        detectAdvancedClickTypes(at: location, geometry: geometry, clickType: clickType)
        
        // Cancel bezier drawing for all tools except bezier pen
        if document.currentTool != .bezierPen && isBezierDrawing {
            cancelBezierDrawing()
        }
        
        // Route to appropriate tool handler based on current tool
        switch document.currentTool {
        case .selection, .scale, .rotate, .shear, .warp:
            // All transform tools use selection logic
            Log.fileOperation("🎯 UNIFIED: Routing to handleSelectionTap...", level: .info)
            handleSelectionTap(at: canvasLocation)
            // REMOVED: handleAggressiveBackgroundTap - this was deselecting objects immediately after selection!
            
        case .directSelection:
            handleDirectSelectionTap(at: canvasLocation)
            // REMOVED: handleAggressiveBackgroundTap - this was interfering with direct selection!
            
        case .convertAnchorPoint:
            handleConvertAnchorPointTap(at: canvasLocation)
            
        case .bezierPen:
            handleBezierPenTap(at: canvasLocation)
            
        case .font:
            // Font tool: Only handle editing existing text on tap, new text requires drag
            if let existingTextID = findTextAt(location: canvasLocation) {
                startEditingText(textID: existingTextID, at: canvasLocation)
            } else {
                Log.fileOperation("📝 FONT TOOL: Tap on empty area - drag to create new text box (like rectangle tool)", level: .info)
            }
            // Keep background tap handling for font tool only (this makes sense for font tool)
            handleAggressiveBackgroundTap(at: canvasLocation)
            
        case .line, .rectangle, .square, .roundedRectangle, .pill, .circle, .ellipse, .oval, .egg, .cone, .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle:
            // Shape tools are drag-only - ignore taps
            Log.fileOperation("🎨 UNIFIED: Shape tools (\(document.currentTool.rawValue)) are drag-only - tap ignored", level: .info)
        
        case .zoom:
            #if os(macOS)
            // Ensure zoom cursor stays during click
            MagnifyingGlassCursor.set()
            #endif
            // Click to zoom at cursor position. Option-click to zoom out.
            let focalPoint = location
            let currentZoom = CGFloat(document.zoomLevel)
            let targetZoom: CGFloat
            if isOptionPressed {
                // Step down to the next lower allowed step
                targetZoom = nextAllowedStepDown(from: currentZoom)
            } else {
                // Step up to the next higher allowed step
                targetZoom = nextAllowedStepUp(from: currentZoom)
            }
            handleZoomAtPoint(newZoomLevel: targetZoom, focalPoint: focalPoint, geometry: geometry)
            #if os(macOS)
            // Re-assert cursor post-zoom operation
            if isCanvasHovering && document.currentTool == .zoom {
                MagnifyingGlassCursor.set()
            }
            // Defensive: schedule one more set to override late system arrow resets
            DispatchQueue.main.async {
                if isCanvasHovering && document.currentTool == .zoom {
                    MagnifyingGlassCursor.set()
                }
            }
            #endif
            
        case .eyedropper:
            startEyedropperColorPick()
            
        default:
            break
        }
    }
    
    /// UNIFIED DRAG CHANGED HANDLER - Works consistently for all areas
    /// Uses Drawing Canvas logic as the ideal template  
    internal func handleUnifiedDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        // Route to appropriate tool handler based on current tool
        switch document.currentTool {
        case .hand:
            handlePanGesture(value: value, geometry: geometry)
        
        case .zoom:
            // Scrubby zoom from the drag start point. Up = zoom in, Down = zoom out (or invert with Option).
            if zoomToolDragStartPoint == .zero {
                zoomToolDragStartPoint = value.startLocation
                zoomToolInitialZoomLevel = document.zoomLevel
            }
            #if os(macOS)
            // Maintain magnifying glass while dragging in zoom tool
            MagnifyingGlassCursor.set()
            #endif
            let deltaY = value.location.y - zoomToolDragStartPoint.y
            let sensitivity: CGFloat = 300.0
            var scaleChange = exp(-deltaY / sensitivity) // drag up (negative deltaY) -> zoom in
            if isOptionPressed { scaleChange = 1.0 / scaleChange }
            // Keep drag zoom continuous (no snapping)
            let continuousZoom = max(0.1, min(16.0, zoomToolInitialZoomLevel * scaleChange))
            handleZoomAtPoint(newZoomLevel: continuousZoom, focalPoint: value.startLocation, geometry: geometry)
            
        case .line, .rectangle, .square, .roundedRectangle, .pill, .circle, .ellipse, .oval, .egg, .cone, .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle:
            handleShapeDrawing(value: value, geometry: geometry)
            
        case .font:
            handleTextBoxDrawing(value: value, geometry: geometry)
            
        case .selection:
            handleUnifiedSelectionDrag(value: value, geometry: geometry)
            
        case .directSelection:
            handleDirectSelectionDrag(value: value, geometry: geometry)
            
        case .bezierPen:
            handleBezierPenDrag(value: value, geometry: geometry)
            
        case .freehand:
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            if !isFreehandDrawing {
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                handleFreehandDragStart(at: startLocation)
            }
            handleFreehandDragUpdate(at: currentLocation)
            
        case .brush:
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            if !isBrushDrawing {
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                handleBrushDragStart(at: startLocation)
            }
            handleBrushDragUpdate(at: currentLocation)
            
        case .marker:
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            if !isMarkerDrawing {
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                handleMarkerDragStart(at: startLocation)
            }
            handleMarkerDragUpdate(at: currentLocation)
            
        case .scale, .rotate, .shear, .warp:
            // Transform tools don't use drag gestures - handled by their own handles
            break
            
        default:
            break
        }
    }
    
    /// UNIFIED DRAG ENDED HANDLER - Works consistently for all areas
    /// CRITICAL FIX: NO drag-to-tap conversion to prevent interrupting real drags
    internal func handleUnifiedDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        // FIXED: Always handle as completed drag - NO conversion to tap
        // This prevents drags from getting "lost" mid-operation
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        print("🎯 UNIFIED: Drag ended - handling as completed drag operation (\(String(format: "%.1f", dragDistance))px)")
        
        // Handle as completed drag
        switch document.currentTool {
        case .hand:
            finishPanGesture()
        
        case .zoom:
            // Reset zoom tool state
            zoomToolDragStartPoint = .zero
            zoomToolInitialZoomLevel = document.zoomLevel
            
        case .line, .rectangle, .square, .roundedRectangle, .pill, .circle, .ellipse, .oval, .egg, .cone, .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle:
            finishShapeDrawing(value: value, geometry: geometry)
            resetShapeDrawingState()
            
        case .font:
            finishTextBoxDrawing(value: value, geometry: geometry)
            resetTextBoxDrawingState()
            
        case .selection:
            finishSelectionDrag()
            isDrawing = false
            
        case .directSelection:
            finishDirectSelectionDrag()
            
        case .bezierPen:
            finishBezierPenDrag()
            
        case .freehand:
            handleFreehandDragEnd()
            
        case .brush:
            handleBrushDragEnd()
            
        case .marker:
            handleMarkerDragEnd()
            
        default:
            break
        }
    }
    
    // MARK: - Unified Selection Drag Handler
    
    /// UNIFIED SELECTION DRAG - Consolidates selection behavior for all areas  
    /// FIXED: Simplified logic to prevent bouncing behavior
    private func handleUnifiedSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        // If a transform handle drag is active (e.g., arrow-tool transform box), ignore canvas drag
        if document.isHandleScalingActive {
            return
        }
        // CORNER TOOL FIX: Prevent object dragging when in corner radius edit mode
        // In this mode, only corner handles should be interactive, not the object itself
        if isCornerRadiusEditMode {
            return
        }
        
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        
        // Start drag if not already dragging
        if !isDrawing {
            // Try to select if nothing selected or dragging unselected object
            if (document.selectedShapeIDs.isEmpty && document.selectedTextIDs.isEmpty) || !isDraggingSelectedObject(at: startLocation) {
                selectObjectAt(startLocation)
            }
            
            // Start drag if we have something selected
            if !document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty {
                selectionDragStart = value.startLocation
                startSelectionDrag()
                isDrawing = true
                print("🎯 UNIFIED SELECTION DRAG: Started at cursor position (\(String(format: "%.1f", selectionDragStart.x)), \(String(format: "%.1f", selectionDragStart.y)))")
            }
        }
        
        // Continue drag if active
        if isDrawing {
            handleSelectionDrag(value: value, geometry: geometry)
        }
    }
    
    // MARK: - State Reset Helpers
    
    private func finishPanGesture() {
        let finalOffset = document.canvasOffset
        initialCanvasOffset = CGPoint.zero
        handToolDragStart = CGPoint.zero
        isPanGestureActive = false
        print("✋ UNIFIED: Hand tool completed - final position: (\(String(format: "%.1f", finalOffset.x)), \(String(format: "%.1f", finalOffset.y)))")
        #if os(macOS)
        // After pan ends, show open hand if still hovering and tool is still hand, else arrow
        if isCanvasHovering && document.currentTool == .hand {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
        #endif
    }
    
    private func resetShapeDrawingState() {
        isDrawing = false
        currentPath = nil
        tempBoundingBoxPath = nil // Clear debug bounding box
        currentDrawingPoints.removeAll()
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
    }

    // MARK: - Eyedropper
    /// Launch the system color sampler and apply the picked color to the active target (fill/stroke)
    private func startEyedropperColorPick() {
        let sampler = NSColorSampler()
        sampler.show { pickedColor in
            guard let nsColor = pickedColor?.usingColorSpace(.sRGB) else { return }
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            let rgb = RGBColor(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
            let vectorColor = VectorColor.rgb(rgb)
            document.setActiveColor(vectorColor)
        }
    }
    
    // MARK: - Coordinate System Validation
    
    /// FIXED: Validate canvas coordinates to ensure proper synchronization
    private func validateCanvasLocation(_ location: CGPoint) -> CGPoint {
        // Check for NaN or infinite values that could cause selection issues
        if location.x.isNaN || location.y.isNaN || location.x.isInfinite || location.y.isInfinite {
            Log.error("❌ INVALID CANVAS COORDINATES: \(location) - using zero point", category: .error)
            return .zero
        }
        
        // Check for extreme values that might indicate coordinate system corruption
        let maxReasonableValue: CGFloat = 1000000.0
        if abs(location.x) > maxReasonableValue || abs(location.y) > maxReasonableValue {
            Log.error("❌ EXTREME CANVAS COORDINATES: \(location) - using zero point", category: .error)
            return .zero
        }
        
        return location
    }
} 