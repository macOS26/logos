//
//  ProfessionalDirectSelectionView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/13/25.
//

import SwiftUI

struct ProfessionalDirectSelectionView: View {
    let document: VectorDocument
    let selectedPoints: Set<PointID>
    let selectedHandles: Set<HandleID>
    let visibleHandles: Set<HandleID>  // Handles that are visible but not selected
    let directSelectedShapeIDs: Set<UUID>
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // PROFESSIONAL BEZIER DISPLAY: Show ALL anchor points and handles for direct-selected shapes
            // This matches professional vector graphics software standards
            ForEach(Array(document.unifiedObjects), id: \.id) { unifiedObject in
                if case .shape(let shape) = unifiedObject.objectType {
                    if shape.isVisible && directSelectedShapeIDs.contains(shape.id) {
                        // GROUP DIRECT SELECTION FIX: Handle groups differently
                        if shape.isGroupContainer {
                            // For groups, show anchor points for all grouped shapes
                            ForEach(shape.groupedShapes.indices, id: \.self) { groupedShapeIndex in
                                let groupedShape = shape.groupedShapes[groupedShapeIndex]
                                if groupedShape.isVisible {
                                    professionalBezierDisplay(for: groupedShape)
                                }
                            }
                        } else {
                            // For individual shapes, show anchor points normally
                            professionalBezierDisplay(for: shape)
                        }
                    }
                }
            }
            
            // HIGHLIGHT INDIVIDUALLY SELECTED HANDLES - USE SAME COORDINATE SYSTEM AS ARROW TOOL
            // Only the selected handle is orange, companion handle stays blue
            ForEach(Array(selectedHandles), id: \.self) { handleID in
                if let handleInfo = getHandleInfo(handleID),
                   let shape = getShapeForHandle(handleID) {
                    // Draw the connecting line in blue (not highlighted) to show it's not interactive
                    Path { path in
                        path.move(to: handleInfo.pointLocation)
                        path.addLine(to: handleInfo.handleLocation)
                    }
                    .stroke(Color.blue.opacity(0.5), lineWidth: 1.0 / document.zoomLevel) // Blue with reduced opacity, not orange
                    // Apply transforms in correct order: shape transform (canvas space) → zoom → offset
                    .transformEffect(shape.transform)
                    .scaleEffect(document.zoomLevel, anchor: .topLeading)
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)

                    // Draw HIGHLIGHTED handle circle only (not the line) - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                    // Position the handle marker using transformed canvas coordinates to avoid scaling the marker itself
                    let transformedHandle = CGPoint(x: handleInfo.handleLocation.x, y: handleInfo.handleLocation.y).applying(shape.transform)
                    Circle()
                        .fill(Color.orange)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: 8, height: 8) // Fixed UI size - does not scale with artwork
                        .position(CGPoint(
                            x: transformedHandle.x * document.zoomLevel + document.canvasOffset.x,
                            y: transformedHandle.y * document.zoomLevel + document.canvasOffset.y
                        ))
                }
            }
            
            // HIGHLIGHT INDIVIDUALLY SELECTED ANCHOR POINTS - USE SAME COORDINATE SYSTEM AS ARROW TOOL
            ForEach(Array(selectedPoints), id: \.self) { pointID in
                if let pointLocation = getPointLocation(pointID),
                   let shape = getShapeForPoint(pointID) {
                    let transformedPoint = CGPoint(x: pointLocation.x, y: pointLocation.y).applying(shape.transform)
                    Rectangle()
                        .fill(Color.orange)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: 10, height: 10) // Fixed UI size - does not scale with artwork
                        .position(CGPoint(
                            x: transformedPoint.x * document.zoomLevel + document.canvasOffset.x,
                            y: transformedPoint.y * document.zoomLevel + document.canvasOffset.y
                        ))
                }
            }
        }
    }
    
    @ViewBuilder
    private func professionalBezierDisplay(for shape: VectorShape) -> some View {
        ZStack {
            // RENDER ALL HANDLES AND ANCHOR POINTS - USE SAME COORDINATE CHAIN AS ARROW TOOL
            ForEach(Array(shape.path.elements.enumerated()), id: \.offset) { elementIndex, element in
                bezierElementView(shape: shape, elementIndex: elementIndex, element: element)
            }
        }
    }
    
    @ViewBuilder
    private func bezierElementView(shape: VectorShape, elementIndex: Int, element: PathElement) -> some View {
        Group {
            // HANDLES FIRST
            bezierHandlesView(shape: shape, elementIndex: elementIndex, element: element)
            
            // ANCHOR POINTS ON TOP
            bezierAnchorPointView(shape: shape, elementIndex: elementIndex, element: element)
        }
    }
    
    @ViewBuilder
    private func bezierHandlesView(shape: VectorShape, elementIndex: Int, element: PathElement) -> some View {
        switch element {
        case .curve(let to, _, let control2):
            bezierCurveHandles(shape: shape, elementIndex: elementIndex, to: to, control2: control2)
        case .move(let to), .line(let to):
            bezierLineHandles(shape: shape, elementIndex: elementIndex, to: to)
        default:
            EmptyView()
        }
    }
    
    private func bezierCurveHandles(shape: VectorShape, elementIndex: Int, to: VectorPoint, control2: VectorPoint) -> some View {
        let pointID = PointID(
            shapeID: shape.id,
            pathIndex: 0,
            elementIndex: elementIndex
        )
        let isPointSelected = selectedPoints.contains(pointID)

        // Check if incoming handle is selected
        let incomingHandleID = HandleID(
            shapeID: shape.id,
            pathIndex: 0,
            elementIndex: elementIndex,
            handleType: .control2
        )
        let isIncomingHandleSelected = selectedHandles.contains(incomingHandleID)
        let isIncomingHandleVisible = selectedHandles.contains(incomingHandleID) || visibleHandles.contains(incomingHandleID)

        // Check if outgoing handle is selected (from next element)
        let outgoingHandleID: HandleID? = {
            if elementIndex + 1 < shape.path.elements.count {
                return HandleID(
                    shapeID: shape.id,
                    pathIndex: 0,
                    elementIndex: elementIndex + 1,
                    handleType: .control1
                )
            }
            return nil
        }()
        let isOutgoingHandleSelected = outgoingHandleID != nil ? selectedHandles.contains(outgoingHandleID!) : false
        let isOutgoingHandleVisible = outgoingHandleID != nil ? (selectedHandles.contains(outgoingHandleID!) || visibleHandles.contains(outgoingHandleID!)) : false

        // For smooth points: if one handle is selected or visible, show both handles AT THIS POINT ONLY
        // Incoming handle belongs to THIS point, outgoing handle also belongs to THIS point
        let shouldShowBothHandlesAtThisPoint = isIncomingHandleVisible || isOutgoingHandleVisible

        // COINCIDENT POINTS: If this point has coincident points, check if ANY of them are selected
        let coincidentPoints = findCoincidentPoints(to: pointID, in: document, tolerance: 1.0)
        let anyCoincidentPointSelected = !coincidentPoints.isEmpty && coincidentPoints.contains { selectedPoints.contains($0) }

        // CLOSED PATH: Check if any handle from coincident first/last points is selected
        let anyCoincidentHandleSelected: Bool = {
            // If this is a closed path and we're at first or last point
            if shape.path.elements.last == .close {
                let lastPointIndex = shape.path.elements.count - 2
                if elementIndex == 0 {
                    // We're at the first point, check if ANY handle from the last point is selected
                    // Check both incoming and outgoing handles of the last point
                    let lastPointIncomingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: lastPointIndex, handleType: .control2)
                    let lastPointOutgoingHandle: HandleID? = lastPointIndex + 1 < shape.path.elements.count ?
                        HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: lastPointIndex + 1, handleType: .control1) : nil

                    return selectedHandles.contains(lastPointIncomingHandle) || visibleHandles.contains(lastPointIncomingHandle) ||
                           (lastPointOutgoingHandle != nil && (selectedHandles.contains(lastPointOutgoingHandle!) || visibleHandles.contains(lastPointOutgoingHandle!)))
                } else if elementIndex == lastPointIndex {
                    // We're at the last point, check if ANY handle from the first point is selected
                    // Check both the outgoing handle of first point and incoming handle if it exists
                    let firstPointOutgoingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: 1, handleType: .control1)
                    // For the incoming handle of the first point, we need to check if first element is a curve
                    var firstPointHasIncomingHandle = false
                    if case .curve = shape.path.elements[0] {
                        let firstPointIncomingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: 0, handleType: .control2)
                        firstPointHasIncomingHandle = selectedHandles.contains(firstPointIncomingHandle) || visibleHandles.contains(firstPointIncomingHandle)
                    }

                    return selectedHandles.contains(firstPointOutgoingHandle) || visibleHandles.contains(firstPointOutgoingHandle) || firstPointHasIncomingHandle
                }
            }
            return false
        }()

        // Show handles if:
        // - The point itself is selected
        // - Any coincident point is selected
        // - Either of THIS point's handles are selected (show both for smooth editing)
        // - Any handle at the coincident point is selected (for closed paths)
        // NOTE: We do NOT show handles just because the previous point's outgoing handle is selected
        let shouldShowHandles = isPointSelected || anyCoincidentPointSelected || shouldShowBothHandlesAtThisPoint || anyCoincidentHandleSelected

        return Group {
            if shouldShowHandles {
            let anchorLocation = CGPoint(x: to.x, y: to.y)
            let control2Location = CGPoint(x: control2.x, y: control2.y)

            // INCOMING HANDLE - only render if NOT collapsed to anchor point
            let incomingHandleCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
            if !incomingHandleCollapsed {
                bezierHandleLineAndCircle(from: anchorLocation, to: control2Location, shape: shape, isSelected: isIncomingHandleSelected)
            }

            // OUTGOING HANDLE - only render if NOT collapsed to anchor point
            if elementIndex + 1 < shape.path.elements.count {
                let nextElement = shape.path.elements[elementIndex + 1]
                if case .curve(_, let nextControl1, _) = nextElement {
                    let control1Location = CGPoint(x: nextControl1.x, y: nextControl1.y)
                    let outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                    if !outgoingHandleCollapsed {
                        bezierHandleLineAndCircle(from: anchorLocation, to: control1Location, shape: shape, isSelected: isOutgoingHandleSelected)
                    }
                }
            }
        }
        }
    }

    private func bezierLineHandles(shape: VectorShape, elementIndex: Int, to: VectorPoint) -> some View {
        let pointID = PointID(
            shapeID: shape.id,
            pathIndex: 0,
            elementIndex: elementIndex
        )
        let isPointSelected = selectedPoints.contains(pointID)

        // COINCIDENT POINTS: If this point has coincident points, check if ANY of them are selected
        let coincidentPoints = findCoincidentPoints(to: pointID, in: document, tolerance: 1.0)
        let anyCoincidentPointSelected = !coincidentPoints.isEmpty && coincidentPoints.contains { selectedPoints.contains($0) }

        // Check if outgoing handle is selected or visible (from next element)
        let outgoingHandleID: HandleID? = {
            if elementIndex + 1 < shape.path.elements.count {
                let nextElement = shape.path.elements[elementIndex + 1]
                if case .curve = nextElement {
                    return HandleID(
                        shapeID: shape.id,
                        pathIndex: 0,
                        elementIndex: elementIndex + 1,
                        handleType: .control1
                    )
                }
            }
            return nil
        }()

        let isOutgoingHandleSelected = outgoingHandleID != nil && selectedHandles.contains(outgoingHandleID!)
        let isOutgoingHandleVisible = outgoingHandleID != nil && (selectedHandles.contains(outgoingHandleID!) || visibleHandles.contains(outgoingHandleID!))

        // For line/move points, we only care about the outgoing handle
        // We should NOT show handles just because the next point's incoming handle is selected

        // CLOSED PATH: For coincident points, check handles from both first and last points
        let anyCoincidentHandleSelected: Bool = {
            if shape.path.elements.last == .close {
                let lastPointIndex = shape.path.elements.count - 2
                if elementIndex == 0 {
                    // We're at the first point (move/line), check ALL handles from the last point
                    // Check incoming handle of last point
                    if case .curve = shape.path.elements[lastPointIndex] {
                        let lastPointIncomingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: lastPointIndex, handleType: .control2)
                        if selectedHandles.contains(lastPointIncomingHandle) || visibleHandles.contains(lastPointIncomingHandle) {
                            return true
                        }
                    }
                    // Check outgoing handle from last point (if next element after last is curve)
                    if lastPointIndex + 1 < shape.path.elements.count {
                        if case .curve = shape.path.elements[lastPointIndex + 1] {
                            let lastPointOutgoingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: lastPointIndex + 1, handleType: .control1)
                            if selectedHandles.contains(lastPointOutgoingHandle) || visibleHandles.contains(lastPointOutgoingHandle) {
                                return true
                            }
                        }
                    }
                } else if elementIndex == lastPointIndex {
                    // We're at the last point, check ALL handles from the first point
                    // Check if first point has incoming handle
                    if case .curve = shape.path.elements[0] {
                        let firstPointIncomingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: 0, handleType: .control2)
                        if selectedHandles.contains(firstPointIncomingHandle) || visibleHandles.contains(firstPointIncomingHandle) {
                            return true
                        }
                    }
                    // Check outgoing handle from first point
                    if shape.path.elements.count > 1 {
                        if case .curve = shape.path.elements[1] {
                            let firstPointOutgoingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: 1, handleType: .control1)
                            if selectedHandles.contains(firstPointOutgoingHandle) || visibleHandles.contains(firstPointOutgoingHandle) {
                                return true
                            }
                        }
                    }
                }
            }
            return false
        }()

        // Show handles if:
        // - The point itself is selected
        // - Any coincident point is selected
        // - This point's outgoing handle is selected or visible
        // - Any handle at the coincident point is selected (for closed paths)
        let shouldShowHandles = isPointSelected || anyCoincidentPointSelected || isOutgoingHandleVisible || anyCoincidentHandleSelected

        return Group {
            if shouldShowHandles {
            let anchorLocation = CGPoint(x: to.x, y: to.y)

            // OUTGOING HANDLE - only render if NOT collapsed to anchor point
            if elementIndex + 1 < shape.path.elements.count {
                let nextElement = shape.path.elements[elementIndex + 1]
                if case .curve(_, let nextControl1, _) = nextElement {
                    let control1Location = CGPoint(x: nextControl1.x, y: nextControl1.y)
                    let outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                    if !outgoingHandleCollapsed {
                        bezierHandleLineAndCircle(from: anchorLocation, to: control1Location, shape: shape, isSelected: isOutgoingHandleSelected)
                    }
                }
            }
        }
        }
    }

    @ViewBuilder
    private func bezierHandleLineAndCircle(from: CGPoint, to: CGPoint, shape: VectorShape, isSelected: Bool = false) -> some View {
        // HANDLE LINE
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel)
        // Apply transforms in correct order: shape transform (canvas space) → zoom → offset
        .transformEffect(shape.transform)
        .scaleEffect(document.zoomLevel, anchor: .topLeading)
        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        
        // HANDLE CIRCLE: use transformed position so the marker remains device-size and correctly aligned
        // Orange if this specific handle is selected, blue otherwise
        let transformedTo = CGPoint(x: to.x, y: to.y).applying(shape.transform)
        Circle()
            .fill(isSelected ? Color.orange : Color.blue)
            .stroke(Color.white, lineWidth: 0.5)
            .frame(width: 6, height: 6)
            .position(CGPoint(
                x: transformedTo.x * document.zoomLevel + document.canvasOffset.x,
                y: transformedTo.y * document.zoomLevel + document.canvasOffset.y
            ))
    }
    
    @ViewBuilder
    private func bezierAnchorPointView(shape: VectorShape, elementIndex: Int, element: PathElement) -> some View {
        if let point = extractPointFromElement(element) {
            let rawPointLocation = CGPoint(x: point.x, y: point.y)
            let transformedPointLocation = rawPointLocation.applying(shape.transform)
            
            let pointID = PointID(
                shapeID: shape.id,
                pathIndex: 0,
                elementIndex: elementIndex
            )
            let isPointSelected = selectedPoints.contains(pointID)
            
            // Check if this point has coincident points for visual indication
            let hasCoincidentPoints = !findCoincidentPoints(to: pointID, in: document, tolerance: 1.0).isEmpty
            
            Rectangle()
                .fill(isPointSelected ? Color.blue : Color.white)
                .stroke(hasCoincidentPoints ? Color.orange : Color.blue, lineWidth: hasCoincidentPoints ? 2.0 : 1.0)
                .frame(width: 8, height: 8)
                .position(CGPoint(
                    x: transformedPointLocation.x * document.zoomLevel + document.canvasOffset.x,
                    y: transformedPointLocation.y * document.zoomLevel + document.canvasOffset.y
                ))
        }
    }
    
    private func extractPointFromElement(_ element: PathElement) -> VectorPoint? {
        switch element {
        case .move(let to), .line(let to):
            return to
        case .curve(let to, _, _), .quadCurve(let to, _):
            return to
        case .close:
            return nil
        }
    }

    // Helper function to get the anchor point index for a handle
    private func getAnchorPointForHandle(_ handleID: HandleID) -> Int? {
        // For control1 (outgoing handle), the anchor point is the previous element
        // For control2 (incoming handle), the anchor point is the same element
        if handleID.handleType == .control1 && handleID.elementIndex > 0 {
            return handleID.elementIndex - 1
        } else if handleID.handleType == .control2 {
            return handleID.elementIndex
        }
        return nil
    }
    
    // REMOVED: Duplicate function - use the precision version above
    
    private func getPointLocation(_ pointID: PointID) -> CGPoint? {
        // Find the shape and extract point location using unified objects
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                // First check if this is the shape we're looking for
                if shape.id == pointID.shapeID {
                    if pointID.elementIndex < shape.path.elements.count {
                        let element = shape.path.elements[pointID.elementIndex]
                        
                        switch element {
                        case .move(let to), .line(let to):
                            return CGPoint(x: to.x, y: to.y)
                        case .curve(let to, _, _):
                            return CGPoint(x: to.x, y: to.y)
                        case .quadCurve(let to, _):
                            return CGPoint(x: to.x, y: to.y)
                        case .close:
                            return nil
                        }
                    }
                }
                
                // Then check grouped shapes within this shape if it's a group container
                if shape.isGroupContainer {
                    if let groupedShape = shape.groupedShapes.first(where: { $0.id == pointID.shapeID }) {
                        if pointID.elementIndex < groupedShape.path.elements.count {
                            let element = groupedShape.path.elements[pointID.elementIndex]
                            
                            switch element {
                            case .move(let to), .line(let to):
                                return CGPoint(x: to.x, y: to.y)
                            case .curve(let to, _, _):
                                return CGPoint(x: to.x, y: to.y)
                            case .quadCurve(let to, _):
                                return CGPoint(x: to.x, y: to.y)
                            case .close:
                                return nil
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func getHandleInfo(_ handleID: HandleID) -> (pointLocation: CGPoint, handleLocation: CGPoint)? {
        // CRITICAL FIX: Match the selection logic exactly!
        // HandleIDs now point to where the handle data actually lives in the bezier structure
        
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                // First check if this is the shape we're looking for
                if shape.id == handleID.shapeID {
                    return getHandleInfoFromShape(shape, handleID: handleID)
                }
                
                // Then check grouped shapes within this shape if it's a group container
                if shape.isGroupContainer {
                    if let groupedShape = shape.groupedShapes.first(where: { $0.id == handleID.shapeID }) {
                        return getHandleInfoFromShape(groupedShape, handleID: handleID)
                    }
                }
            }
        }
        return nil
    }
    
    private func getHandleInfoFromShape(_ shape: VectorShape, handleID: HandleID) -> (pointLocation: CGPoint, handleLocation: CGPoint)? {
        if handleID.elementIndex < shape.path.elements.count {
            let element = shape.path.elements[handleID.elementIndex]
            
            switch element {
            case .curve(let to, let control1, let control2):
                if handleID.handleType == .control1 {
                    // OUTGOING HANDLE: control1 of current element belongs to PREVIOUS anchor point
                    if handleID.elementIndex > 0 {
                        let prevElement = shape.path.elements[handleID.elementIndex - 1]
                        switch prevElement {
                        case .move(let prevTo), .line(let prevTo):
                            let pointLocation = CGPoint(x: prevTo.x, y: prevTo.y)
                            let handleLocation = CGPoint(x: control1.x, y: control1.y)
                            return (pointLocation, handleLocation)
                        case .curve(let prevTo, _, _):
                            let pointLocation = CGPoint(x: prevTo.x, y: prevTo.y)
                            let handleLocation = CGPoint(x: control1.x, y: control1.y)
                            return (pointLocation, handleLocation)
                        default:
                            return nil
                        }
                    }
                } else {
                    // INCOMING HANDLE: control2 of current element belongs to current anchor point
                    let pointLocation = CGPoint(x: to.x, y: to.y)
                    let handleLocation = CGPoint(x: control2.x, y: control2.y)
                    return (pointLocation, handleLocation)
                }
            case .quadCurve(let to, let control):
                if handleID.handleType == .control1 {
                    // For quad curves, control1 could be outgoing from previous point
                    if handleID.elementIndex > 0 {
                        let prevElement = shape.path.elements[handleID.elementIndex - 1]
                        switch prevElement {
                        case .move(let prevTo), .line(let prevTo), .curve(let prevTo, _, _):
                            let pointLocation = CGPoint(x: prevTo.x, y: prevTo.y)
                            let handleLocation = CGPoint(x: control.x, y: control.y)
                            return (pointLocation, handleLocation)
                        default:
                            return nil
                        }
                    }
                } else {
                    // Standard quad curve control handle
                    let pointLocation = CGPoint(x: to.x, y: to.y)
                    let handleLocation = CGPoint(x: control.x, y: control.y)
                    return (pointLocation, handleLocation)
                }
            default:
                return nil
            }
        }
        return nil
    }
    

    private func getShapeForHandle(_ handleID: HandleID) -> VectorShape? {
        // Find the shape that contains this handle using unified objects
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                // First check if this is the shape we're looking for
                if shape.id == handleID.shapeID {
                    return shape
                }
                
                // Then check grouped shapes within this shape if it's a group container
                if shape.isGroupContainer {
                    if let groupedShape = shape.groupedShapes.first(where: { $0.id == handleID.shapeID }) {
                        return groupedShape
                    }
                }
            }
        }
        return nil
    }
    
    private func getShapeForPoint(_ pointID: PointID) -> VectorShape? {
        // Find the shape that contains this point using unified objects
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                // First check if this is the shape we're looking for
                if shape.id == pointID.shapeID {
                    return shape
                }
                
                // Then check grouped shapes within this shape if it's a group container
                if shape.isGroupContainer {
                    if let groupedShape = shape.groupedShapes.first(where: { $0.id == pointID.shapeID }) {
                        return groupedShape
                    }
                }
            }
        }
        return nil
    }    
}
