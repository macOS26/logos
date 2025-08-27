//
//  DrawingCanvas+ConvertAnchorPoint.swift
//  logos inkpen.io
//
//  Convert Anchor Point tool functionality
//

import SwiftUI

extension DrawingCanvas {
    func handleConvertAnchorPointTap(at location: CGPoint) {
        // ZOOM-AWARE CONVERT POINT TOLERANCE: Scale tolerance based on zoom level
        // At high zoom levels, small physical movements translate to large canvas movements
        // So we need to reduce the tolerance proportionally
        let baseConvertTolerance: Double = 8.0 // Base tolerance in screen pixels
        let zoomLevel = document.zoomLevel
        let tolerance = max(2.0, baseConvertTolerance / zoomLevel) // Minimum 2px, scales with zoom
                
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
    func enableDirectSelectionForConvertedPoint(shapeID: UUID, elementIndex: Int) {
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
    
    func convertLineToSmooth(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .line(let to):
            // Create smooth point with BOTH handles on THIS point
            let point = VectorPoint(to.x, to.y)
            let handleLength: Double = 30.0
            
            // Calculate direction based on adjacent points
            var directionVector = CGPoint(x: 1.0, y: 0.0) // Default horizontal
            
            if elementIndex > 0, elementIndex + 1 < elements.count {
                // Get previous and next points to determine tangent
                var prevPoint: VectorPoint?
                var nextPoint: VectorPoint?
                
                switch elements[elementIndex - 1] {
                case .move(let p), .line(let p):
                    prevPoint = p
                case .curve(let p, _, _), .quadCurve(let p, _):
                    prevPoint = p
                default:
                    break
                }
                
                switch elements[elementIndex + 1] {
                case .move(let p), .line(let p):
                    nextPoint = p
                case .curve(let p, _, _), .quadCurve(let p, _):
                    nextPoint = p
                default:
                    break
                }
                
                if let prev = prevPoint, let next = nextPoint {
                    let dx = next.x - prev.x
                    let dy = next.y - prev.y
                    let length = sqrt(dx * dx + dy * dy)
                    if length > 0.1 {
                        directionVector = CGPoint(x: dx / length, y: dy / length)
                    }
                }
            }
            
            // Create handles extending from THIS point
            let incomingHandle = VectorPoint(
                point.x - directionVector.x * handleLength,
                point.y - directionVector.y * handleLength
            )
            let outgoingHandle = VectorPoint(
                point.x + directionVector.x * handleLength,
                point.y + directionVector.y * handleLength
            )
            
            // THIS element gets the incoming handle (control2)
            // Convert to curve with incoming handle
            elements[elementIndex] = .curve(to: point, control1: point, control2: incomingHandle)
            
            // NEXT element gets the outgoing handle (control1) 
            if elementIndex + 1 < elements.count {
                switch elements[elementIndex + 1] {
                case .line(let nextTo):
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: outgoingHandle, control2: nextTo)
                case .curve(let nextTo, _, let nextControl2):
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: outgoingHandle, control2: nextControl2)
                case .quadCurve(let nextTo, _):
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: outgoingHandle, control2: nextTo)
                default:
                    break
                }
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // CRITICAL FIX: Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ CONVERTED LINE TO SMOOTH: Both handles on same point", category: .fileOperations)
            
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
                    
                    // CRITICAL FIX: Sync unified objects system after path changes
                    document.syncUnifiedObjectsAfterPropertyChange()
                    document.objectWillChange.send()
                    
                    Log.info("✅ ADDED OUTGOING HANDLE to move point", category: .fileOperations)
                }
            }
            
        default:
            break
        }
    }
    
    func convertSmoothToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .curve(let to, _, _):
            // Convert to LINE element (true corner point with no handles)
            let cornerPoint = VectorPoint(to.x, to.y)
            elements[elementIndex] = .line(to: cornerPoint)
            
            // Check NEXT element and handle it properly
            if elementIndex + 1 < elements.count {
                switch elements[elementIndex + 1] {
                case .curve(let nextTo, _, let nextControl2):
                    // Check if control2 is also collapsed (making it a corner point)
                    let nextControl2Collapsed = (abs(nextControl2.x - nextTo.x) < 0.1 && abs(nextControl2.y - nextTo.y) < 0.1)
                    
                    if nextControl2Collapsed {
                        // Both handles would be collapsed - convert to line (corner)
                        elements[elementIndex + 1] = .line(to: nextTo)
                    } else {
                        // Keep control2 - convert to quadCurve (cusp)
                        elements[elementIndex + 1] = .quadCurve(to: nextTo, control: nextControl2)
                    }
                default:
                    break
                }
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // CRITICAL FIX: Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ CONVERTED SMOOTH TO CORNER: Collapsed both handles to anchor point", category: .fileOperations)
        default:
            break
        }
    }
    
    func convertCornerToSmooth(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        // This function is called from the line detection in handleConvertAnchorPointTap
        // So we handle .line elements, NOT .curve elements
        switch element {
        case .line(let to), .curve(let to, _, _):
            // Create smooth point with both handles 180° apart
            let point = VectorPoint(to.x, to.y)
            let handleLength: Double = 30.0
            
            // Use simple horizontal handles
            let incomingHandle = VectorPoint(point.x - handleLength, point.y)
            let outgoingHandle = VectorPoint(point.x + handleLength, point.y)
            
            // Convert THIS element to curve with incoming handle
            elements[elementIndex] = .curve(to: point, control1: point, control2: incomingHandle)
            
            // Update NEXT element with outgoing handle
            if elementIndex + 1 < elements.count {
                switch elements[elementIndex + 1] {
                case .curve(let nextTo, _, let nextControl2):
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: outgoingHandle, control2: nextControl2)
                case .line(let nextTo):
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: outgoingHandle, control2: nextTo)
                default:
                    break
                }
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // CRITICAL FIX: Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ CONVERTED CORNER TO SMOOTH: Both handles 180° aligned", category: .fileOperations)
        default:
            break
        }
    }
    
    func convertQuadToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
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
            
            // CRITICAL FIX: Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ CONVERTED QUAD CURVE TO CORNER POINT (handles completely removed)", category: .fileOperations)
        default:
            break
        }
    }
    
    // MARK: - Handle Removal Functionality
    
    /// Removes a handle if clicked, returns description of what was removed
    func removeHandleIfClicked(at location: CGPoint, tolerance: Double) -> String? {
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
                    case .curve(let to, let control1, let control2):
                        // Check control1 handle (belongs to THIS anchor point)
                        let control1HandleLocation = CGPoint(x: control1.x, y: control1.y)
                        if distance(location, control1HandleLocation) <= tolerance {
                            // Check if handle is not already collapsed to anchor point
                            let handleCollapsed = (abs(control1.x - to.x) < 0.1 && abs(control1.y - to.y) < 0.1)
                            if !handleCollapsed {
                                removeControl1Handle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                return "control1 handle at element \(elementIndex)"
                            }
                        }
                        
                        // Check control2 handle (belongs to THIS anchor point)
                        let control2HandleLocation = CGPoint(x: control2.x, y: control2.y)
                        if distance(location, control2HandleLocation) <= tolerance {
                            // Check if handle is not already collapsed to anchor point
                            let handleCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
                            if !handleCollapsed {
                                removeControl2Handle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                return "control2 handle at element \(elementIndex)"
                            }
                        }
                        
                    case .move(_), .line(_):
                        // Check control1 handle of NEXT element (if it exists)
                        if elementIndex + 1 < shape.path.elements.count {
                            let nextElement = shape.path.elements[elementIndex + 1]
                            if case .curve(let nextTo, let nextControl1, _) = nextElement {
                                let control1HandleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y)
                                if distance(location, control1HandleLocation) <= tolerance {
                                    // Check if handle is not already collapsed to the source anchor point (where it's coming from)
                                    let sourceAnchorPoint: VectorPoint
                                    switch element {
                                    case .move(let to), .line(let to):
                                        sourceAnchorPoint = to
                                    case .curve(let to, _, _), .quadCurve(let to, _):
                                        sourceAnchorPoint = to
                                    default:
                                        sourceAnchorPoint = nextTo // Fallback
                                    }
                                    let handleCollapsed = (abs(nextControl1.x - sourceAnchorPoint.x) < 0.1 && abs(nextControl1.y - sourceAnchorPoint.y) < 0.1)
                                    if !handleCollapsed {
                                        removeNextElementControl1Handle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                        return "control1 handle of next element at element \(elementIndex)"
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
    
    /// Removes the control1 handle of a curve element
    func removeControl1Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .curve(let to, _, let control2):
            // Check if control2 is also collapsed
            let control2Collapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
            
            if control2Collapsed {
                // Both handles collapsed/removed - convert to line (corner point)
                elements[elementIndex] = .line(to: to)
            } else {
                // Keep control2 - convert to quadCurve (cusp point)
                elements[elementIndex] = .quadCurve(to: to, control: control2)
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // CRITICAL FIX: Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ REMOVED CONTROL1 HANDLE: Converted to \(control2Collapsed ? "line (corner)" : "quadCurve (cusp)")", category: .fileOperations)
            
        case .quadCurve(let to, _):
            // Removing the only handle - convert to line (corner point)
            elements[elementIndex] = .line(to: to)
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // CRITICAL FIX: Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ REMOVED QUAD HANDLE: Converted to line (corner)", category: .fileOperations)
            
        default:
            break
        }
    }
    
    /// Removes the control2 handle of a curve element
    func removeControl2Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .curve(let to, let control1, _):
            // Check if control1 is also collapsed
            let control1Collapsed = (abs(control1.x - to.x) < 0.1 && abs(control1.y - to.y) < 0.1)
            
            if control1Collapsed {
                // Both handles collapsed/removed - convert to line (corner point)
                elements[elementIndex] = .line(to: to)
            } else {
                // Keep control1 - convert to quadCurve (cusp point)
                elements[elementIndex] = .quadCurve(to: to, control: control1)
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // CRITICAL FIX: Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ REMOVED CONTROL2 HANDLE: Converted to \(control1Collapsed ? "line (corner)" : "quadCurve (cusp)")", category: .fileOperations)
            
        case .quadCurve(let to, _):
            // Removing the only handle - convert to line (corner point)
            elements[elementIndex] = .line(to: to)
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // CRITICAL FIX: Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ REMOVED QUAD HANDLE: Converted to line (corner)", category: .fileOperations)
            
        default:
            break
        }
    }
    
    /// Removes the control1 handle of the NEXT element (for line/move elements)
    func removeNextElementControl1Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex + 1 < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let nextElement = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex + 1]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch nextElement {
        case .curve(let to, _, let control2):
            // FIXED: Collapse control1 handle to the anchor point where it's coming from (the line/move element's anchor point)
            // Get the anchor point of the current element (line/move) that the handle is coming from
            let currentElement = elements[elementIndex]
            let sourceAnchorPoint: VectorPoint
            
            switch currentElement {
            case .move(let to), .line(let to):
                sourceAnchorPoint = to
            case .curve(let to, _, _), .quadCurve(let to, _):
                sourceAnchorPoint = to
            default:
                sourceAnchorPoint = to // Fallback
            }
            
            // Collapse the control1 handle to the source anchor point
            elements[elementIndex + 1] = .curve(to: to, control1: sourceAnchorPoint, control2: control2)
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // CRITICAL FIX: Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ REMOVED NEXT ELEMENT CONTROL1 HANDLE: Collapsed to source anchor point", category: .fileOperations)
            
        default:
            break
        }
    }
} 
