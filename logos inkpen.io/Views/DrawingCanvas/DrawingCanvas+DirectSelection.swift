//
//  DrawingCanvas+DirectSelection.swift
//  logos inkpen.io
//
//  Direct selection functionality
//

import SwiftUI

extension DrawingCanvas {
    // MARK: - PROFESSIONAL ANCHOR POINT AND HANDLE SELECTION
    
    /// STAGE 1: Select individual anchor points or handles (when shape already direct-selected)
    internal func selectIndividualAnchorPointOrHandle(at location: CGPoint, tolerance: Double) -> Bool {
        // Search through all direct-selected shapes for individual anchor points and handles
        for shapeID in directSelectedShapeIDs {
            // Find the shape in the document
            for layerIndex in document.layers.indices {
                let layer = document.layers[layerIndex]
                if let shape = layer.shapes.first(where: { $0.id == shapeID }) {
                    
                    // IMPROVED LOCKED BEHAVIOR: Instead of preventing interaction, deselect current selection
                    if layer.isLocked || shape.isLocked {
                        let lockType = layer.isLocked ? "locked layer" : "locked object"
                        print("🚫 Clicked on points/handles of \(lockType) '\(shape.name)' - deselecting current selection")
                        directSelectedShapeIDs.removeAll()
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        document.objectWillChange.send()
                        return true
                    }
                    
                    // GROUP ANCHOR POINT SELECTION FIX: Handle groups differently
                    if shape.isGroupContainer {
                        // For groups, check anchor points in all grouped shapes
                        print("🔍 Checking anchor points in group '\(shape.name)' with \(shape.groupedShapes.count) shapes")
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
        // Check each path element for points and handles
                    for (elementIndex, element) in shape.path.elements.enumerated() {
                        let point: VectorPoint
                        
                        switch element {
                        case .move(let to), .line(let to):
                            point = to
                            
                            // Check for OUTGOING HANDLE (control1 from NEXT element - if it exists)
                            if elementIndex + 1 < shape.path.elements.count {
                                let nextElement = shape.path.elements[elementIndex + 1]
                                if case .curve(_, let nextControl1, _) = nextElement {
                                    let outgoingHandleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y)
                                    if distance(location, outgoingHandleLocation) <= tolerance {
                                        // CRITICAL FIX: HandleID must point to the NEXT element where the handle actually lives
                                        let handleID = HandleID(
                                            shapeID: shape.id,
                                            pathIndex: 0,
                                            elementIndex: elementIndex + 1, // NEXT element, not current!
                                            handleType: .control1
                                        )
                                        
                                        if isShiftPressed && selectedHandles.contains(handleID) {
                                            selectedHandles.remove(handleID)
                                            print("🎯 Deselected OUTGOING handle from line/move point")
                                        } else {
                                            if !isShiftPressed {
                                                selectedHandles.removeAll()
                                                selectedPoints.removeAll()
                                            }
                                            selectedHandles.insert(handleID)
                                            print("🎯 Selected OUTGOING handle from line/move point")
                                        }
                                        return true
                                    }
                                }
                            }
                            
                        case .curve(let to, _, let control2):
                            point = to
                            
                            // FIRST: Check control handles (higher priority than anchor points)
                            // For curves, we need to match the DISPLAY logic exactly:
                            // - control2 is the INCOMING handle to this anchor point
                            // - control1 from NEXT element is the OUTGOING handle from this anchor point
                            
                            // INCOMING HANDLE (control2 of current element)
                            let handle2Location = CGPoint(x: control2.x, y: control2.y)
                            let handle2Distance = distance(location, handle2Location)
                            print("🎯 Testing INCOMING handle at (\(String(format: "%.1f", handle2Location.x)), \(String(format: "%.1f", handle2Location.y))), distance: \(String(format: "%.1f", handle2Distance)), tolerance: \(String(format: "%.1f", tolerance))")
                            if handle2Distance <= tolerance {
                                let handleID = HandleID(
                                    shapeID: shape.id,
                                    pathIndex: 0,
                                    elementIndex: elementIndex,
                                    handleType: .control2
                                )
                                
                                if isShiftPressed && selectedHandles.contains(handleID) {
                                    selectedHandles.remove(handleID)
                                    print("🎯 Deselected INCOMING handle")
                                } else {
                                    if !isShiftPressed {
                                        selectedHandles.removeAll()
                                        selectedPoints.removeAll()
                                    }
                                    selectedHandles.insert(handleID)
                                    print("🎯 Selected INCOMING handle")
                                }
                                return true
                            }
                            
                            // OUTGOING HANDLE (control1 from NEXT element - if it exists)
                            if elementIndex + 1 < shape.path.elements.count {
                                let nextElement = shape.path.elements[elementIndex + 1]
                                if case .curve(_, let nextControl1, _) = nextElement {
                                    let outgoingHandleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y)
                                    let outgoingDistance = distance(location, outgoingHandleLocation)
                                    print("🎯 Testing OUTGOING handle at (\(String(format: "%.1f", outgoingHandleLocation.x)), \(String(format: "%.1f", outgoingHandleLocation.y))), distance: \(String(format: "%.1f", outgoingDistance)), tolerance: \(String(format: "%.1f", tolerance))")
                                    if outgoingDistance <= tolerance {
                                        // CRITICAL FIX: HandleID must point to the NEXT element where the handle actually lives
                                        let handleID = HandleID(
                                            shapeID: shape.id,
                                            pathIndex: 0,
                                            elementIndex: elementIndex + 1, // NEXT element, not current!
                                            handleType: .control1
                                        )
                                        
                                        if isShiftPressed && selectedHandles.contains(handleID) {
                                            selectedHandles.remove(handleID)
                                            print("🎯 Deselected OUTGOING handle")
                                        } else {
                                            if !isShiftPressed {
                                                selectedHandles.removeAll()
                                                selectedPoints.removeAll()
                                            }
                                            selectedHandles.insert(handleID)
                                            print("🎯 Selected OUTGOING handle")
                                        }
                                        return true
                                    }
                                }
                            }
                            
                        case .quadCurve(let to, let control):
                            point = to
                            
                            // Check control handle for quad curve
                            let handleLocation = CGPoint(x: control.x, y: control.y)
                            if distance(location, handleLocation) <= tolerance {
                                let handleID = HandleID(
                                    shapeID: shape.id,
                                    pathIndex: 0,
                                    elementIndex: elementIndex,
                                    handleType: .control1
                                )
                                
                                if isShiftPressed && selectedHandles.contains(handleID) {
                                    selectedHandles.remove(handleID)
                                    print("🎯 Deselected quad handle")
                                } else {
                                    if !isShiftPressed {
                                        selectedHandles.removeAll()
                                        selectedPoints.removeAll()
                                    }
                                    selectedHandles.insert(handleID)
                                    print("🎯 Selected quad handle")
                                }
                                return true
                            }
                            
                        case .close:
                            continue
                        }
                        
                        // SECOND: Check if tap is near the main anchor point
                        let pointLocation = CGPoint(x: point.x, y: point.y)
                        if distance(location, pointLocation) <= tolerance {
                            let pointID = PointID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: elementIndex
                            )
                            
                            if isShiftPressed && selectedPoints.contains(pointID) {
                                // Shift+Click on selected point: deselect it and all coincident points
                                let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
                                selectedPoints.remove(pointID)
                                for coincidentPoint in coincidentPoints {
                                    selectedPoints.remove(coincidentPoint)
                                }
                                print("🎯 Deselected anchor point and \(coincidentPoints.count) coincident points")
                            } else {
                                // Select point with all coincident points for unified movement
                                selectPointWithCoincidents(pointID, addToSelection: isShiftPressed)
                                print("🎯 Selected anchor point with coincident points")
                            }
                            return true
                        }
                    }
        return false
    }
    
    /// STAGE 2: Direct-select whole shape (Adobe Illustrator: shows all anchor points)
    internal func directSelectWholeShape(at location: CGPoint) -> Bool {
        // Search for any shape at the click location
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
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
                    print("  - Background shape - exact bounds hit test: \(isHit)")
                } else if shape.isGroupContainer {
                    // GROUP HIT TESTING FIX: Check if we hit any of the grouped shapes
                    print("  - Group container: checking \(shape.groupedShapes.count) grouped shapes")
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
                                print("    - Grouped shape '\(groupedShape.name)' stroke hit: \(isHit)")
                                break
                            }
                        } else {
                            // Regular grouped shapes: Use bounds + path hit testing
                            let transformedBounds = groupedShape.bounds.applying(groupedShape.transform)
                            let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                            
                            if expandedBounds.contains(location) {
                                isHit = true
                                print("    - Grouped shape '\(groupedShape.name)' bounds hit: \(isHit)")
                                break
                            } else if PathOperations.hitTest(groupedShape.transformedPath, point: location, tolerance: 8.0) {
                                isHit = true
                                print("    - Grouped shape '\(groupedShape.name)' path hit: \(isHit)")
                                break
                            }
                        }
                    }
                } else {
                    // Regular shapes: Use different logic for stroke vs filled
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                    
                    if isStrokeOnly && shape.strokeStyle != nil {
                        // Stroke-only shapes: Use stroke-based hit testing
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                        print("  - Stroke hit test: \(isHit) (tolerance: \(strokeTolerance))")
                    } else {
                        // Regular shapes: Use bounds + path hit testing
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                        
                        if expandedBounds.contains(location) {
                            isHit = true
                            print("  - Bounds hit test: \(isHit)")
                        } else {
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                            print("  - Path hit test: \(isHit)")
                        }
                    }
                }
                
                if isHit {
                    // IMPROVED LOCKED BEHAVIOR: Instead of preventing interaction, deselect current selection
                    if layer.isLocked || shape.isLocked {
                        let lockType = layer.isLocked ? "locked layer" : "locked object"
                        print("🚫 Direct-clicked on \(lockType) '\(shape.name)' - deselecting current selection")
                        directSelectedShapeIDs.removeAll()
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        document.objectWillChange.send()
                        return true
                    }
                    
                    // PROFESSIONAL: Direct-select the whole shape
                    directSelectedShapeIDs.removeAll()
                    directSelectedShapeIDs.insert(shape.id)
                    selectedPoints.removeAll() // Clear individual selections
                    selectedHandles.removeAll()
                    
                    print("✅ DIRECT-SELECTED SHAPE: \(shape.name)")
                    print("  Shape will now show ALL anchor points and handles (Adobe Illustrator behavior)")
                    return true
                }
            }
        }
        
        return false
    }
    
    // TEXT TOOL COMPLETELY REMOVED - Starting over with simple approach
    internal func handleDirectSelectionTap(at location: CGPoint) {
        print("🎯 PROFESSIONAL DIRECT SELECTION tap at: \(location)")
        
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
            print("🔥 STAGE 1: Checking individual anchor points in direct-selected shapes...")
            foundSelection = selectIndividualAnchorPointOrHandle(at: location, tolerance: tolerance)
        }
        
        // STAGE 2: If no anchor point selected, try to direct-select a whole shape (Adobe Illustrator behavior)
        if !foundSelection {
            print("🔥 STAGE 2: Looking for shapes to direct-select...")
            foundSelection = directSelectWholeShape(at: location)
        }
        
        // STAGE 3: If nothing found, clear all selections (clicked empty space)
        if !foundSelection {
            print("❌ Clicked empty space - clearing all direct selections")
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            directSelectedShapeIDs.removeAll()
        }
        
        print("🎯 DIRECT SELECTION RESULT:")
        print("  Selected points: \(selectedPoints.count)")
        print("  Selected handles: \(selectedHandles.count)")
        print("  Direct selected shapes: \(directSelectedShapeIDs.count)")
        
        // Force UI update to show selections
        document.objectWillChange.send()
    }
} 