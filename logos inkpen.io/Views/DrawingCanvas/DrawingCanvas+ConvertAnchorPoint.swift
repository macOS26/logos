//
//  DrawingCanvas+ConvertAnchorPoint.swift
//  logos inkpen.io
//
//  Convert Anchor Point tool functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func handleConvertAnchorPointTap(at location: CGPoint) {
        // ZOOM-AWARE CONVERT POINT TOLERANCE: Scale tolerance based on zoom level
        // At high zoom levels, small physical movements translate to large canvas movements
        // So we need to reduce the tolerance proportionally
        let baseConvertTolerance: Double = 8.0 // Base tolerance in screen pixels
        let zoomLevel = document.zoomLevel
        let tolerance = max(2.0, baseConvertTolerance / zoomLevel) // Minimum 2px, scales with zoom
        
        // TEXT EDITING REMOVED
        
        // NEW: First check if clicking on a handle to remove it
        if let handleRemovalResult = removeHandleIfClicked(at: location, tolerance: tolerance) {
            Log.fileOperation("🎯 CONVERT POINT TOOL: Removed handle - \(handleRemovalResult)", level: .info)
            return
        }
        
        // Search through all visible layers and shapes for points to convert
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            // PROTECT LOCKED LAYERS: Don't allow converting points on locked layers
            if layer.isLocked {
                continue
            }
            
            for (shapeIndex, shape) in layer.shapes.enumerated().reversed() {
                if !shape.isVisible { continue }
                
                // Check each path element for points
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .move(let to), .line(let to):
                        let pointLocation = CGPoint(x: to.x, y: to.y)
                        if distance(location, pointLocation) <= tolerance {
                            // Convert line point to smooth point by adding curve handles
                            convertLineToSmooth(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                            
                            // PROFESSIONAL UX: Auto-enable direct selection to show the result
                            enableDirectSelectionForConvertedPoint(shapeID: shape.id, elementIndex: elementIndex)
                            return
                        }
                    case .curve(let to, _, let control2):
                        let pointLocation = CGPoint(x: to.x, y: to.y)
                        if distance(location, pointLocation) <= tolerance {
                            // CRITICAL FIX: Proper corner point detection
                            // A point is a corner point if BOTH its incoming AND outgoing handles are collapsed to the anchor
                            
                            // Check incoming handle (control2 of current element)
                            let incomingHandleCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
                            
                            // Check outgoing handle (control1 of NEXT element, if it exists)
                            var outgoingHandleCollapsed = true // Default to true if no next element
                            if elementIndex + 1 < shape.path.elements.count {
                                let nextElement = shape.path.elements[elementIndex + 1]
                                if case .curve(_, let nextControl1, _) = nextElement {
                                    outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                                }
                            }
                            
                            let isCornerPoint = incomingHandleCollapsed && outgoingHandleCollapsed
                            
                            if isCornerPoint {
                                // Convert corner point back to smooth curve
                                convertCornerToSmooth(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                Log.fileOperation("🔄 DETECTED CORNER POINT → Converting to SMOOTH", level: .info)
                            } else {
                                // Convert smooth point to corner point
                                convertSmoothToCorner(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                Log.fileOperation("🔄 DETECTED SMOOTH POINT → Converting to CORNER", level: .info)
                            }
                            
                            // PROFESSIONAL UX: Auto-enable direct selection to show the result
                            enableDirectSelectionForConvertedPoint(shapeID: shape.id, elementIndex: elementIndex)
                            return
                        }
                    case .quadCurve(let to, _):
                        let pointLocation = CGPoint(x: to.x, y: to.y)
                        if distance(location, pointLocation) <= tolerance {
                            // Convert quad curve to corner point
                            convertQuadToCorner(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                            
                            // PROFESSIONAL UX: Auto-enable direct selection to show the result
                            enableDirectSelectionForConvertedPoint(shapeID: shape.id, elementIndex: elementIndex)
                            return
                        }
                    case .close:
                        continue
                    }
                }
            }
        }
        
        // If no point was found, try to select the shape for direct selection UI
        tryToSelectShapeForConvertTool(at: location)
        
        // ENHANCED DEBUGGING: Show detailed coordinate info for toolbar bleed-through investigation
        let documentBounds = document.documentBounds
        Log.info("Convert Anchor Point: No point found at location \(location)", category: .general)
        Log.info("  - Document bounds: \(documentBounds)", category: .general)
        Log.info("  - Is within document: \(documentBounds.contains(location))", category: .general)
        Log.info("  - Current tool: \(document.currentTool.rawValue)", category: .general)
        Log.info("  - This might be a toolbar click bleeding through to canvas!", category: .general)
    }
    
    // PROFESSIONAL UX: Auto-select shapes when clicking with Convert Point tool
    internal func tryToSelectShapeForConvertTool(at location: CGPoint) {
        // Search for any shape at the click location
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            // PROTECT LOCKED LAYERS: Don't allow selecting shapes on locked layers for convert tool
            if layer.isLocked {
                continue
            }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                // PASTEBOARD BEHAVES EXACTLY LIKE CANVAS: Allow hit testing, handle via locked behavior
                
                var isHit = false
                
                // Use the same hit testing logic as selection tool
                // CRITICAL FIX: Background shapes (Canvas/Pasteboard) should NEVER be selectable
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    // SKIP background shapes entirely - they should not be selectable
                    Log.info("  - Background shape '\(shape.name)' SKIPPED - not selectable", category: .general)
                    continue
                } else {
                    // Regular shapes: Use different logic for stroke vs filled
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                    
                    if isStrokeOnly && shape.strokeStyle != nil {
                        // Stroke-only shapes: Use stroke-based hit testing
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                    } else {
                        // Regular shapes: Use bounds + path hit testing
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                        
                        if expandedBounds.contains(location) {
                            isHit = true
                        } else {
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                        }
                    }
                }
                
                if isHit {
                    // IMPROVED LOCKED BEHAVIOR: Handle locked layers/objects properly
                    if layer.isLocked || shape.isLocked {
                        let lockType = layer.isLocked ? "locked layer" : "locked object"
                        Log.info("🚫 Convert Point Tool clicked on \(lockType) '\(shape.name)' - deselecting current selection", category: .general)
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        directSelectedShapeIDs.removeAll()
                        syncDirectSelectionWithDocument()
                        document.objectWillChange.send()
                        return
                    }
                    
                    // Select this shape for direct selection UI
                    document.selectedShapeIDs.removeAll()
                    document.selectedTextIDs.removeAll()
                    selectedPoints.removeAll()
                    selectedHandles.removeAll()
                    directSelectedShapeIDs.removeAll()
                    
                    // Direct-select the shape to show all anchor points and handles
                    directSelectedShapeIDs.insert(shape.id)
                    syncDirectSelectionWithDocument()
                    
                    // Force UI update
                    document.objectWillChange.send()
                    
                    Log.fileOperation("🎯 CONVERT POINT TOOL: Selected shape \(shape.name) for direct selection UI", level: .info)
                    return
                }
            }
        }
        
        // If no shape was hit, clear all selections
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        syncDirectSelectionWithDocument()
        document.objectWillChange.send()
    }
    
    // PROFESSIONAL UX IMPROVEMENT: Enable direct selection UI for convert point tool
    internal func enableDirectSelectionForConvertedPoint(shapeID: UUID, elementIndex: Int) {
        // Clear any existing selections but KEEP the convert point tool active
        document.selectedShapeIDs.removeAll()
        document.selectedTextIDs.removeAll()
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        
        // DON'T switch tools - keep Convert Point tool active
        // But enable direct selection UI mode for this tool
        
        // Direct-select the shape that was modified (for UI display)
        directSelectedShapeIDs.insert(shapeID)
        syncDirectSelectionWithDocument()
        
        // Select the specific point that was converted for immediate feedback
        let pointID = PointID(
            shapeID: shapeID,
            pathIndex: 0,
            elementIndex: elementIndex
        )
        selectedPoints.insert(pointID)
        
        // Force UI update to show the changes
        document.objectWillChange.send()
        
        Log.fileOperation("🎯 CONVERT POINT TOOL: Enabled direct selection UI (tool stays active)", level: .info)
        Log.info("  - Shape: \(shapeID)", category: .general)
        Log.info("  - Point: Element \(elementIndex)", category: .general)
        Log.info("  - User can see bezier handles while continuing to use Convert Point tool", category: .general)
    }
    
    internal func convertLineToSmooth(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .line(let to):
            // CRITICAL FIX: Convert line to curve but ONLY modify handles that belong to this anchor point
            let point = VectorPoint(to.x, to.y)
            let handleLength: Double = 30.0
            
            // STEP 1: Convert current line element to curve with incoming handle
            let incomingHandle = VectorPoint(point.x - handleLength, point.y)
            elements[elementIndex] = .curve(to: point, control1: VectorPoint(point.x, point.y), control2: incomingHandle)
            
            // STEP 2: Add outgoing handle to NEXT element (if it exists and is a curve)
            if elementIndex + 1 < elements.count {
                if case .curve(let nextTo, _, let nextControl2) = elements[elementIndex + 1] {
                    let outgoingHandle = VectorPoint(point.x + handleLength, point.y)
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: outgoingHandle, control2: nextControl2)
                }
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            Log.info("✅ CONVERTED LINE TO SMOOTH CURVE with proper handle structure", category: .fileOperations)
            
        case .move(let to):
            // STEP 1: Move elements can't be converted directly, but we can add outgoing handle to next element
            let point = VectorPoint(to.x, to.y)
            let handleLength: Double = 30.0
            
            // Add outgoing handle to NEXT element (if it exists and is a curve)
            if elementIndex + 1 < elements.count {
                if case .curve(let nextTo, _, let nextControl2) = elements[elementIndex + 1] {
                    let outgoingHandle = VectorPoint(point.x + handleLength, point.y)
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: outgoingHandle, control2: nextControl2)
                    
                    document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    
                    Log.info("✅ ADDED OUTGOING HANDLE to move point", category: .fileOperations)
                }
            }
            
        default:
            break
        }
    }
    
    internal func convertSmoothToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .curve(let to, _, _):
            // CRITICAL FIX: Convert curve to line element (removes handles completely)
            let cornerPoint = VectorPoint(to.x, to.y)
            
            // STEP 1: Convert current curve element to line element
            elements[elementIndex] = .line(to: cornerPoint)
            
            // STEP 2: Convert NEXT element to line if it's a curve (removes outgoing handle)
            if elementIndex + 1 < elements.count {
                if case .curve(let nextTo, _, _) = elements[elementIndex + 1] {
                    elements[elementIndex + 1] = .line(to: nextTo)
                }
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            Log.info("✅ CONVERTED SMOOTH CURVE TO CORNER POINT (handles completely removed)", category: .fileOperations)
        default:
            break
        }
    }
    
    internal func convertCornerToSmooth(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .curve(let to, let control1, _):
            // CRITICAL FIX: Create proper 180-degree symmetric handles based on path direction
            let point = VectorPoint(to.x, to.y)
            let handleLength: Double = 30.0
            
            // Calculate the direction vector based on adjacent points
            var directionVector = CGPoint(x: 1.0, y: 0.0) // Default horizontal
            
            // Try to get direction from previous point
            if elementIndex > 0 {
                let prevElement = elements[elementIndex - 1]
                var prevPoint: VectorPoint?
                
                switch prevElement {
                case .move(let from), .line(let from):
                    prevPoint = from
                case .curve(let from, _, _):
                    prevPoint = from
                default:
                    break
                }
                
                if let prev = prevPoint {
                    let dx = point.x - prev.x
                    let dy = point.y - prev.y
                    let length = sqrt(dx * dx + dy * dy)
                    if length > 0.1 {
                        directionVector = CGPoint(x: dx / length, y: dy / length)
                    }
                }
            }
            // If no previous point, try to get direction from next point
            else if elementIndex + 1 < elements.count {
                let nextElement = elements[elementIndex + 1]
                var nextPoint: VectorPoint?
                
                switch nextElement {
                case .move(let next), .line(let next):
                    nextPoint = next
                case .curve(let next, _, _):
                    nextPoint = next
                default:
                    break
                }
                
                if let next = nextPoint {
                    let dx = next.x - point.x
                    let dy = next.y - point.y
                    let length = sqrt(dx * dx + dy * dy)
                    if length > 0.1 {
                        directionVector = CGPoint(x: dx / length, y: dy / length)
                    }
                }
            }
            
            // ROTATE HANDLES BY -45 DEGREES for better visibility while maintaining 180-degree symmetry
            let rotationAngle = -45.0 * .pi / 180.0  // -45 degrees in radians
            let cosAngle = cos(rotationAngle)
            let sinAngle = sin(rotationAngle)
            
            // Apply rotation to direction vector
            let rotatedDirX = directionVector.x * cosAngle - directionVector.y * sinAngle
            let rotatedDirY = directionVector.x * sinAngle + directionVector.y * cosAngle
            
            // Create symmetric handles using the rotated direction vector (EXACTLY like pen tool)
            let outgoingHandle = VectorPoint(
                point.x + rotatedDirX * handleLength,
                point.y + rotatedDirY * handleLength
            )
            let incomingHandle = VectorPoint(
                point.x - rotatedDirX * handleLength,
                point.y - rotatedDirY * handleLength
            )
            
            // STEP 1: Add incoming handle (control2) to current element
            elements[elementIndex] = .curve(to: point, control1: control1, control2: incomingHandle)
            
            // STEP 2: Add outgoing handle (control1 of NEXT element)
            if elementIndex + 1 < elements.count {
                if case .curve(let nextTo, _, let nextControl2) = elements[elementIndex + 1] {
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: outgoingHandle, control2: nextControl2)
                }
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            Log.info("✅ CONVERTED CORNER POINT TO SMOOTH CURVE with 180-degree symmetric handles", category: .fileOperations)
        default:
            break
        }
    }
    
    internal func convertQuadToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        
        switch element {
        case .quadCurve(let to, _):
            // Convert quad curve to line element (completely removes handles)
            let cornerPoint = VectorPoint(to.x, to.y)
            let newElement = PathElement.line(to: cornerPoint)
            document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            Log.info("✅ CONVERTED QUAD CURVE TO CORNER POINT (handles completely removed)", category: .fileOperations)
        default:
            break
        }
    }
    
    // MARK: - Handle Removal Functionality
    
    /// Removes a handle if clicked, returns description of what was removed
    private func removeHandleIfClicked(at location: CGPoint, tolerance: Double) -> String? {
        // Search through all visible layers and shapes for handles to remove
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            // PROTECT LOCKED LAYERS: Don't allow removing handles on locked layers
            if layer.isLocked {
                continue
            }
            
            for (shapeIndex, shape) in layer.shapes.enumerated().reversed() {
                if !shape.isVisible || shape.isLocked { continue }
                
                // Check each path element for handles
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .curve(let to, _, let control2):
                        // Check incoming handle (control2 of current element)
                        let incomingHandleLocation = CGPoint(x: control2.x, y: control2.y)
                        if distance(location, incomingHandleLocation) <= tolerance {
                            // Check if handle is not already collapsed to anchor point
                            let handleCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
                            if !handleCollapsed {
                                removeIncomingHandle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                return "incoming handle at element \(elementIndex)"
                            }
                        }
                        
                        // Check outgoing handle (control1 of NEXT element, if it exists)
                        if elementIndex + 1 < shape.path.elements.count {
                            let nextElement = shape.path.elements[elementIndex + 1]
                            if case .curve(_, let nextControl1, _) = nextElement {
                                let outgoingHandleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y)
                                if distance(location, outgoingHandleLocation) <= tolerance {
                                    // Check if handle is not already collapsed to anchor point
                                    let handleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                                    if !handleCollapsed {
                                        removeOutgoingHandle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                        return "outgoing handle at element \(elementIndex)"
                                    }
                                }
                            }
                        }
                        
                    case .move(let to), .line(let to):
                        // Check outgoing handle (control1 of NEXT element, if it exists)
                        if elementIndex + 1 < shape.path.elements.count {
                            let nextElement = shape.path.elements[elementIndex + 1]
                            if case .curve(_, let nextControl1, _) = nextElement {
                                let outgoingHandleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y)
                                if distance(location, outgoingHandleLocation) <= tolerance {
                                    // Check if handle is not already collapsed to anchor point
                                    let handleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                                    if !handleCollapsed {
                                        removeOutgoingHandle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                        return "outgoing handle at element \(elementIndex)"
                                    }
                                }
                            }
                        }
                        
                    default:
                        break
                    }
                }
            }
        }
        
        return nil // No handle was clicked
    }
    
    /// Removes the incoming handle (control2) of a curve element
    private func removeIncomingHandle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .curve(let to, let control1, _):
            // Check if outgoing handle is also collapsed (from next element)
            var shouldConvertToLine = false
            if elementIndex + 1 < elements.count {
                if case .curve(_, let nextControl1, _) = elements[elementIndex + 1] {
                    // Check if outgoing handle is collapsed to the current anchor point
                    let outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                    if outgoingHandleCollapsed {
                        shouldConvertToLine = true
                    }
                }
            }
            
            if shouldConvertToLine {
                // Both handles are collapsed - convert to line element
                elements[elementIndex] = .line(to: to)
                
                // Also convert next element to line if it's a curve
                if elementIndex + 1 < elements.count {
                    if case .curve(let nextTo, _, _) = elements[elementIndex + 1] {
                        elements[elementIndex + 1] = .line(to: nextTo)
                    }
                }
                
                Log.info("✅ REMOVED INCOMING HANDLE: Converted to line element (both handles removed)", category: .fileOperations)
            } else {
                // Only incoming handle collapsed - keep as curve but collapse the handle
                elements[elementIndex] = .curve(to: to, control1: control1, control2: to)
                Log.info("✅ REMOVED INCOMING HANDLE: Element \(elementIndex)", category: .fileOperations)
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
        default:
            break
        }
    }
    
    /// Removes the outgoing handle (control1) of the next element
    private func removeOutgoingHandle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex + 1 < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let nextElement = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex + 1]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch nextElement {
        case .curve(let to, _, let control2):
            // Check if incoming handle is also collapsed (from current element)
            var shouldConvertToLine = false
            if elementIndex >= 0 && elementIndex < elements.count {
                if case .curve(_, _, let currentControl2) = elements[elementIndex] {
                    // Check if incoming handle is collapsed to the next anchor point
                    let incomingHandleCollapsed = (abs(currentControl2.x - to.x) < 0.1 && abs(currentControl2.y - to.y) < 0.1)
                    if incomingHandleCollapsed {
                        shouldConvertToLine = true
                    }
                }
            }
            
            if shouldConvertToLine {
                // Both handles are collapsed - convert to line element
                elements[elementIndex + 1] = .line(to: to)
                
                // Also convert current element to line if it's a curve
                if elementIndex >= 0 && elementIndex < elements.count {
                    if case .curve(let currentTo, _, _) = elements[elementIndex] {
                        elements[elementIndex] = .line(to: currentTo)
                    }
                }
                
                Log.info("✅ REMOVED OUTGOING HANDLE: Converted to line element (both handles removed)", category: .fileOperations)
            } else {
                // Only outgoing handle collapsed - keep as curve but collapse the handle
                elements[elementIndex + 1] = .curve(to: to, control1: to, control2: control2)
                Log.info("✅ REMOVED OUTGOING HANDLE: Element \(elementIndex + 1)", category: .fileOperations)
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
        default:
            break
        }
    }
} 