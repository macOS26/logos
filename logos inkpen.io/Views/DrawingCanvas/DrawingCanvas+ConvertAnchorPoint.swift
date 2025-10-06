//
//  DrawingCanvas+ConvertAnchorPoint.swift
//  logos inkpen.io
//
//  Simplified Convert Anchor Point tool functionality
//  Only handles collapsing handles to their anchor points
//

import SwiftUI
import Combine

extension DrawingCanvas {
    func handleConvertAnchorPointTap(at location: CGPoint) {
        // ZOOM-AWARE TOLERANCE: Scale tolerance based on zoom level
        let baseTolerance: Double = 8.0 // Base tolerance in screen pixels
        let zoomLevel = document.zoomLevel
        let tolerance = max(2.0, baseTolerance / zoomLevel) // Minimum 2px, scales with zoom
        
        // FIRST: Check if clicking on an anchor point with collapsed handles to restore them
        if let restoreResult = restoreCollapsedHandlesIfClicked(at: location, tolerance: tolerance) {
            Log.fileOperation("🎯 CONVERT POINT TOOL: Restored handles - \(restoreResult)", level: .info)
            
            // Enable direct selection UI to show the result
            enableDirectSelectionForConvertedPoint(shapeID: restoreResult.shapeID, elementIndex: restoreResult.elementIndex)
            return
        }
        
        // SECOND: Check for handle clicks to collapse them
        if let collapseResult = collapseHandleIfClicked(at: location, tolerance: tolerance) {
            Log.fileOperation("🎯 CONVERT POINT TOOL: Collapsed handle - \(collapseResult)", level: .info)
            
            // Enable direct selection UI to show the result
            enableDirectSelectionForConvertedPoint(shapeID: collapseResult.shapeID, elementIndex: collapseResult.elementIndex)
            return
        }
        
        // If no handle was clicked, try to select the shape for direct selection UI
        tryToSelectShapeForConvertTool(at: location)
        
        // Log.info("Convert Anchor Point: No handle found at location \(location)", category: .general)
    }
    
    // MARK: - Handle Collapse and Restore Functionality
    
    /// Restores collapsed handles if clicking on an anchor point with collapsed handles
    func restoreCollapsedHandlesIfClicked(at location: CGPoint, tolerance: Double) -> (shapeID: UUID, elementIndex: Int)? {
        // Search through all visible layers and shapes for anchor points with collapsed handles
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            // PROTECT LOCKED LAYERS: Don't allow restoring handles on locked layers
            if layer.isLocked {
                continue
            }
            
            let shapes = document.getShapesForLayer(layerIndex)
            for (shapeIndex, shape) in shapes.enumerated().reversed() {
                if !shape.isVisible || shape.isLocked { continue }
                
                // FIRST: Check if clicking on any anchor point that has collapsed handles
                // We need to check ALL elements to find ALL collapsed handles for the clicked point
                var clickedAnchorPoint: VectorPoint?
                var clickedElementIndex: Int?
                
                // Find which anchor point was clicked
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .curve(let to, _, _), .move(let to), .line(let to), .quadCurve(let to, _):
                        let anchorPointLocation = CGPoint(x: to.x, y: to.y)
                        if distance(location, anchorPointLocation) <= tolerance {
                            clickedAnchorPoint = to
                            clickedElementIndex = elementIndex
                            break
                        }
                    default:
                        break
                    }
                }
                
                // If we found a clicked anchor point, check ALL elements for collapsed handles
                if let anchorPoint = clickedAnchorPoint, let elementIndex = clickedElementIndex {
                    var hasCollapsedHandles = false
                    
                    // Check ALL elements for handles that belong to this anchor point
                    for (_, checkElement) in shape.path.elements.enumerated() {
                        switch checkElement {
                        case .curve(_, let control1, let control2):
                            // Check if this element's handles belong to the clicked anchor point
                            let control1Collapsed = (abs(control1.x - anchorPoint.x) < 0.1 && abs(control1.y - anchorPoint.y) < 0.1)
                            let control2Collapsed = (abs(control2.x - anchorPoint.x) < 0.1 && abs(control2.y - anchorPoint.y) < 0.1)
                            
                            if control1Collapsed || control2Collapsed {
                                hasCollapsedHandles = true
                                // Log.info("🎯 FOUND COLLAPSED HANDLE: Element \(checkIndex) has handle collapsed to anchor point", category: .general)
                            }
                            
                        default:
                            break
                        }
                    }
                    
                    if hasCollapsedHandles {
                        // Log.info("🎯 FOUND COLLAPSED HANDLES: Restoring all handles for anchor point at element \(elementIndex)", category: .general)
                        restoreAllHandlesForAnchorPoint(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex, anchorPoint: anchorPoint)
                        return (shape.id, elementIndex)
                    }
                    
                    // NEW FEATURE: If no collapsed handles found, check if both handles are extended and collapse them
                    if !hasCollapsedHandles {
                        // Check if the clicked element has both handles extended (not collapsed)
                        let clickedElement = shape.path.elements[elementIndex]
                        if case .curve(_, let control1, let control2) = clickedElement {
                            // Check if both handles are extended (not collapsed to the anchor point)
                            let control1Extended = !(abs(control1.x - anchorPoint.x) < 0.1 && abs(control1.y - anchorPoint.y) < 0.1)
                            let control2Extended = !(abs(control2.x - anchorPoint.x) < 0.1 && abs(control2.y - anchorPoint.y) < 0.1)
                            
                            if control1Extended && control2Extended {
                                // Log.info("🎯 BOTH HANDLES EXTENDED: Collapsing both handles for anchor point at element \(elementIndex)", category: .general)
                                collapseBothHandlesForAnchorPoint(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex, anchorPoint: anchorPoint)
                                return (shape.id, elementIndex)
                            }
                        }
                    }
                }
            }
        }
        
        return nil // No anchor point with collapsed handles was clicked
    }
    
    // MARK: - Simplified Handle Collapse Functionality
    
    /// Collapses a handle if clicked, returns information about what was collapsed
    func collapseHandleIfClicked(at location: CGPoint, tolerance: Double) -> (shapeID: UUID, elementIndex: Int)? {
        // Search through all visible layers and shapes for handles to collapse
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            // PROTECT LOCKED LAYERS: Don't allow collapsing handles on locked layers
            if layer.isLocked {
                continue
            }
            
            let shapes = document.getShapesForLayer(layerIndex)
            for (shapeIndex, shape) in shapes.enumerated().reversed() {
                if !shape.isVisible || shape.isLocked { continue }
                
                // Check each path element for handles
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .curve(let to, let control1, let control2):
                        // Check control1 handle (outgoing handle of THIS anchor point)
                        let control1HandleLocation = CGPoint(x: control1.x, y: control1.y)
                        if distance(location, control1HandleLocation) <= tolerance {
                            // Check if handle is not already collapsed to the current anchor point
                            let currentAnchorPoint: VectorPoint
                            if elementIndex > 0 {
                                let previousElement = shape.path.elements[elementIndex - 1]
                                switch previousElement {
                                case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                                    currentAnchorPoint = to
                                case .close:
                                    // For close elements, we need to find the last valid point
                                    // This is a fallback case - in practice, close shouldn't be the previous element for a curve
                                    currentAnchorPoint = VectorPoint(0, 0)
                                }
                            } else {
                                currentAnchorPoint = VectorPoint(0, 0)
                            }
                            let handleCollapsed = (abs(control1.x - currentAnchorPoint.x) < 0.1 && abs(control1.y - currentAnchorPoint.y) < 0.1)
                            if !handleCollapsed {
                                collapseControl1Handle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                return (shape.id, elementIndex)
                            }
                        }
                        
                        // Check control2 handle (incoming handle of THIS anchor point)
                        let control2HandleLocation = CGPoint(x: control2.x, y: control2.y)
                        if distance(location, control2HandleLocation) <= tolerance {
                            // Check if handle is not already collapsed to anchor point
                            let handleCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
                            if !handleCollapsed {
                                collapseControl2Handle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                return (shape.id, elementIndex)
                            }
                        }
                        
                    case .move(_), .line(_):
                        // Check control1 handle of NEXT element (outgoing handle from THIS anchor point)
                            if elementIndex + 1 < shape.path.elements.count {
                                let nextElement = shape.path.elements[elementIndex + 1]
                            if case .curve(let nextTo, let nextControl1, _) = nextElement {
                                let control1HandleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y)
                                if distance(location, control1HandleLocation) <= tolerance {
                                    // Check if handle is not already collapsed to the source anchor point
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
                                        collapseNextElementControl1Handle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                        return (shape.id, elementIndex)
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
    
    /// Collapses the control1 handle of a curve element to its anchor point
    func collapseControl1Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex < shape.path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = shape.path.elements[elementIndex]
        var elements = shape.path.elements
        
        switch element {
        case .curve(let to, let originalControl1, let control2):
            // Store the original control1 position for potential restoration
            let handleKey = "\(layerIndex)_\(shapeIndex)_\(elementIndex)_control1"
            document.originalHandlePositions[handleKey] = originalControl1
            
            // FORMULA 1: Control1 handle is the outgoing handle from the current anchor point, so collapse it to the current anchor point
            // We need to get the current anchor point (where the curve starts from)
            let currentAnchorPoint: VectorPoint
            if elementIndex > 0 {
                // Get the previous element's destination point
                let previousElement = elements[elementIndex - 1]
                switch previousElement {
                case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                    currentAnchorPoint = to
                case .close:
                    // For close elements, we need to find the last valid point
                    // This is a fallback case - in practice, close shouldn't be the previous element for a curve
                    currentAnchorPoint = VectorPoint(0, 0)
                }
            } else {
                // If this is the first element, use the move point or default to origin
                currentAnchorPoint = VectorPoint(0, 0)
            }
            let collapsedControl1 = VectorPoint(currentAnchorPoint.x, currentAnchorPoint.y)
            elements[elementIndex] = .curve(to: to, control1: collapsedControl1, control2: control2)
            
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // Sync unified objects system after path changes
            document.updateUnifiedObjectsOptimized()
            document.objectWillChange.send()
            
            // Log.info("✅ COLLAPSED CONTROL1 HANDLE: Handle collapsed to its anchor point", category: .fileOperations)
            
        case .quadCurve(let to, _):
            // For quadCurve, collapsing the handle converts it to a line
            elements[elementIndex] = .line(to: to)
            
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // Sync unified objects system after path changes
            document.updateUnifiedObjectsOptimized()
            document.objectWillChange.send()
            
            // Log.info("✅ COLLAPSED QUAD HANDLE: Converted to line (corner)", category: .fileOperations)
            
        default:
            break
        }
    }
    
    /// Collapses the control2 handle of a curve element to its anchor point
    func collapseControl2Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex < shape.path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = shape.path.elements[elementIndex]
        var elements = shape.path.elements
        
        switch element {
        case .curve(let to, let control1, let originalControl2):
            // Store the original control2 position for potential restoration
            let handleKey = "\(layerIndex)_\(shapeIndex)_\(elementIndex)_control2"
            document.originalHandlePositions[handleKey] = originalControl2
            
            // FORMULA 1: Control2 handle belongs to THIS anchor point (to), so collapse it to THIS point
            let collapsedControl2 = VectorPoint(to.x, to.y)
            elements[elementIndex] = .curve(to: to, control1: control1, control2: collapsedControl2)
            
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // Sync unified objects system after path changes
            document.updateUnifiedObjectsOptimized()
            document.objectWillChange.send()
            
            // Log.info("✅ COLLAPSED CONTROL2 HANDLE: Handle collapsed to its anchor point", category: .fileOperations)
            
        case .quadCurve(let to, _):
            // For quadCurve, collapsing the handle converts it to a line
            elements[elementIndex] = .line(to: to)
            
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // Sync unified objects system after path changes
            document.updateUnifiedObjectsOptimized()
            document.objectWillChange.send()
            
            // Log.info("✅ COLLAPSED QUAD HANDLE: Converted to line (corner)", category: .fileOperations)
            
        default:
            break
        }
    }
    
    /// Collapses the control1 handle of the NEXT element (for line/move elements)
    func collapseNextElementControl1Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex + 1 < shape.path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let nextElement = shape.path.elements[elementIndex + 1]
        var elements = shape.path.elements
        
        switch nextElement {
        case .curve(let to, let originalControl1, let control2):
            // Store the original control1 position for potential restoration
            let handleKey = "\(layerIndex)_\(shapeIndex)_\(elementIndex + 1)_control1"
            document.originalHandlePositions[handleKey] = originalControl1
            
            // FORMULA 2: Control1 handle of NEXT element belongs to the SOURCE anchor point (where it's coming from)
            // Get the source anchor point (the line/move element's anchor point)
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
            
            // Collapse the control1 handle to the source anchor point (where it's coming from)
            elements[elementIndex + 1] = .curve(to: to, control1: sourceAnchorPoint, control2: control2)
            
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // Sync unified objects system after path changes
            document.updateUnifiedObjectsOptimized()
            document.objectWillChange.send()
            
            // Log.info("✅ COLLAPSED NEXT ELEMENT CONTROL1 HANDLE: Handle collapsed to source anchor point", category: .fileOperations)
            
        default:
            break
        }
    }
    
    // MARK: - Handle Restore Functions
    
    /// Restores handles for a curve element to their original positions
    func restoreHandlesForCurveElement(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex < shape.path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = shape.path.elements[elementIndex]
        var elements = shape.path.elements
        
        switch element {
        case .curve(let to, let control1, let control2):
            // Check if we have stored original positions for both handles
            let control1Key = "\(layerIndex)_\(shapeIndex)_\(elementIndex)_control1"
            let control2Key = "\(layerIndex)_\(shapeIndex)_\(elementIndex)_control2"
            
            let control1X = UserDefaults.standard.double(forKey: "\(control1Key)_x")
            let control1Y = UserDefaults.standard.double(forKey: "\(control1Key)_y")
            let control2X = UserDefaults.standard.double(forKey: "\(control2Key)_x")
            let control2Y = UserDefaults.standard.double(forKey: "\(control2Key)_y")
            
            // Check if we have stored positions (non-zero values indicate stored positions)
            let hasControl1Original = (control1X != 0.0 || control1Y != 0.0)
            let hasControl2Original = (control2X != 0.0 || control2Y != 0.0)
            
            // Check which handles are actually collapsed
            let control1Collapsed = (abs(control1.x - to.x) < 0.1 && abs(control1.y - to.y) < 0.1)
            let control2Collapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
            
            var restoredControl1 = control1
            var restoredControl2 = control2
            
            // Only restore control1 if it's collapsed AND we have its original position
            if control1Collapsed && hasControl1Original {
                restoredControl1 = VectorPoint(control1X, control1Y)
            }
            
            // Only restore control2 if it's collapsed AND we have its original position
            if control2Collapsed && hasControl2Original {
                restoredControl2 = VectorPoint(control2X, control2Y)
            }
            
            elements[elementIndex] = .curve(to: to, control1: restoredControl1, control2: restoredControl2)
            
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // Sync unified objects system after path changes
            document.updateUnifiedObjectsOptimized()
            document.objectWillChange.send()
            
            // Log.info("✅ RESTORED CURVE HANDLES: Handles restored to reasonable positions", category: .fileOperations)
            
        default:
            break
        }
    }
    
    /// Restores the control1 handle of the NEXT element (for line/move elements)
    func restoreNextElementControl1Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex + 1 < shape.path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let nextElement = shape.path.elements[elementIndex + 1]
        var elements = shape.path.elements
        
        switch nextElement {
        case .curve(let to, _, let control2):
            // Check if we have stored original position for control1 of the next element
            let control1Key = "\(layerIndex)_\(shapeIndex)_\(elementIndex + 1)_control1"
            let control1X = UserDefaults.standard.double(forKey: "\(control1Key)_x")
            let control1Y = UserDefaults.standard.double(forKey: "\(control1Key)_y")
            
            // Check if we have stored position (non-zero values indicate stored position)
            let hasControl1Original = (control1X != 0.0 || control1Y != 0.0)
            
            var restoredControl1: VectorPoint
            
            if hasControl1Original {
                // Restore to original position
                restoredControl1 = VectorPoint(control1X, control1Y)
            } else {
                // Fallback to reasonable position if no original stored
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
                
                // Restore control1 to a reasonable position (1/3 towards destination)
                restoredControl1 = VectorPoint(
                    sourceAnchorPoint.x + (to.x - sourceAnchorPoint.x) * 0.33,
                    sourceAnchorPoint.y + (to.y - sourceAnchorPoint.y) * 0.33
                )
            }
            
            elements[elementIndex + 1] = .curve(to: to, control1: restoredControl1, control2: control2)
            
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // Sync unified objects system after path changes
            document.updateUnifiedObjectsOptimized()
            document.objectWillChange.send()
            
            // Log.info("✅ RESTORED NEXT ELEMENT CONTROL1 HANDLE: Handle restored to reasonable position", category: .fileOperations)
            
        default:
            break
        }
    }
    
    /// Restores all handles that belong to a specific anchor point
    func restoreAllHandlesForAnchorPoint(layerIndex: Int, shapeIndex: Int, elementIndex: Int, anchorPoint: VectorPoint) {
        guard layerIndex < document.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex < shape.path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        var elements = shape.path.elements
        var needsUpdate = false
        
        // Restore handles from ALL elements that have handles collapsed to this anchor point
        for (checkIndex, checkElement) in elements.enumerated() {
            if case .curve(let to, let control1, let control2) = checkElement {
                // Check if control1 is collapsed to the anchor point
                let control1Collapsed = (abs(control1.x - anchorPoint.x) < 0.1 && abs(control1.y - anchorPoint.y) < 0.1)
                let control2Collapsed = (abs(control2.x - anchorPoint.x) < 0.1 && abs(control2.y - anchorPoint.y) < 0.1)
                
                var restoredControl1 = control1
                var restoredControl2 = control2
                var elementNeedsUpdate = false
                
                // Restore control1 if collapsed
                if control1Collapsed {
                    let control1Key = "\(layerIndex)_\(shapeIndex)_\(checkIndex)_control1"
                    if let originalPosition = document.originalHandlePositions[control1Key] {
                        restoredControl1 = originalPosition
                        elementNeedsUpdate = true
                        // Log.info("🎯 RESTORE: Restoring control1 for element \(checkIndex)", category: .general)
                    }
                }
                
                // Restore control2 if collapsed
                if control2Collapsed {
                    let control2Key = "\(layerIndex)_\(shapeIndex)_\(checkIndex)_control2"
                    if let originalPosition = document.originalHandlePositions[control2Key] {
                        restoredControl2 = originalPosition
                        elementNeedsUpdate = true
                        // Log.info("🎯 RESTORE: Restoring control2 for element \(checkIndex)", category: .general)
                    }
                }
                
                if elementNeedsUpdate {
                    elements[checkIndex] = .curve(to: to, control1: restoredControl1, control2: restoredControl2)
                    needsUpdate = true
                }
            }
        }
        
        if needsUpdate {
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // Sync unified objects system after path changes
            document.updateUnifiedObjectsOptimized()
            document.objectWillChange.send()
            
            // Log.info("✅ RESTORED ALL HANDLES: All handles for anchor point restored to original positions", category: .fileOperations)
        }
    }
    
    /// Collapses both handles of an anchor point at once (like manually clicking both handles)
    func collapseBothHandlesForAnchorPoint(layerIndex: Int, shapeIndex: Int, elementIndex: Int, anchorPoint: VectorPoint) {
        guard layerIndex < document.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex < shape.path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        var elements = shape.path.elements
        var needsUpdate = false
        
        // Collapse handles from ALL elements that have handles belonging to this anchor point
        for (checkIndex, checkElement) in elements.enumerated() {
            if case .curve(let to, let control1, let control2) = checkElement {
                // Check if this element's 'to' point is the clicked anchor point (control2 belongs to this anchor point)
                if abs(to.x - anchorPoint.x) < 0.1 && abs(to.y - anchorPoint.y) < 0.1 {
                    // Store original position for potential restoration
                    let control2Key = "\(layerIndex)_\(shapeIndex)_\(checkIndex)_control2"
                    document.originalHandlePositions[control2Key] = control2
                    
                    // Collapse control2 to the anchor point
                    let collapsedControl2 = VectorPoint(anchorPoint.x, anchorPoint.y)
                    elements[checkIndex] = .curve(to: to, control1: control1, control2: collapsedControl2)
                    needsUpdate = true
                    // Log.info("🎯 COLLAPSE: Collapsed control2 for element \(checkIndex)", category: .general)
                }
                
                // Check if this element's control1 belongs to the clicked anchor point (outgoing handle from this anchor point)
                // We need to check if the previous element's 'to' point is the clicked anchor point
                if checkIndex > 0 {
                    let previousElement = elements[checkIndex - 1]
                    let previousAnchorPoint: VectorPoint
                    
                    switch previousElement {
                    case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                        previousAnchorPoint = to
                    default:
                        previousAnchorPoint = VectorPoint(0, 0)
                    }
                    
                    if abs(previousAnchorPoint.x - anchorPoint.x) < 0.1 && abs(previousAnchorPoint.y - anchorPoint.y) < 0.1 {
                        // Store original position for potential restoration
                        let control1Key = "\(layerIndex)_\(shapeIndex)_\(checkIndex)_control1"
                        document.originalHandlePositions[control1Key] = control1
                        
                        // Collapse control1 to the anchor point
                        let collapsedControl1 = VectorPoint(anchorPoint.x, anchorPoint.y)
                        elements[checkIndex] = .curve(to: to, control1: collapsedControl1, control2: control2)
                        needsUpdate = true
                        // Log.info("🎯 COLLAPSE: Collapsed control1 for element \(checkIndex)", category: .general)
                    }
                }
            }
        }
        
        if needsUpdate {
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // Sync unified objects system after path changes
            document.updateUnifiedObjectsOptimized()
            document.objectWillChange.send()
            
            // Log.info("✅ COLLAPSED ALL HANDLES: All handles for anchor point collapsed to anchor point", category: .fileOperations)
        }
    }
    
    // MARK: - Shape Selection for Convert Tool
    
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
            
            let shapes = document.getShapesForLayer(layerIndex)
            for shape in shapes.reversed() {
                if !shape.isVisible { continue }
                
                var isHit = false
                
                // Use the same hit testing logic as selection tool
                // CRITICAL FIX: Background shapes (Canvas/Pasteboard) should NEVER be selectable
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    // SKIP background shapes entirely - they should not be selectable
                    // Log.info("  - Background shape '\(shape.name)' SKIPPED - not selectable", category: .general)
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
                        
                        // Log.info("🚫 Convert Point Tool clicked on \(lockType) '\(shape.name)' - deselecting current selection", category: .general)
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
        // Log.info("  - Shape: \(shapeID)", category: .general)
        // Log.info("  - Point: Element \(elementIndex)", category: .general)
        // Log.info("  - User can see bezier handles while continuing to use Convert Point tool", category: .general)
    }
}
