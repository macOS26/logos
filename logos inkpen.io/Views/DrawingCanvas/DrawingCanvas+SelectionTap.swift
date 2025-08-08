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
        
        print("🎯 SELECTION TAP: Starting selection at location \(location)")
        print("🎯 SELECTION TAP: Current tool is \(document.currentTool.rawValue)")
        
        // OPTION+CLICK WITH ARROW TOOL: Switch to Direct Selection mode (Adobe Illustrator behavior)
        if isOptionPressed && document.currentTool == .selection {
            print("🎯 OPTION+CLICK: Switching to Direct Selection tool and performing direct selection")
            document.currentTool = .directSelection
            // Perform direct selection at the click location
            handleDirectSelectionTap(at: location)
            return
        }
        
        // CONTROL+CLICK WITH ARROW TOOL: Enter corner radius editing mode (Adobe Illustrator style)
        if isControlPressed && document.currentTool == .selection {
            print("🎯 CONTROL+CLICK: Checking for rounded rectangle to enter corner radius mode")
            
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
                print("🎯 CONTROL+CLICK: Entering corner radius edit mode for rectangle-based shape: \(shape.name)")
                
                // Enable corner radius support if not already enabled
                if !shape.isRoundedRectangle {
                    // This will be handled by the toolbar when it updates the shape
                    print("🎯 CONTROL+CLICK: Shape will be converted to corner-radius-enabled when editing begins")
                }
                
                // Select the shape (corner radius editing now uses dedicated tool)
                document.selectedShapeIDs = [shape.id]
                
                // Clear other selection modes
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                directSelectedShapeIDs.removeAll()
                
                return
            } else if clickedShape != nil {
                print("🎯 CONTROL+CLICK: Clicked shape (\(clickedShape?.name ?? "unknown")) is not a rectangle-based shape")
            } else {
                print("🎯 CONTROL+CLICK: No shape found at click location")
            }
        }
        
        // CRITICAL: Regular Selection tool must clear direct selection
        // Professional tools have mutually exclusive selection modes
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        syncDirectSelectionWithDocument()
        
        // Only handle selection for selection and transform tools
        guard document.currentTool == .selection || 
              document.currentTool == .scale || 
              document.currentTool == .rotate || 
              document.currentTool == .shear || 
              document.currentTool == .warp else { 
            print("🚫 SELECTION TAP: Wrong tool - early return")
            return 
        }
        
        print("🔍 SELECTION TAP: Tool check passed, looking for objects...")
        
        // CRITICAL FIX: Check for text objects FIRST (they should be selectable with selection tool!)
        if let textID = findTextAt(location: location) {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                let textObject = document.textObjects[textIndex]
                
                // PRINT TEXT BOX SETTINGS AS REQUESTED BY USER
                print("🎯 ARROW TOOL SELECTED TEXT BOX UUID: \(textID.uuidString.prefix(8))")
                print("📝 CONTENT: '\(textObject.content)'")
                print("🎨 TYPOGRAPHY SETTINGS:")
                print("  - Font: \(textObject.typography.fontFamily) \(textObject.typography.fontWeight.rawValue) \(textObject.typography.fontStyle.rawValue)")
                print("  - Size: \(textObject.typography.fontSize)pt")
                print("  - Line Height: \(textObject.typography.lineHeight)pt")
                print("  - Line Spacing: \(textObject.typography.lineSpacing)pt")
                print("  - Alignment: \(textObject.typography.alignment.rawValue)")
                print("  - Fill Color: \(textObject.typography.fillColor)")
                print("📦 BOUNDS: \(textObject.bounds)")
                print("📍 POSITION: \(textObject.position)")
                print("🔄 STATES: isEditing=\(textObject.isEditing), isVisible=\(textObject.isVisible), isLocked=\(textObject.isLocked)")
                
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
        
        print("🎯 SELECTION TAP: Looking for shapes at location \(location)")
        
        // Search through layers from top to bottom
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            print("🎯 SELECTION TAP: Checking layer \(layerIndex): '\(layer.name)' with \(layer.shapes.count) shapes")
            
            // Search through shapes from top to bottom (reverse order)
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                print("🎯 SELECTION TAP: Testing shape '\(shape.name)' (group: \(shape.isGroupContainer))")
                
                // PASTEBOARD BEHAVES EXACTLY LIKE CANVAS: Allow hit testing, handle via locked behavior
                
                // FIXED: Proper hit testing logic for stroke vs filled shapes
                var isHit = false
                
                // CRITICAL FIX: Background shapes (Canvas/Pasteboard) should NEVER be selectable
                // They should always trigger deselection like clicking on empty space
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    // SKIP background shapes entirely - they should not be selectable
                    // This ensures clicking on Canvas/Pasteboard always deselects, never selects
                    print("  - Background shape '\(shape.name)' SKIPPED - not selectable")
                    continue
                } else if shape.isGroupContainer {
                    // GROUP HIT TESTING FIX: Check if we hit any of the grouped shapes
                    print("  - Group container: checking \(shape.groupedShapes.count) grouped shapes")
                    for groupedShape in shape.groupedShapes {
                        if !groupedShape.isVisible { continue }
                        
                        print("    - Testing grouped shape '\(groupedShape.name)'")
                        
                        // OPTION KEY ENHANCEMENT: Use path-based selection for grouped shapes too
                        if isOptionPressed {
                            // Option key held: Use precise path-based hit testing only
                            let tolerance: CGFloat = 8.0
                            if PathOperations.hitTest(groupedShape.transformedPath, point: location, tolerance: tolerance) {
                                isHit = true
                                print("      - ⌥ Option group path hit: YES")
                                break
                            } else {
                                print("      - ⌥ Option group path hit: NO")
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
                                    print("      - Stroke hit: YES")
                                    break
                                } else {
                                    print("      - Stroke hit: NO")
                                }
                            } else {
                                // Regular grouped shapes: Use bounds + path hit testing
                                let transformedBounds = groupedShape.bounds.applying(groupedShape.transform)
                                let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                                
                                if expandedBounds.contains(location) {
                                    isHit = true
                                    print("      - Bounds hit: YES")
                                    break
                                } else if PathOperations.hitTest(groupedShape.transformedPath, point: location, tolerance: 8.0) {
                                    isHit = true
                                    print("      - Path hit: YES")
                                    break
                                } else {
                                    print("      - Bounds hit: NO, Path hit: NO")
                                }
                            }
                        }
                    }
                    print("  - Group overall hit result: \(isHit)")
                } else {
                    // OPTION KEY ENHANCEMENT: Use path-based selection when Option key is held
                    if isOptionPressed {
                        // Option key held: Use precise path-based hit testing only
                        let tolerance: CGFloat = 8.0
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
                        print("  - ⌥ Option path-only hit test: \(isHit)")
                    } else {
                        // Regular selection: Use different logic for stroke vs filled
                        let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                        
                        if isStrokeOnly && shape.strokeStyle != nil {
                            // Method 1: Stroke-only shapes - use stroke-based hit testing only
                            let strokeWidth = shape.strokeStyle?.width ?? 1.0
                            let strokeTolerance = max(15.0, strokeWidth + 10.0)
                            
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                            print("  - Regular stroke hit test: \(isHit)")
                        } else {
                            // Method 2: Filled shapes - use bounds + path hit testing
                            let transformedBounds = shape.bounds.applying(shape.transform)
                            let expandedBounds = transformedBounds.insetBy(dx: -12, dy: -12)
                            
                            if expandedBounds.contains(location) {
                                isHit = true
                                print("  - Regular bounds hit test: \(isHit)")
                            } else {
                                // Fallback: precise path hit test
                                isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                                print("  - Regular path hit test: \(isHit)")
                            }
                        }
                    }
                }
                
                if isHit {
                    hitShape = shape
                    hitLayerIndex = layerIndex
                    print("🎯 SELECTION TAP: FOUND HIT - Shape '\(shape.name)' in layer \(layerIndex)")
                    
                    // Check if shape is locked BEFORE setting it as hit
                    if layer.isLocked || shape.isLocked {
                        let lockType = layer.isLocked ? "locked layer" : "locked object"
                        print("🚫 Shape '\(shape.name)' is on \(lockType) - deselecting everything")
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
            print("🎯 SELECTION TAP: NO SHAPE HIT - will deselect")
        }
        
        if let shape = hitShape, let layerIndex = hitLayerIndex {
            print("✅ SELECTION SUCCESS: Selected shape '\(shape.name)' on layer \(layerIndex)")
            
            // CRITICAL FIX: Clear text selection when selecting shapes
            document.selectedTextIDs.removeAll()
            
            if isShiftPressed {
                // SHIFT+CLICK: Add to selection
                document.selectedShapeIDs.insert(shape.id)
            } else if isCommandPressed {
                // CMD+CLICK: Toggle selection
                if document.selectedShapeIDs.contains(shape.id) {
                    document.selectedShapeIDs.remove(shape.id)
                } else {
                    document.selectedShapeIDs.insert(shape.id)
                }
            } else {
                // REGULAR CLICK: Replace selection
                document.selectedShapeIDs = [shape.id]
            }
            
            // Update selected layer
            document.selectedLayerIndex = layerIndex
            
            // Force UI update
            document.objectWillChange.send()
        } else {
            print("❌ NO HIT: No objects found at location \(location)")
            
            // DESELECT ALL: Tap on empty area with selection tool
            let wasSelected = !document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs.removeAll()
            syncDirectSelectionWithDocument()
            
            if wasSelected {
                print("🎯 DESELECTED: Cleared selection due to empty area tap")
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