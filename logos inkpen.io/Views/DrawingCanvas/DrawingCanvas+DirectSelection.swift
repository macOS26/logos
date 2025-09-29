//
//  DrawingCanvas+DirectSelection.swift
//  logos inkpen.io
//
//  Direct selection functionality
//

import SwiftUI
import Combine

extension DrawingCanvas {
    // MARK: - PROFESSIONAL ANCHOR POINT AND HANDLE SELECTION
    
    /// STAGE 1: Select individual anchor points or handles (when shape already direct-selected)
    internal func selectIndividualAnchorPointOrHandle(at location: CGPoint, tolerance: Double) -> Bool {
        // Search through all direct-selected shapes for individual anchor points and handles
        for shapeID in directSelectedShapeIDs {
            // Find the shape in the document
            for layerIndex in document.layers.indices {
                let layer = document.layers[layerIndex]
                let shapes = document.getShapesForLayer(layerIndex)
                if let shape = shapes.first(where: { $0.id == shapeID }) {
                    
                    // IMPROVED LOCKED BEHAVIOR: Instead of preventing interaction, deselect current selection
                    if layer.isLocked || shape.isLocked {
                        let lockType = layer.isLocked ? "locked layer" : "locked object"
                        Log.info("🚫 Clicked on points/handles of \(lockType) '\(shape.name)' - deselecting current selection", category: .general)
                        directSelectedShapeIDs.removeAll()
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        syncDirectSelectionWithDocument()
                        document.objectWillChange.send()
                        return true
                    }
                    
                    // GROUP ANCHOR POINT SELECTION FIX: Handle groups differently
                    if shape.isGroupContainer {
                        // For groups, check anchor points in all grouped shapes
                        Log.info("🔍 Checking anchor points in group '\(shape.name)' with \(shape.groupedShapes.count) shapes", category: .general)
                        for groupedShape in shape.groupedShapes {
                            if !groupedShape.isVisible { continue }
                            
                            // Check each path element for points and handles in grouped shapes
                            if checkAnchorPointsInShape(groupedShape, at: location, tolerance: tolerance) {
                                return true
                            }
                        }
                    } else {
                        // For individual shapes, check anchor points normally
                        if checkAnchorPointsInShape(shape, at: location, tolerance: tolerance) {
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    /// Helper function to check anchor points in a specific shape
    private func checkAnchorPointsInShape(_ shape: VectorShape, at location: CGPoint, tolerance: Double) -> Bool {
        // IMPROVED SELECTION: Expanded hit areas for easier selection
        // Points: 4x4 pixel square with 1-2px border = 5-6px radius for easier selection
        // Handles: 8x8 pixel circle = 4px radius for precise selection
        let pointSelectionRadius: Double = 6.0 / document.zoomLevel  // Includes border for easier selection
        let handleSelectionRadius: Double = 4.0 / document.zoomLevel  // Scale with zoom

        // FIRST PASS: Check all anchor points (higher priority than handles)
        for (elementIndex, element) in shape.path.elements.enumerated() {
            let point: VectorPoint

            switch element {
            case .move(let to), .line(let to):
                point = to
            case .curve(let to, _, _):
                point = to
            case .quadCurve(let to, _):
                point = to
            case .close:
                continue
            }

            // Check if tap is near the anchor point with PRECISE radius
            let pointLocation = CGPoint(x: point.x, y: point.y).applying(shape.transform)
            if distance(location, pointLocation) <= pointSelectionRadius {
                let pointID = PointID(
                    shapeID: shape.id,
                    pathIndex: 0,
                    elementIndex: elementIndex
                )

                if isShiftPressed && selectedPoints.contains(pointID) {
                    // Shift+Click on selected point: deselect it and all coincident points
                    let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
                    let closedPathEndpoints = findClosedPathEndpoints(for: pointID)
                    selectedPoints.remove(pointID)
                    for coincidentPoint in coincidentPoints {
                        selectedPoints.remove(coincidentPoint)
                    }
                    for endpointID in closedPathEndpoints {
                        selectedPoints.remove(endpointID)
                    }
                    Log.fileOperation("🎯 Deselected anchor point", level: .info)
                } else {
                    // Select point with all coincident points for unified movement
                    selectPointWithCoincidents(pointID, addToSelection: isShiftPressed)
                    Log.fileOperation("🎯 Selected anchor point", level: .info)
                }
                return true
            }
        }

        // SECOND PASS: Check handles (lower priority than points)
        for (elementIndex, element) in shape.path.elements.enumerated() {
            switch element {
            case .curve(let to, _, let control2):
                // Check INCOMING handle (control2)
                let handle2Collapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
                if !handle2Collapsed {
                    let handle2Location = CGPoint(x: control2.x, y: control2.y).applying(shape.transform)
                    if distance(location, handle2Location) <= handleSelectionRadius {
                        let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex, handleType: .control2)
                        if isShiftPressed && selectedHandles.contains(handleID) {
                            selectedHandles.remove(handleID)
                            Log.fileOperation("🎯 Deselected INCOMING handle", level: .info)
                        } else {
                            if !isShiftPressed {
                                selectedHandles.removeAll()
                                selectedPoints.removeAll()
                            }
                            selectedHandles.insert(handleID)

                            // CRITICAL: Also select corresponding handles on coincident points
                            selectCoincidentHandles(for: handleID, shape: shape)

                            Log.fileOperation("🎯 Selected INCOMING handle", level: .info)
                        }
                        return true
                    }
                }

                // Check OUTGOING handle (control1 from NEXT element)
                if elementIndex + 1 < shape.path.elements.count {
                    if case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                        let outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                        if !outgoingHandleCollapsed {
                            let outgoingHandleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y).applying(shape.transform)
                            if distance(location, outgoingHandleLocation) <= handleSelectionRadius {
                                let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex + 1, handleType: .control1)
                                if isShiftPressed && selectedHandles.contains(handleID) {
                                    selectedHandles.remove(handleID)
                                    Log.fileOperation("🎯 Deselected OUTGOING handle", level: .info)
                                } else {
                                    if !isShiftPressed {
                                        selectedHandles.removeAll()
                                        selectedPoints.removeAll()
                                    }
                                    selectedHandles.insert(handleID)

                                    // CRITICAL: Also select corresponding handles on coincident points
                                    selectCoincidentHandles(for: handleID, shape: shape)

                                    Log.fileOperation("🎯 Selected OUTGOING handle", level: .info)
                                }
                                return true
                            }
                        }
                    }
                }

            case .quadCurve(let to, let control):
                // Check quad curve handle
                let quadHandleCollapsed = (abs(control.x - to.x) < 0.1 && abs(control.y - to.y) < 0.1)
                if !quadHandleCollapsed {
                    let handleLocation = CGPoint(x: control.x, y: control.y).applying(shape.transform)
                    if distance(location, handleLocation) <= handleSelectionRadius {
                        let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex, handleType: .control1)
                        if isShiftPressed && selectedHandles.contains(handleID) {
                            selectedHandles.remove(handleID)
                            Log.fileOperation("🎯 Deselected quad handle", level: .info)
                        } else {
                            if !isShiftPressed {
                                selectedHandles.removeAll()
                                selectedPoints.removeAll()
                            }
                            selectedHandles.insert(handleID)

                            // CRITICAL: Also select corresponding handles on coincident points
                            selectCoincidentHandles(for: handleID, shape: shape)

                            Log.fileOperation("🎯 Selected quad handle", level: .info)
                        }
                        return true
                    }
                }

            case .move(let to), .line(let to):
                // Check OUTGOING handle for move/line points
                if elementIndex + 1 < shape.path.elements.count {
                    if case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                        let outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                        if !outgoingHandleCollapsed {
                            let handleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y).applying(shape.transform)
                            if distance(location, handleLocation) <= handleSelectionRadius {
                                let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex + 1, handleType: .control1)
                                if isShiftPressed && selectedHandles.contains(handleID) {
                                    selectedHandles.remove(handleID)
                                    Log.fileOperation("🎯 Deselected OUTGOING handle from line/move", level: .info)
                                } else {
                                    if !isShiftPressed {
                                        selectedHandles.removeAll()
                                        selectedPoints.removeAll()
                                    }
                                    selectedHandles.insert(handleID)

                                    // CRITICAL: Also select corresponding handles on coincident points
                                    selectCoincidentHandles(for: handleID, shape: shape)

                                    Log.fileOperation("🎯 Selected OUTGOING handle from line/move", level: .info)
                                }
                                return true
                            }
                        }
                    }
                }

            case .close:
                continue
            }
        }

        // No third pass needed - all checks complete
        return false
    }
    
            /// STAGE 2: Direct-select whole shape (Professional: shows all anchor points)
    internal func directSelectWholeShape(at location: CGPoint) -> Bool {
        // Search for any shape at the click location
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            let shapes = document.getShapesForLayer(layerIndex)
            for shape in shapes.reversed() {
                if !shape.isVisible { continue }
                
                // PASTEBOARD BEHAVES EXACTLY LIKE CANVAS: Allow hit testing, handle via locked behavior
                
                var isHit = false
                
                // PROFESSIONAL HIT TESTING (same logic as regular selection)
                // CRITICAL FIX: Background shapes (Canvas/Pasteboard) need special handling
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    // Background shapes: Use EXACT bounds checking - no tolerance!
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(location)
                    Log.info("  - Background shape - exact bounds hit test: \(isHit)", category: .general)
                } else if shape.isGroupContainer {
                    // GROUP HIT TESTING FIX: Check if we hit any of the grouped shapes
                    Log.info("  - Group container: checking \(shape.groupedShapes.count) grouped shapes", category: .general)
                    for groupedShape in shape.groupedShapes {
                        if !groupedShape.isVisible { continue }
                        
                        // Apply the same hit testing logic to grouped shapes
                        let isStrokeOnly = groupedShape.fillStyle?.color == .clear || groupedShape.fillStyle == nil
                        
                        if isStrokeOnly && groupedShape.strokeStyle != nil {
                            // Stroke-only shapes: Use stroke-based hit testing
                            let strokeWidth = groupedShape.strokeStyle?.width ?? 1.0
                            let strokeTolerance = max(15.0, strokeWidth + 10.0)
                            if PathOperations.hitTest(groupedShape.transformedPath, point: location, tolerance: strokeTolerance) {
                                isHit = true
                                Log.info("    - Grouped shape '\(groupedShape.name)' stroke hit: \(isHit)", category: .general)
                                break
                            }
                        } else {
                            // Regular grouped shapes: Use path-based hit testing for object-precise selection
                            // ZOOM-AWARE PATH HIT TEST TOLERANCE: Scale tolerance based on zoom level
                            let basePathTolerance: Double = 8.0 // Base tolerance in screen pixels
                            let pathTolerance = max(2.0, basePathTolerance / document.zoomLevel) // Minimum 2px, scales with zoom
                            
                            if PathOperations.hitTest(groupedShape.transformedPath, point: location, tolerance: pathTolerance) {
                                isHit = true
                                Log.info("    - Grouped shape '\(groupedShape.name)' object-based path hit: \(isHit)", category: .general)
                                break
                            }
                        }
                    }
                } else {
                    // Regular shapes: Use path-based hit testing for object-precise selection
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                    
                    if isStrokeOnly && shape.strokeStyle != nil {
                        // Stroke-only shapes: Use stroke-based hit testing
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                        Log.info("  - Stroke hit test: \(isHit) (tolerance: \(strokeTolerance))", category: .general)
                    } else {
                        // Regular shapes: Use path-based hit testing for object-precise selection
                        // ZOOM-AWARE PATH HIT TEST TOLERANCE: Scale tolerance based on zoom level
                        let basePathTolerance: Double = 8.0 // Base tolerance in screen pixels
                        let pathTolerance = max(2.0, basePathTolerance / document.zoomLevel) // Minimum 2px, scales with zoom
                        
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: pathTolerance)
                        Log.info("  - Object-based path hit test: \(isHit)", category: .general)
                    }
                }
                
                if isHit {
                    // IMPROVED LOCKED BEHAVIOR: Instead of preventing interaction, deselect current selection
                    if layer.isLocked || shape.isLocked {
                        let lockType = layer.isLocked ? "locked layer" : "locked object"
                        Log.info("🚫 Direct-clicked on \(lockType) '\(shape.name)' - deselecting current selection", category: .general)
                        directSelectedShapeIDs.removeAll()
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        syncDirectSelectionWithDocument()
                        document.objectWillChange.send()
                        return true
                    }
                    
                    // PROFESSIONAL: Direct-select the whole shape
                    directSelectedShapeIDs.removeAll()
                    directSelectedShapeIDs.insert(shape.id)
                    selectedPoints.removeAll() // Clear individual selections
                    selectedHandles.removeAll()
                    syncDirectSelectionWithDocument()
                    
                    Log.info("✅ DIRECT-SELECTED SHAPE: \(shape.name)", category: .fileOperations)
                    Log.info("  Shape will now show ALL anchor points and handles (professional behavior)", category: .general)
                    return true
                }
            }
        }
        
        return false
    }
    
    // TEXT TOOL COMPLETELY REMOVED - Starting over with simple approach
    internal func handleDirectSelectionTap(at location: CGPoint) {
        Log.fileOperation("🎯 PROFESSIONAL DIRECT SELECTION tap at: \(location)", level: .info)
        
        // TEXT EDITING REMOVED
        
        // IMPROVED: Scale tolerance with zoom level for consistent screen-space tolerance
        // At 1x zoom: 15 canvas units = 15 screen pixels
        // At 2x zoom: 7.5 canvas units = 15 screen pixels
        // At 0.5x zoom: 30 canvas units = 15 screen pixels
        let screenTolerance: Double = 15.0
        let tolerance: Double = screenTolerance / document.zoomLevel
        var foundSelection = false
        
        // STAGE 1: Check if clicking on individual anchor points/handles (for already direct-selected shapes)
        if !directSelectedShapeIDs.isEmpty {
            Log.fileOperation("🔥 STAGE 1: Checking individual anchor points in direct-selected shapes...", level: .info)
            foundSelection = selectIndividualAnchorPointOrHandle(at: location, tolerance: tolerance)
        }
        
        // STAGE 2: If no anchor point selected, try to direct-select a whole shape (professional behavior)
        if !foundSelection {
            Log.fileOperation("🔥 STAGE 2: Looking for shapes to direct-select...", level: .info)
            foundSelection = directSelectWholeShape(at: location)
        }
        
        // STAGE 3: If nothing found, clear all selections (clicked empty space)
        if !foundSelection {
            Log.error("❌ Clicked empty space - clearing all direct selections", category: .error)
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            directSelectedShapeIDs.removeAll()
            syncDirectSelectionWithDocument()
        }
        
        Log.fileOperation("🎯 DIRECT SELECTION RESULT:", level: .info)
        Log.info("  Selected points: \(selectedPoints.count)", category: .general)
        Log.info("  Selected handles: \(selectedHandles.count)", category: .general)
        Log.info("  Direct selected shapes: \(directSelectedShapeIDs.count)", category: .general)
        
        // Force UI update to show selections
        document.objectWillChange.send()
    }

    // MARK: - Helper for Coincident Handle Selection

    /// When selecting a handle, also select ALL handles at coincident points to keep them visible
    private func selectCoincidentHandles(for handleID: HandleID, shape: VectorShape) {
        // Get the anchor point for this handle
        let anchorPoint: CGPoint?
        let pointIndex: Int

        if handleID.handleType == .control1 {
            // control1 belongs to the anchor at the END of the PREVIOUS element
            pointIndex = handleID.elementIndex - 1
            if pointIndex >= 0 && pointIndex < shape.path.elements.count {
                switch shape.path.elements[pointIndex] {
                case .move(let to), .line(let to):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                case .close:
                    anchorPoint = nil
                }
            } else {
                return
            }
        } else if handleID.handleType == .control2 {
            // control2 belongs to the anchor at the END of the CURRENT element
            pointIndex = handleID.elementIndex
            if pointIndex < shape.path.elements.count {
                switch shape.path.elements[pointIndex] {
                case .curve(let to, _, _):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                case .quadCurve(let to, _):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                default:
                    anchorPoint = nil
                }
            } else {
                return
            }
        } else {
            return
        }

        guard let anchor = anchorPoint else { return }

        // Find coincident points at this anchor position
        let tolerance = 1.0
        for (index, element) in shape.path.elements.enumerated() {
            // Skip the point we're already working with
            if index == pointIndex { continue }

            // Get the point position from this element
            let elementPoint: CGPoint?
            switch element {
            case .move(let to), .line(let to):
                elementPoint = CGPoint(x: to.x, y: to.y)
            case .curve(let to, _, _), .quadCurve(let to, _):
                elementPoint = CGPoint(x: to.x, y: to.y)
            case .close:
                elementPoint = nil
            }

            // Check if this point is coincident with our anchor
            if let point = elementPoint {
                let distance = sqrt(pow(anchor.x - point.x, 2) + pow(anchor.y - point.y, 2))
                if distance <= tolerance {
                    // This is a coincident point! Add BOTH its handles if they exist

                    // Add incoming handle if it exists
                    if case .curve(_, _, let control2) = element {
                        let handle2Collapsed = (abs(control2.x - point.x) < 0.1 && abs(control2.y - point.y) < 0.1)
                        if !handle2Collapsed {
                            let coincidentHandleID = HandleID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: index,
                                handleType: .control2
                            )
                            selectedHandles.insert(coincidentHandleID)
                            Log.info("🔗 AUTO-SELECTED coincident incoming handle at element \(index)", category: .general)
                        }
                    }

                    // Add outgoing handle if it exists
                    let nextIndex = index + 1
                    if nextIndex < shape.path.elements.count {
                        if case .curve(_, let control1, _) = shape.path.elements[nextIndex] {
                            let handle1Collapsed = (abs(control1.x - point.x) < 0.1 && abs(control1.y - point.y) < 0.1)
                            if !handle1Collapsed {
                                let coincidentHandleID = HandleID(
                                    shapeID: shape.id,
                                    pathIndex: 0,
                                    elementIndex: nextIndex,
                                    handleType: .control1
                                )
                                selectedHandles.insert(coincidentHandleID)
                                Log.info("🔗 AUTO-SELECTED coincident outgoing handle at element \(nextIndex)", category: .general)
                            }
                        }
                    }
                }
            }
        }
    }
}
