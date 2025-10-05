//
//  BezierToolHelpers.swift
//  logos inkpen.io
//
//  Helper functions for Bezier tool functionality
//

import SwiftUI
import Combine

extension DrawingCanvas {
    // MARK: - Grid Snapping
    
    /// Snap a point to the grid if snap to grid is enabled
    internal func snapToGrid(_ point: CGPoint) -> CGPoint {
        guard document.snapToGrid else { return point }
        
        // Get the grid spacing based on document settings
        // Apply the same spacing multiplier as used in GridView
        let baseSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit
        let spacingMultiplier: CGFloat = {
            switch document.settings.unit {
            case .pixels, .points:
                return 25.0
            case .millimeters:
                return 10.0
            case .picas:
                return 4.0
            default:
                return 1.0
            }
        }()
        let gridSpacing = baseSpacing * spacingMultiplier
        
        // Prevent division by zero
        guard gridSpacing > 0 else { return point }
        
        // Snap to nearest grid intersection
        let snappedX = round(point.x / gridSpacing) * gridSpacing
        let snappedY = round(point.y / gridSpacing) * gridSpacing
        
        return CGPoint(x: snappedX, y: snappedY)
    }
    
    /// Ensure incomplete paths have proper fill and stroke colors
    internal func ensureIncompletePathHasProperColors(shape: VectorShape) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        
        // Find the shape in the document and ensure it has proper colors
        let shapes = document.getShapesForLayer(layerIndex)
        for shapeIndex in shapes.indices {
            if let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
               currentShape.id == shape.id {
                // Ensure stroke has proper colors and is visible
                document.createStrokeStyleInUnified(
                    id: shape.id,
                    color: document.defaultStrokeColor,
                    width: document.defaultStrokeWidth,
                    placement: document.defaultStrokePlacement,
                    lineCap: document.defaultStrokeLineCap,
                    lineJoin: document.defaultStrokeLineJoin,
                    miterLimit: document.defaultStrokeMiterLimit,
                    opacity: document.defaultStrokeOpacity
                )
                
                // Ensure fill has proper colors and is visible
                document.createFillStyleInUnified(
                    id: shape.id,
                    color: document.defaultFillColor,
                    opacity: document.defaultFillOpacity
                )
                
                var updatedShape = currentShape
                updatedShape.updateBounds()
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                break
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    // MARK: - Bezier Path Handling
    
    internal func handleBezierPenTap(at location: CGPoint) {
        var constrainedLocation = location
        
        // Apply angle constraint if Shift is pressed and we're adding to existing path
        if isShiftPressed && isBezierDrawing && !bezierPoints.isEmpty {
            guard let lastPoint = bezierPoints.last else { return }
            let referencePoint = CGPoint(x: lastPoint.x, y: lastPoint.y)
            constrainedLocation = constrainToAngle(from: referencePoint, to: location)
        }
        
        // Apply snap to point or grid if enabled
        constrainedLocation = applySnapping(to: constrainedLocation)
        
        // Check if we're trying to close the CURRENT path by clicking near its first point
        if isBezierDrawing && bezierPoints.count >= 3 && showClosePathHint {
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            
            // ZOOM-AWARE CLOSE TOLERANCE
            let baseCloseTolerance: Double = 5.0
            let zoomLevel = document.zoomLevel
            let closeTolerance = max(2.0, baseCloseTolerance / zoomLevel)
            
            if distance(constrainedLocation, firstPointLocation) <= closeTolerance {
                closeBezierPath()
                return
            }
        }
        
        if !isBezierDrawing {
            // CHECK FOR CONTINUING EXISTING PATH
            if let selectedPointID = selectedPoints.first {
                if getShapeForPoint(selectedPointID) != nil,
                   let pointPosition = getPointPosition(selectedPointID) {
                    continueExistingPath(from: pointPosition)
                    return
                }
            }
            
            // CREATE FIRST POINT IMMEDIATELY
            if activeBezierShape == nil {
                createNewBezierPath(at: constrainedLocation)
            }
            return
        } else {
            // PURE CLICK: Add corner point (no handles)
            addCornerPoint(at: constrainedLocation)
        }
    }
    
    internal func handleBezierPenDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        var startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        var currentLocation = screenToCanvas(value.location, geometry: geometry)
        
        // Apply snap to point or grid to start location if enabled
        startLocation = applySnapping(to: startLocation)
        
        // Apply angle constraint if Shift is pressed
        if isShiftPressed && isBezierDrawing && !bezierPoints.isEmpty {
            currentLocation = applyAngleConstraintForDrag(currentLocation: currentLocation, startLocation: startLocation)
        }
        
        // Apply snap to point or grid if enabled
        currentLocation = applySnapping(to: currentLocation)
        
        // Calculate actual drag distance
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        
        // ZOOM-AWARE DRAG THRESHOLD
        let baseThreshold: Double = 8.0
        let zoomLevel = document.zoomLevel
        let zoomAwareThreshold = max(2.0, baseThreshold / zoomLevel)
        
        // Handle first point creation if no bezier path is active
        if !isBezierDrawing && activeBezierShape == nil {
            handleFirstPointCreationFromDrag(startLocation: startLocation)
        }
        
        // Regular bezier pen drag handling
        guard isBezierDrawing else { return }
        
        // Only proceed with handle creation if user has dragged significantly
        if dragDistance < zoomAwareThreshold {
            return
        }
        
        // Check if we're dragging from an existing anchor point
        let basePointTolerance: Double = 8.0
        let tolerance = max(2.0, basePointTolerance / zoomLevel)
        
        var draggedPointIndex: Int? = nil
        for (index, point) in bezierPoints.enumerated() {
            let pointLocation = CGPoint(x: point.x, y: point.y)
            if distance(startLocation, pointLocation) <= tolerance {
                draggedPointIndex = index
                break
            }
        }
        
        if let pointIndex = draggedPointIndex {
            editExistingPointHandles(pointIndex: pointIndex, currentLocation: currentLocation)
        } else {
            createNewPointWithHandles(startLocation: startLocation, currentLocation: currentLocation)
        }
    }
    
    // MARK: - Path Updates
    
    internal func updateActiveBezierShapeInDocument(isLiveDrag: Bool = false, shouldSendUpdate: Bool = true) {
        guard let activeBezierShape = activeBezierShape,
              let updatedPath = bezierPath,
              let layerIndex = document.selectedLayerIndex else { return }
        
        // Find the shape in the document and update it
        let shapes = document.getShapesForLayer(layerIndex)
        for shapeIndex in shapes.indices {
            if let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
               currentShape.id == activeBezierShape.id {
                // Update the path with the latest bezier path data
                var updatedShape = currentShape
                updatedShape.path = updatedPath
                
                if !isLiveDrag {
                    // Only update styles when not dragging for better performance
                    document.createStrokeStyleInUnified(
                        id: activeBezierShape.id,
                        color: document.defaultStrokeColor,
                        width: document.defaultStrokeWidth,
                        placement: document.defaultStrokePlacement,
                        lineCap: document.defaultStrokeLineCap,
                        lineJoin: document.defaultStrokeLineJoin,
                        miterLimit: document.defaultStrokeMiterLimit,
                        opacity: document.defaultStrokeOpacity
                    )
                    
                    updatedShape.updateBounds()
                }
                
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                break
            }
        }
        
        if shouldSendUpdate {
            document.objectWillChange.send()
        }
    }
    
    internal func finishBezierPath() {
        guard let activeBezierShape = activeBezierShape else {
            cancelBezierDrawing()
            return
        }

        // Apply colors even for incomplete paths
        if bezierPoints.count < 2 {
            ensureIncompletePathHasProperColors(shape: activeBezierShape)
            cancelBezierDrawing()
            currentShapeId = nil
            return
        }

        // Apply final colors to the path
        applyFinalColorsToPath(shape: activeBezierShape)

        // Reset bezier state BUT KEEP pen tool active for continuous tracing
        cancelBezierDrawing()
    }
    
    internal func finishBezierPenDrag() {
        // Reset bezier drag state
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
        
        // Update the real shape in the document
        updateActiveBezierShapeInDocument()
    }
    
    // MARK: - Path Continuation Helpers
    
    internal func shouldShowContinuePathHint() -> (Bool, CGPoint?) {
        guard document.currentTool == .bezierPen && !isBezierDrawing else {
            return (false, nil)
        }
        
        if let selectedPointID = selectedPoints.first,
           let pointPosition = getPointPosition(selectedPointID) {
            return (true, CGPoint(x: pointPosition.x, y: pointPosition.y))
        }
        
        return (false, nil)
    }
    
    // MARK: - Angle Constraint Helpers
    
    internal var constraintAngles: [Double] {
        return [0, 45, 90, 135, 180, 225, 270, 315]
    }
    
    internal func findBestIntersectionPoint(from currentPoint: CGPoint, toward target: CGPoint) -> CGPoint? {
        guard isBezierDrawing && bezierPoints.count >= 1 else { return nil }
        
        let dx = target.x - currentPoint.x
        let dy = target.y - currentPoint.y
        let currentAngle = atan2(dy, dx)
        var currentAngleDegrees = currentAngle * 180.0 / .pi
        if currentAngleDegrees < 0 {
            currentAngleDegrees += 360
        }
        
        var closestAngleFromCurrent = constraintAngles[0]
        var minDiff = 360.0
        for angle in constraintAngles {
            let diff = abs(currentAngleDegrees - angle)
            let wrappedDiff = min(diff, 360 - diff)
            if wrappedDiff < minDiff {
                minDiff = wrappedDiff
                closestAngleFromCurrent = angle
            }
        }
        
        let angleFromCurrentRad = closestAngleFromCurrent * .pi / 180.0
        
        var bestIntersection: CGPoint?
        var bestScore = Double.infinity
        
        for existingPoint in bezierPoints {
            for constraintAngleFromPoint in constraintAngles {
                let angleFromPointRad = constraintAngleFromPoint * .pi / 180.0
                
                let cos1 = cos(angleFromCurrentRad)
                let sin1 = sin(angleFromCurrentRad)
                let cos2 = cos(angleFromPointRad)
                let sin2 = sin(angleFromPointRad)
                
                let denominator = cos1 * sin2 - sin1 * cos2
                
                if abs(denominator) > 0.001 {
                    let dx0 = existingPoint.x - currentPoint.x
                    let dy0 = existingPoint.y - currentPoint.y
                    
                    let t1 = (dx0 * sin2 - dy0 * cos2) / denominator
                    let t2 = (dx0 * sin1 - dy0 * cos1) / denominator
                    
                    if t1 > 0 && t2 > 0 {
                        let intersectionX = currentPoint.x + t1 * cos1
                        let intersectionY = currentPoint.y + t1 * sin1
                        let intersection = CGPoint(x: intersectionX, y: intersectionY)
                        
                        let distToTarget = sqrt(pow(target.x - intersection.x, 2) +
                                               pow(target.y - intersection.y, 2))
                        
                        if distToTarget < bestScore {
                            bestScore = distToTarget
                            bestIntersection = intersection
                        }
                    }
                }
            }
        }
        
        return bestIntersection
    }
    
    // MARK: - Private Helper Methods
    
    private func constrainToAngle(from reference: CGPoint, to target: CGPoint) -> CGPoint {
        let dx = target.x - reference.x
        let dy = target.y - reference.y
        let distance = sqrt(dx * dx + dy * dy)
        
        guard distance > 0.001 else { return target }
        
        if isBezierDrawing && bezierPoints.count >= 1 {
            if let intersectionPoint = findBestIntersectionPoint(from: reference, toward: target) {
                return intersectionPoint
            }
        }
        
        let angle = atan2(dy, dx)
        var angleDegrees = angle * 180.0 / .pi
        if angleDegrees < 0 {
            angleDegrees += 360
        }
        
        var closestAngle = constraintAngles[0]
        var minDifference = 360.0
        
        for constraintAngle in constraintAngles {
            let diff = abs(angleDegrees - constraintAngle)
            let wrappedDiff = min(diff, 360 - diff)
            if wrappedDiff < minDifference {
                minDifference = wrappedDiff
                closestAngle = constraintAngle
            }
        }
        
        let constrainedAngleRad = closestAngle * .pi / 180.0
        let constrainedX = reference.x + distance * cos(constrainedAngleRad)
        let constrainedY = reference.y + distance * sin(constrainedAngleRad)
        
        return CGPoint(x: constrainedX, y: constrainedY)
    }
    
    private func getShapeForPoint(_ pointID: PointID) -> VectorShape? {
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if shape.id == pointID.shapeID {
                    return shape
                }
                
                if shape.isGroupContainer {
                    if let groupedShape = shape.groupedShapes.first(where: { $0.id == pointID.shapeID }) {
                        return groupedShape
                    }
                }
            }
        }
        return nil
    }
    
    private func createNewBezierPath(at location: CGPoint) {
        let newPath = VectorPath(elements: [.move(to: VectorPoint(location))])
        bezierPath = newPath
        bezierPoints = [VectorPoint(location)]
        isBezierDrawing = true
        activeBezierPointIndex = 0
        bezierHandles.removeAll()

        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: document.defaultStrokeWidth,
            placement: document.defaultStrokePlacement,
            dashPattern: [],
            lineCap: document.defaultStrokeLineCap,
            lineJoin: document.defaultStrokeLineJoin,
            miterLimit: document.defaultStrokeMiterLimit,
            opacity: document.defaultStrokeOpacity
        )
        let fillStyle: FillStyle? = nil

        activeBezierShape = VectorShape(
            name: "Bezier Path",
            path: newPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        if let shape = activeBezierShape {
            currentShapeId = shape.id
            document.addShape(shape)
        }
    }

    private func continueExistingPath(from pointPosition: VectorPoint) {

        let newPath = VectorPath(elements: [.move(to: pointPosition)])
        bezierPath = newPath
        bezierPoints = [pointPosition]
        isBezierDrawing = true
        activeBezierPointIndex = 0
        bezierHandles.removeAll()

        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: document.defaultStrokeWidth,
            placement: document.defaultStrokePlacement,
            dashPattern: [],
            lineCap: document.defaultStrokeLineCap,
            lineJoin: document.defaultStrokeLineJoin,
            miterLimit: document.defaultStrokeMiterLimit,
            opacity: document.defaultStrokeOpacity
        )
        let fillStyle: FillStyle? = nil

        activeBezierShape = VectorShape(
            name: "Bezier Path (Continued)",
            path: newPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        if let shape = activeBezierShape {
            currentShapeId = shape.id
            document.addShape(shape)
        }
        
        selectedPoints.removeAll()
        document.objectWillChange.send()
    }
    
    private func addCornerPoint(at location: CGPoint) {
        let newPoint = VectorPoint(location)
        bezierPoints.append(newPoint)
        activeBezierPointIndex = bezierPoints.count - 1
        
        let previousPointIndex = bezierPoints.count - 2
        
        if previousPointIndex >= 0,
           let previousHandles = bezierHandles[previousPointIndex],
           let previousControl2 = previousHandles.control2 {
            bezierPath?.addElement(.curve(to: newPoint, control1: previousControl2, control2: newPoint))
        } else {
            bezierPath?.addElement(.line(to: newPoint))
        }

        updateActiveBezierShapeInDocument(isLiveDrag: true)
    }
    
    private func applyAngleConstraintForDrag(currentLocation: CGPoint, startLocation: CGPoint) -> CGPoint {
        let referencePoint: CGPoint
        if isDraggingBezierHandle {
            if let activeIndex = activeBezierPointIndex, activeIndex < bezierPoints.count {
                let point = bezierPoints[activeIndex]
                referencePoint = CGPoint(x: point.x, y: point.y)
            } else if !bezierPoints.isEmpty {
                if let lastPoint = bezierPoints.last {
                    referencePoint = CGPoint(x: lastPoint.x, y: lastPoint.y)
                } else {
                    referencePoint = currentLocation
                }
            } else {
                referencePoint = startLocation
            }
        } else {
            if let lastPoint = bezierPoints.last {
                referencePoint = CGPoint(x: lastPoint.x, y: lastPoint.y)
            } else {
                referencePoint = currentLocation
            }
        }
        return constrainToAngle(from: referencePoint, to: currentLocation)
    }
    
    private func handleFirstPointCreationFromDrag(startLocation: CGPoint) {
        if let selectedPointID = selectedPoints.first {
            if getShapeForPoint(selectedPointID) != nil,
               let pointPosition = getPointPosition(selectedPointID) {
                continueExistingPath(from: pointPosition)
            } else {
                createNewPathFromDrag(at: startLocation)
            }
        } else {
            createNewPathFromDrag(at: startLocation)
        }
    }
    
    private func createNewPathFromDrag(at location: CGPoint) {
        let firstPoint = VectorPoint(location)
        let newPath = VectorPath(elements: [.move(to: firstPoint)])
        bezierPath = newPath
        bezierPoints = [firstPoint]
        isBezierDrawing = true
        activeBezierPointIndex = 0
        bezierHandles.removeAll()

        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: document.defaultStrokeWidth,
            opacity: document.defaultStrokeOpacity
        )
        let fillStyle: FillStyle? = nil

        let newShape = VectorShape(
            name: "Bezier Path",
            path: newPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        activeBezierShape = newShape
        document.addShape(newShape)
    }

    private func editExistingPointHandles(pointIndex: Int, currentLocation: CGPoint) {
        if !isDraggingBezierHandle {
            isDraggingBezierHandle = true
            isDraggingBezierPoint = true
        }
        
        let point = bezierPoints[pointIndex]
        let pointLocation = CGPoint(x: point.x, y: point.y)
        
        let dragVector = CGPoint(
            x: currentLocation.x - pointLocation.x,
            y: currentLocation.y - pointLocation.y
        )
        
        let control1 = VectorPoint(
            pointLocation.x - dragVector.x,
            pointLocation.y - dragVector.y
        )
        let control2 = VectorPoint(
            pointLocation.x + dragVector.x,
            pointLocation.y + dragVector.y
        )
        
        bezierHandles[pointIndex] = BezierHandleInfo(
            control1: control1,
            control2: control2,
            hasHandles: true
        )
        
        updatePathWithHandles()
        updateActiveBezierShapeInDocument(isLiveDrag: true)
    }
    
    private func createNewPointWithHandles(startLocation: CGPoint, currentLocation: CGPoint) {
        if !isDraggingBezierHandle {
            isDraggingBezierHandle = true
            
            let lastPoint = bezierPoints.last
            let distanceToLastPoint = lastPoint.map { distance(startLocation, CGPoint(x: $0.x, y: $0.y)) } ?? Double.infinity
            
            let baseDuplicateTolerance: Double = 5.0
            let zoomLevel = document.zoomLevel
            let duplicateTolerance = max(1.0, baseDuplicateTolerance / zoomLevel)
            
            if distanceToLastPoint > duplicateTolerance {
                let newPoint = VectorPoint(startLocation)
                bezierPoints.append(newPoint)
                activeBezierPointIndex = bezierPoints.count - 1
                bezierPath?.addElement(.line(to: newPoint))
            } else {
                activeBezierPointIndex = bezierPoints.count - 1
            }
        }
        
        let activeIndex = bezierPoints.count - 1
        let activePoint = bezierPoints[activeIndex]
        let activeLocation = CGPoint(x: activePoint.x, y: activePoint.y)
        
        let dragVector = CGPoint(
            x: currentLocation.x - activeLocation.x,
            y: currentLocation.y - activeLocation.y
        )
        
        let control1 = VectorPoint(
            activeLocation.x - dragVector.x * 0.5,
            activeLocation.y - dragVector.y * 0.5
        )
        let control2 = VectorPoint(
            activeLocation.x + dragVector.x * 0.5,
            activeLocation.y + dragVector.y * 0.5
        )
        
        bezierHandles[activeIndex] = BezierHandleInfo(
            control1: control1,
            control2: control2,
            hasHandles: true
        )
        
        updatePathWithHandles()
        updateActiveBezierShapeInDocument(isLiveDrag: true)
    }
    
    private func applyFinalColorsToPath(shape: VectorShape) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        
        let shapes = document.getShapesForLayer(layerIndex)
        for shapeIndex in shapes.indices {
            if let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
               currentShape.id == shape.id {
                document.createStrokeStyleInUnified(
                    id: shape.id,
                    color: document.defaultStrokeColor,
                    width: document.defaultStrokeWidth,
                    placement: document.defaultStrokePlacement,
                    lineCap: document.defaultStrokeLineCap,
                    lineJoin: document.defaultStrokeLineJoin,
                    miterLimit: document.defaultStrokeMiterLimit,
                    opacity: document.defaultStrokeOpacity
                )
                
                document.createFillStyleInUnified(
                    id: shape.id,
                    color: document.defaultFillColor,
                    opacity: document.defaultFillOpacity
                )
                
                var updatedShape = currentShape
                updatedShape.updateBounds()
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                
                document.updateUnifiedObjectsOptimized()
                break
            }
        }

        document.objectWillChange.send()
    }
}