//
//  DrawingCanvas+ConvertAnchorPoint.swift
//  logos inkpen.io
//
//  Simplified Convert Anchor Point tool functionality
//  Only handles collapsing handles to their anchor points
//

import SwiftUI

extension DrawingCanvas {
    func handleConvertAnchorPointTap(at location: CGPoint) {
        // ZOOM-AWARE TOLERANCE: Scale tolerance based on zoom level
        let baseTolerance: Double = 8.0 // Base tolerance in screen pixels
        let zoomLevel = document.zoomLevel
        let tolerance = max(2.0, baseTolerance / zoomLevel) // Minimum 2px, scales with zoom
        
        // SIMPLIFIED: Only check for handle clicks to collapse them
        if let collapseResult = collapseHandleIfClicked(at: location, tolerance: tolerance) {
            Log.fileOperation("🎯 CONVERT POINT TOOL: Collapsed handle - \(collapseResult)", level: .info)
            
            // Enable direct selection UI to show the result
            enableDirectSelectionForConvertedPoint(shapeID: collapseResult.shapeID, elementIndex: collapseResult.elementIndex)
            return
        }
        
        // If no handle was clicked, try to select the shape for direct selection UI
        tryToSelectShapeForConvertTool(at: location)
        
        Log.info("Convert Anchor Point: No handle found at location \(location)", category: .general)
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
            
            for (shapeIndex, shape) in layer.shapes.enumerated().reversed() {
                if !shape.isVisible || shape.isLocked { continue }
                
                // Check each path element for handles
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .curve(let to, let control1, let control2):
                        // Check control1 handle (outgoing handle of THIS anchor point)
                        let control1HandleLocation = CGPoint(x: control1.x, y: control1.y)
                        if distance(location, control1HandleLocation) <= tolerance {
                            // Check if handle is not already collapsed to anchor point
                            let handleCollapsed = (abs(control1.x - to.x) < 0.1 && abs(control1.y - to.y) < 0.1)
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
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .curve(let to, _, let control2):
            // FORMULA 1: Control1 handle belongs to THIS anchor point (to), so collapse it to THIS point
            let collapsedControl1 = VectorPoint(to.x, to.y)
            elements[elementIndex] = .curve(to: to, control1: collapsedControl1, control2: control2)
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ COLLAPSED CONTROL1 HANDLE: Handle collapsed to its anchor point", category: .fileOperations)
            
        case .quadCurve(let to, _):
            // For quadCurve, collapsing the handle converts it to a line
            elements[elementIndex] = .line(to: to)
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ COLLAPSED QUAD HANDLE: Converted to line (corner)", category: .fileOperations)
            
        default:
            break
        }
    }
    
    /// Collapses the control2 handle of a curve element to its anchor point
    func collapseControl2Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .curve(let to, let control1, _):
            // FORMULA 1: Control2 handle belongs to THIS anchor point (to), so collapse it to THIS point
            let collapsedControl2 = VectorPoint(to.x, to.y)
            elements[elementIndex] = .curve(to: to, control1: control1, control2: collapsedControl2)
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ COLLAPSED CONTROL2 HANDLE: Handle collapsed to its anchor point", category: .fileOperations)
            
        case .quadCurve(let to, _):
            // For quadCurve, collapsing the handle converts it to a line
            elements[elementIndex] = .line(to: to)
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ COLLAPSED QUAD HANDLE: Converted to line (corner)", category: .fileOperations)
            
        default:
            break
        }
    }
    
    /// Collapses the control1 handle of the NEXT element (for line/move elements)
    func collapseNextElementControl1Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex + 1 < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let nextElement = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex + 1]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch nextElement {
        case .curve(let to, _, let control2):
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
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            // Sync unified objects system after path changes
            document.syncUnifiedObjectsAfterPropertyChange()
            document.objectWillChange.send()
            
            Log.info("✅ COLLAPSED NEXT ELEMENT CONTROL1 HANDLE: Handle collapsed to source anchor point", category: .fileOperations)
            
        default:
            break
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
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
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
}
