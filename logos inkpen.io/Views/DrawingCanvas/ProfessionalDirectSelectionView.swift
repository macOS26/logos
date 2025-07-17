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
    let directSelectedShapeIDs: Set<UUID>
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // PROFESSIONAL BEZIER DISPLAY: Show ALL anchor points and handles for direct-selected shapes
            // This matches Adobe Illustrator, Photoshop, and FreeHand professional standards
            ForEach(document.layers.indices, id: \.self) { layerIndex in
                let layer = document.layers[layerIndex]
                if layer.isVisible {
                    ForEach(layer.shapes.indices, id: \.self) { shapeIndex in
                        let shape = layer.shapes[shapeIndex]
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
            }
            
            // HIGHLIGHT INDIVIDUALLY SELECTED HANDLES - USE SAME COORDINATE SYSTEM AS ARROW TOOL
            ForEach(Array(selectedHandles), id: \.self) { handleID in
                if let handleInfo = getHandleInfo(handleID),
                   let shape = getShapeForHandle(handleID) {
                    // Draw HIGHLIGHTED line from point to handle - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                    Path { path in
                        path.move(to: handleInfo.pointLocation)
                        path.addLine(to: handleInfo.handleLocation)
                    }
                    .stroke(Color.orange, lineWidth: 2.0 / document.zoomLevel) // Scale-independent, orange for selected handles
                    .scaleEffect(document.zoomLevel, anchor: .topLeading)
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                    .transformEffect(shape.transform)
                    
                    // Draw HIGHLIGHTED handle as larger circle - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                    Circle()
                        .fill(Color.orange)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: 6 / document.zoomLevel, height: 6 / document.zoomLevel) // Scale-independent
                        .position(handleInfo.handleLocation)
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                        .transformEffect(shape.transform)
                }
            }
            
            // HIGHLIGHT INDIVIDUALLY SELECTED ANCHOR POINTS - USE SAME COORDINATE SYSTEM AS ARROW TOOL
            ForEach(Array(selectedPoints), id: \.self) { pointID in
                if let pointLocation = getPointLocation(pointID),
                   let shape = getShapeForPoint(pointID) {
                    Rectangle()
                        .fill(Color.orange)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: 8 / document.zoomLevel, height: 8 / document.zoomLevel) // Scale-independent
                        .position(pointLocation)
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                        .transformEffect(shape.transform)
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
    
    @ViewBuilder
    private func bezierCurveHandles(shape: VectorShape, elementIndex: Int, to: VectorPoint, control2: VectorPoint) -> some View {
        let anchorLocation = CGPoint(x: to.x, y: to.y)
        let control2Location = CGPoint(x: control2.x, y: control2.y)
        
        // INCOMING HANDLE
        bezierHandleLineAndCircle(from: anchorLocation, to: control2Location, shape: shape)
        
        // OUTGOING HANDLE
        if elementIndex + 1 < shape.path.elements.count {
            let nextElement = shape.path.elements[elementIndex + 1]
            if case .curve(_, let nextControl1, _) = nextElement {
                let control1Location = CGPoint(x: nextControl1.x, y: nextControl1.y)
                bezierHandleLineAndCircle(from: anchorLocation, to: control1Location, shape: shape)
            }
        }
    }
    
    @ViewBuilder
    private func bezierLineHandles(shape: VectorShape, elementIndex: Int, to: VectorPoint) -> some View {
        let anchorLocation = CGPoint(x: to.x, y: to.y)
        
        // OUTGOING HANDLE
        if elementIndex + 1 < shape.path.elements.count {
            let nextElement = shape.path.elements[elementIndex + 1]
            if case .curve(_, let nextControl1, _) = nextElement {
                let control1Location = CGPoint(x: nextControl1.x, y: nextControl1.y)
                bezierHandleLineAndCircle(from: anchorLocation, to: control1Location, shape: shape)
            }
        }
    }
    
    @ViewBuilder
    private func bezierHandleLineAndCircle(from: CGPoint, to: CGPoint, shape: VectorShape) -> some View {
        // HANDLE LINE
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel)
        .scaleEffect(document.zoomLevel, anchor: .topLeading)
        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        .transformEffect(shape.transform)
        
        // HANDLE CIRCLE
        Circle()
            .fill(Color.blue)
            .stroke(Color.white, lineWidth: 0.5)
            .frame(width: 4 / document.zoomLevel, height: 4 / document.zoomLevel)
            .position(to)
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            .transformEffect(shape.transform)
    }
    
    @ViewBuilder
    private func bezierAnchorPointView(shape: VectorShape, elementIndex: Int, element: PathElement) -> some View {
        if let point = extractPointFromElement(element) {
            let pointLocation = CGPoint(x: point.x, y: point.y)
            
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
                .frame(width: 6 / document.zoomLevel, height: 6 / document.zoomLevel)
                .position(pointLocation)
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                .transformEffect(shape.transform)
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
    
    // REMOVED: Duplicate function - use the precision version above
    
    private func getPointLocation(_ pointID: PointID) -> CGPoint? {
        // Find the shape and extract point location (including grouped shapes)
        for layer in document.layers {
            // First check top-level shapes
            if let shape = layer.shapes.first(where: { $0.id == pointID.shapeID }) {
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
            
            // Then check grouped shapes within group containers
            for containerShape in layer.shapes {
                if containerShape.isGroupContainer {
                    if let groupedShape = containerShape.groupedShapes.first(where: { $0.id == pointID.shapeID }) {
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
        
        for layer in document.layers {
            // First check top-level shapes
            if let shape = layer.shapes.first(where: { $0.id == handleID.shapeID }) {
                return getHandleInfoFromShape(shape, handleID: handleID)
            }
            
            // Then check grouped shapes within group containers
            for containerShape in layer.shapes {
                if containerShape.isGroupContainer {
                    if let groupedShape = containerShape.groupedShapes.first(where: { $0.id == handleID.shapeID }) {
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
        // Find the shape that contains this handle (including grouped shapes)
        for layer in document.layers {
            // First check top-level shapes
            if let shape = layer.shapes.first(where: { $0.id == handleID.shapeID }) {
                return shape
            }
            
            // Then check grouped shapes within group containers
            for containerShape in layer.shapes {
                if containerShape.isGroupContainer {
                    if let groupedShape = containerShape.groupedShapes.first(where: { $0.id == handleID.shapeID }) {
                        return groupedShape
                    }
                }
            }
        }
        return nil
    }
    
    private func getShapeForPoint(_ pointID: PointID) -> VectorShape? {
        // Find the shape that contains this point (including grouped shapes)
        for layer in document.layers {
            // First check top-level shapes
            if let shape = layer.shapes.first(where: { $0.id == pointID.shapeID }) {
                return shape
            }
            
            // Then check grouped shapes within group containers
            for containerShape in layer.shapes {
                if containerShape.isGroupContainer {
                    if let groupedShape = containerShape.groupedShapes.first(where: { $0.id == pointID.shapeID }) {
                        return groupedShape
                    }
                }
            }
        }
        return nil
    }
    
}
