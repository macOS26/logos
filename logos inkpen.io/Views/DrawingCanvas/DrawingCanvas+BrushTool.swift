import SwiftUI

extension DrawingCanvas {

    func isPathBoundsFinite(_ rect: CGRect) -> Bool {
        return rect.origin.x.isFinite && rect.origin.y.isFinite &&
               rect.size.width.isFinite && rect.size.height.isFinite
    }

    internal func cancelBrushDrawing() {
        brushPath = nil
        brushRawPoints.removeAll()
        brushSimplifiedPoints.removeAll()
        isBrushDrawing = false
        activeBrushShape = nil
    }

    internal func handleBrushDragStart(at location: CGPoint) {
        guard !isBrushDrawing else { return }

        isBrushDrawing = true

        document.hasPressureInput = PressureManager.shared.hasRealPressureInput

        // Use current pressure instead of hardcoded 1.0 to avoid false positive bulge at start
        let startPressure = PressureManager.shared.currentPressure
        brushRawPoints = [BrushPoint(location: location, pressure: startPressure)]
        brushSimplifiedPoints = []

        PressureManager.shared.resetForNewDrawing()

        let startPoint = VectorPoint(location)
        brushPath = VectorPath(elements: [.move(to: startPoint)])

        let strokeStyle: StrokeStyle? = document.brushApplyNoStroke ? nil : StrokeStyle(
            color: getCurrentStrokeColor(),
            width: getCurrentStrokeWidth(),
            lineCap: document.defaultStrokeLineCap,
            lineJoin: document.defaultStrokeLineJoin,
            miterLimit: document.defaultStrokeMiterLimit,
            opacity: getCurrentStrokeOpacity()
        )
        let fillStyle = FillStyle(
            color: getCurrentFillColor(),
            opacity: getCurrentFillOpacity()
        )

        activeBrushShape = VectorShape(
            name: "Brush Stroke",
            path: brushPath!,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
    }

    internal func handleBrushDragUpdate(at location: CGPoint, pressure: Double? = nil) {
        guard isBrushDrawing else { return }

        let actualPressure = pressure ?? PressureManager.shared.currentPressure

        let newPoint = BrushPoint(location: location, pressure: actualPressure)
        brushRawPoints.append(newPoint)

        updateBrushPreview()

        if brushRawPoints.count > 1000 {
            brushRawPoints = Array(brushRawPoints.suffix(800))
        }
    }

    internal func handleBrushDragEnd() {
        guard isBrushDrawing else { return }

        if brushRawPoints.count == 2 {
            let startPoint = brushRawPoints[0]
            let endPoint = brushRawPoints[1]
            var interpolatedPoints: [BrushPoint] = [startPoint]

            let numIntermediatePoints = 4
            for i in 1...numIntermediatePoints {
                let t = Double(i) / Double(numIntermediatePoints + 1)
                let interpolatedLocation = CGPoint(
                    x: startPoint.location.x + (endPoint.location.x - startPoint.location.x) * t,
                    y: startPoint.location.y + (endPoint.location.y - startPoint.location.y) * t
                )
                let interpolatedPressure = startPoint.pressure + (endPoint.pressure - startPoint.pressure) * t
                interpolatedPoints.append(BrushPoint(
                    location: interpolatedLocation,
                    pressure: interpolatedPressure
                ))
            }

            interpolatedPoints.append(endPoint)
            brushRawPoints = interpolatedPoints
        }

        if let preview = brushPreviewPath {
            finalizeFromPreview(preview)
        } else {
            processBrushStroke()
        }

        brushPreviewPath = nil
        cancelBrushDrawing()

        document.selectedShapeIDs.removeAll()
        document.selectedObjectIDs.removeAll()
        document.selectedTextIDs.removeAll()
    }

    private func updateBrushPreview() {
        guard brushRawPoints.count >= 2 else { return }

        let newPreviewPath = generateLivePreviewPath()
        brushPreviewPath = newPreviewPath
    }

    private func generateLivePreviewPath() -> VectorPath {
        guard brushRawPoints.count >= 2 else {
            return VectorPath(elements: [.move(to: VectorPoint(brushRawPoints[0].location))])
        }

        var pointsToProcess = brushRawPoints
        if brushRawPoints.count == 2 {
            let startPoint = brushRawPoints[0]
            let endPoint = brushRawPoints[1]
            var interpolatedPoints: [BrushPoint] = [startPoint]

            let dx = endPoint.location.x - startPoint.location.x
            let dy = endPoint.location.y - startPoint.location.y
            let lineLength = sqrt(dx * dx + dy * dy)
            let perpX = lineLength > 0 ? -dy / lineLength : 0
            let perpY = lineLength > 0 ? dx / lineLength : 0
            let numIntermediatePoints = 5
            for i in 1...numIntermediatePoints {
                let t = Double(i) / Double(numIntermediatePoints + 1)
                let jitterAmount = sin(t * .pi) * 2.0

                let interpolatedLocation = CGPoint(
                    x: startPoint.location.x + (endPoint.location.x - startPoint.location.x) * t + perpX * jitterAmount,
                    y: startPoint.location.y + (endPoint.location.y - startPoint.location.y) * t + perpY * jitterAmount
                )

                let interpolatedPressure = startPoint.pressure + (endPoint.pressure - startPoint.pressure) * t

                interpolatedPoints.append(BrushPoint(
                    location: interpolatedLocation,
                    pressure: interpolatedPressure
                ))
            }

            interpolatedPoints.append(endPoint)
            pointsToProcess = interpolatedPoints
        }

        let rawPointLocations = pointsToProcess.map { $0.location }

        if rawPointLocations.count >= 2 {
            let newPath = generatePreviewVariableWidthPath(
                centerPoints: rawPointLocations,
                recentRawPoints: pointsToProcess,
                thickness: document.currentBrushThickness,
                pressureSensitivity: 0.5,
                taper: 0.5
            )
            return newPath
        }

        return VectorPath(elements: [.move(to: VectorPoint(rawPointLocations[0]))])
    }

    private func generateLivePreviewPathOffMain(
        rawPoints: [BrushPoint],
        thickness: Double,
        pressureSensitivity: Double,
        taper: Double,
        previewTolerance: Double
    ) -> VectorPath {
        guard rawPoints.count >= 2 else {
            return VectorPath(elements: [.move(to: VectorPoint(rawPoints[0].location))])
        }

        var pointsToProcess = rawPoints
        if rawPoints.count == 2 {
            let startPoint = rawPoints[0]
            let endPoint = rawPoints[1]
            var interpolatedPoints: [BrushPoint] = [startPoint]

            let dx = endPoint.location.x - startPoint.location.x
            let dy = endPoint.location.y - startPoint.location.y
            let lineLength = sqrt(dx * dx + dy * dy)
            let perpX = lineLength > 0 ? -dy / lineLength : 0
            let perpY = lineLength > 0 ? dx / lineLength : 0
            let numIntermediatePoints = 5
            for i in 1...numIntermediatePoints {
                let t = Double(i) / Double(numIntermediatePoints + 1)
                let jitterAmount = sin(t * .pi) * 2.0

                let interpolatedLocation = CGPoint(
                    x: startPoint.location.x + (endPoint.location.x - startPoint.location.x) * t + perpX * jitterAmount,
                    y: startPoint.location.y + (endPoint.location.y - startPoint.location.y) * t + perpY * jitterAmount
                )

                let basePressure = startPoint.pressure + (endPoint.pressure - startPoint.pressure) * t
                let pressureVariation = sin(t * .pi) * 0.15
                let interpolatedPressure = min(1.0, basePressure * (1.0 + pressureVariation))

                interpolatedPoints.append(BrushPoint(
                    location: interpolatedLocation,
                    pressure: interpolatedPressure
                ))
            }

            interpolatedPoints.append(endPoint)
            pointsToProcess = interpolatedPoints
        }

        let rawPointLocations = pointsToProcess.map { $0.location }
        var simplifiedPoints: [CGPoint] = DrawingCanvasPathHelpers.douglasPeuckerSimplify(points: rawPointLocations, tolerance: previewTolerance * 0.01)

        if simplifiedPoints.count < 30 && rawPointLocations.count > 2 {
            simplifiedPoints = DrawingCanvasPathHelpers.douglasPeuckerSimplify(points: rawPointLocations, tolerance: previewTolerance * 0.001)
            if simplifiedPoints.count < 30 {
                let stepSize = max(1, rawPointLocations.count / 50)
                simplifiedPoints = []
                for i in Swift.stride(from: 0, to: rawPointLocations.count, by: stepSize) {
                    simplifiedPoints.append(rawPointLocations[i])
                }
                if let last = rawPointLocations.last, simplifiedPoints.last != last {
                    simplifiedPoints.append(last)
                }
            }
        }

        if simplifiedPoints.count >= 2 {
            return generatePreviewVariableWidthPath(
                centerPoints: simplifiedPoints,
                recentRawPoints: pointsToProcess,
                thickness: thickness,
                pressureSensitivity: pressureSensitivity,
                taper: taper
            )
        } else {
            return VectorPath(elements: [.move(to: VectorPoint(pointsToProcess[0].location))])
        }
    }

    private func processBrushStroke() {
        guard brushRawPoints.count >= 2,
              activeBrushShape != nil,
              document.selectedLayerIndex != nil else {
            return
        }

        if brushRawPoints.count <= 4 {
            return
        }

        brushSimplifiedPoints = brushRawPoints.map { $0.location }

        let brushStrokePath = generateSmoothVariableWidthPath(
            centerPoints: brushSimplifiedPoints,
            rawPoints: brushRawPoints,
            thickness: document.currentBrushThickness,
            pressureSensitivity: 0.5,
            taper: 0.5
        )

        var finalShape = VectorShape(
            name: "Brush Stroke",
            path: brushStrokePath,
            strokeStyle: document.brushApplyNoStroke ? nil : StrokeStyle(
                color: getCurrentStrokeColor(),
                width: getCurrentStrokeWidth(),
                opacity: getCurrentStrokeOpacity()
            ),
            fillStyle: FillStyle(
                color: getCurrentFillColor(),
                opacity: getCurrentFillOpacity()
            )
        )

        if document.brushRemoveOverlap {
            let cg = finalShape.path.cgPath
            var cleaned: CGPath? = nil
            cleaned = CoreGraphicsPathOperations.normalized(cg, using: .winding)
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.normalized(cg, using: .evenOdd) }
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.union(cg, cg, using: .winding) }
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.union(cg, cg, using: .evenOdd) }
            if let cleanedPath = cleaned, !cleanedPath.isEmpty, isPathBoundsFinite(cleanedPath.boundingBox) {
                finalShape.path = VectorPath(cgPath: cleanedPath)
            }

            finalShape.path = ProfessionalPathOperations.mergeAdjacentCoincidentPoints(in: finalShape.path, tolerance: 1.1)
        }

        document.addShapeToFront(finalShape)

    }

    private func finalizeFromPreview(_ preview: VectorPath) {
        guard document.selectedLayerIndex != nil else { return }

        guard brushRawPoints.count >= 2 else { return }

        var dedupedPoints: [BrushPoint] = []
        let dupThreshold = document.currentBrushSmoothingTolerance

        for point in brushRawPoints {
            if let lastPoint = dedupedPoints.last {
                let distance = hypot(point.location.x - lastPoint.location.x,
                                   point.location.y - lastPoint.location.y)
                if distance < dupThreshold {
                    continue
                }
            }
            dedupedPoints.append(point)
        }

        let dedupedLocations = dedupedPoints.map { $0.location }

        guard dedupedLocations.count >= 2 else { return }

        if dedupedLocations.count == 2 {
            let start = dedupedLocations[0]
            let end = dedupedLocations[1]
            let distance = hypot(end.x - start.x, end.y - start.y)
            guard distance >= 2.0 else { return }
        }

        var finalPath: VectorPath

        if dedupedLocations.count >= 2 {
            finalPath = generatePreviewVariableWidthPath(
                centerPoints: dedupedLocations,
                recentRawPoints: dedupedPoints,
                thickness: document.currentBrushThickness,
                pressureSensitivity: 0.5,
                taper: 0.5
            )
        } else {
            finalPath = preview
        }

        let strokeStyle: StrokeStyle? = document.brushApplyNoStroke ? nil : StrokeStyle(
            color: getCurrentStrokeColor(),
            width: getCurrentStrokeWidth(),
            lineCap: document.defaultStrokeLineCap,
            lineJoin: document.defaultStrokeLineJoin,
            miterLimit: document.defaultStrokeMiterLimit,
            opacity: getCurrentStrokeOpacity()
        )
        let fillStyle = FillStyle(color: getCurrentFillColor(), opacity: getCurrentFillOpacity())

        if document.brushRemoveOverlap {
            let currentPath = finalPath.cgPath
            var cleaned: CGPath? = nil
            cleaned = CoreGraphicsPathOperations.union(currentPath, currentPath, using: .winding)
            if cleaned == nil {
                cleaned = CoreGraphicsPathOperations.normalized(currentPath, using: .winding)
            }

            if let cleanedPath = cleaned, !cleanedPath.isEmpty, isPathBoundsFinite(cleanedPath.boundingBox) {
                finalPath = VectorPath(cgPath: cleanedPath, fillRule: .winding)
            }

            finalPath = ProfessionalPathOperations.mergeAdjacentCoincidentPoints(in: finalPath, tolerance: 1.1)
        }
        let shape = VectorShape(name: "Brush Stroke", path: finalPath, geometricType: .brushStroke, strokeStyle: strokeStyle, fillStyle: fillStyle)
        document.addShape(shape)
    }

    private func applySelfUnionToBrushStroke(shapeIndex: Int, layerIndex: Int) {

        let shapes = document.getShapesForLayer(layerIndex)
        guard shapeIndex < shapes.count else {
            return
        }

        guard let brushStroke = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else {
            return
        }

        guard brushStroke.id == activeBrushShape?.id else {
            return
        }

        let originalPath = brushStroke.path.cgPath

        guard !originalPath.isEmpty else {
            return
        }

        let pathBounds = originalPath.boundingBox
        guard isPathBoundsFinite(pathBounds) && !pathBounds.isNull else {
            return
        }

        if let cleanedPath = CoreGraphicsPathOperations.normalized(originalPath) {
            guard !cleanedPath.isEmpty && isPathBoundsFinite(cleanedPath.boundingBox) else {
                return
            }
            
            let cleanedVectorPath = VectorPath(cgPath: cleanedPath)
            var updatedShape = brushStroke
            updatedShape.path = cleanedVectorPath
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
        }
    }

    private func generatePreviewVariableWidthPath(centerPoints: [CGPoint], recentRawPoints: [BrushPoint], thickness: Double, pressureSensitivity: Double, taper: Double) -> VectorPath {
        guard centerPoints.count >= 2 else {
            return VectorPath(elements: [.move(to: VectorPoint(centerPoints[0]))])
        }

        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []

        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)
            var finalThickness = thickness

            var mappedPressure = 1.0
            if appState.pressureSensitivityEnabled && !recentRawPoints.isEmpty {
                var closestDistance = Double.infinity
                var closestPressure = 1.0

                for rawPoint in recentRawPoints {
                    let distance = sqrt(pow(point.x - rawPoint.location.x, 2) + pow(point.y - rawPoint.location.y, 2))
                    if distance < closestDistance {
                        closestDistance = distance
                        closestPressure = rawPoint.pressure
                    }
                }

                let curve = appState.pressureCurve
                mappedPressure = getThicknessFromPressureCurve(pressure: closestPressure, curve: curve)
            }

            let taperZone = 0.15
            var taperMultiplier = 1.0

            if progress < taperZone {
                let t = progress / taperZone
                taperMultiplier = pow(t, 1.5)
            } else if progress > (1.0 - taperZone) {
                let t = (1.0 - progress) / taperZone
                taperMultiplier = pow(t, 1.5)
            }

            finalThickness *= (taperMultiplier * mappedPressure)

            let minThickness = document.currentBrushMinTaperThickness
            if finalThickness > 0 {
                finalThickness = max(finalThickness, minThickness)
            }

            thicknessPoints.append((location: point, thickness: finalThickness))
        }

        let leftEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: true)
        let rightEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: false)
        let leftEdgePath = DrawingCanvasPathHelpers.createSmoothBezierPath(from: leftEdgePoints)
        let rightEdgePath = DrawingCanvasPathHelpers.createSmoothBezierPath(from: rightEdgePoints.reversed())

        return createSmoothBrushOutline(leftEdgePath: leftEdgePath, rightEdgePath: rightEdgePath)
    }

    private func interpolatePressureForPoint(_ targetPoint: CGPoint, from rawPoints: [BrushPoint]) -> Double {
        guard !rawPoints.isEmpty else { return 1.0 }

        var firstClosest: (distance: Double, pressure: Double) = (Double.infinity, 1.0)
        var secondClosest: (distance: Double, pressure: Double) = (Double.infinity, 1.0)

        for rawPoint in rawPoints {
            let distance = hypot(
                targetPoint.x - rawPoint.location.x,
                targetPoint.y - rawPoint.location.y
            )

            if distance < firstClosest.distance {
                secondClosest = firstClosest
                firstClosest = (distance, rawPoint.pressure)
            } else if distance < secondClosest.distance {
                secondClosest = (distance, rawPoint.pressure)
            }
        }

        if secondClosest.distance != Double.infinity && firstClosest.distance > 0 {
            let totalDistance = firstClosest.distance + secondClosest.distance
            if totalDistance > 0 {
                let weight1 = secondClosest.distance / totalDistance
                let weight2 = firstClosest.distance / totalDistance

                return weight1 * firstClosest.pressure + weight2 * secondClosest.pressure
            }
        }

        return firstClosest.pressure
    }

    private func detectStraightLine(points: [CGPoint]) -> Bool {
        guard points.count >= 2 else { return false }

        guard let start = points.first, let end = points.last else {
            return false
        }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lineLength = sqrt(dx * dx + dy * dy)

        if lineLength < 50 { return true }

        var maxDeviation: Double = 0
        for point in points {
            let deviation = abs((dy * point.x - dx * point.y + end.x * start.y - end.y * start.x) / lineLength)
            maxDeviation = max(maxDeviation, deviation)
        }

        return maxDeviation < lineLength * 0.05
    }

    private func generateSmoothVariableWidthPath(centerPoints: [CGPoint], rawPoints: [BrushPoint], thickness: Double, pressureSensitivity: Double, taper: Double) -> VectorPath {
        guard centerPoints.count >= 2 else {
            return VectorPath(elements: [.move(to: VectorPoint(rawPoints[0].location))])
        }

        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []

        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)
            var finalThickness = thickness

            var mappedPressure = 1.0
            if appState.pressureSensitivityEnabled {
                let interpolatedPressure = interpolatePressureForPoint(point, from: rawPoints)
                let curve = appState.pressureCurve
                mappedPressure = getThicknessFromPressureCurve(pressure: interpolatedPressure, curve: curve)
            }

            let taperZone = 0.15
            var taperMultiplier = 1.0

            if progress < taperZone {
                let t = progress / taperZone
                taperMultiplier = pow(t, 1.5)
            } else if progress > (1.0 - taperZone) {
                let t = (1.0 - progress) / taperZone
                taperMultiplier = pow(t, 1.5)
            }

            finalThickness *= (taperMultiplier * mappedPressure)

            let minThickness = document.currentBrushMinTaperThickness
            if finalThickness > 0 {
                finalThickness = max(finalThickness, minThickness)
            }

            thicknessPoints.append((location: point, thickness: finalThickness))
        }

        let leftEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: true)
        let rightEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: false)
        let leftEdgePath = DrawingCanvasPathHelpers.createSmoothBezierPath(from: leftEdgePoints)
        let rightEdgePath = DrawingCanvasPathHelpers.createSmoothBezierPath(from: rightEdgePoints.reversed())

        return createSmoothBrushOutline(leftEdgePath: leftEdgePath, rightEdgePath: rightEdgePath)
    }

    private func generateOffsetPoints(centerPoints: [(location: CGPoint, thickness: Double)], isLeftSide: Bool) -> [CGPoint] {
        var offsetPoints: [CGPoint] = []

        for i in 0..<centerPoints.count {
            let point = centerPoints[i]
            let thickness = point.thickness
            var perpendicular: CGPoint

            if i == 0 {
                if i + 1 < centerPoints.count {
                    let nextPoint = centerPoints[i + 1].location
                    let direction = CGPoint(x: nextPoint.x - point.location.x, y: nextPoint.y - point.location.y)
                    perpendicular = CGPoint(x: -direction.y, y: direction.x)
                } else {
                    perpendicular = CGPoint(x: 0, y: 1)
                }
            } else if i == centerPoints.count - 1 {
                let prevPoint = centerPoints[i - 1].location
                let direction = CGPoint(x: point.location.x - prevPoint.x, y: point.location.y - prevPoint.y)
                perpendicular = CGPoint(x: -direction.y, y: direction.x)
            } else {
                let prevPoint = centerPoints[i - 1].location
                let nextPoint = centerPoints[i + 1].location
                let incomingDir = CGPoint(x: point.location.x - prevPoint.x, y: point.location.y - prevPoint.y)
                let outgoingDir = CGPoint(x: nextPoint.x - point.location.x, y: nextPoint.y - point.location.y)

                // Normalize incoming and outgoing directions
                let incomingLength = sqrt(incomingDir.x * incomingDir.x + incomingDir.y * incomingDir.y)
                let outgoingLength = sqrt(outgoingDir.x * outgoingDir.x + outgoingDir.y * outgoingDir.y)

                let normIncoming = incomingLength > 0 ? CGPoint(x: incomingDir.x / incomingLength, y: incomingDir.y / incomingLength) : incomingDir
                let normOutgoing = outgoingLength > 0 ? CGPoint(x: outgoingDir.x / outgoingLength, y: outgoingDir.y / outgoingLength) : outgoingDir

                let avgDirection = CGPoint(
                    x: (normIncoming.x + normOutgoing.x) / 2,
                    y: (normIncoming.y + normOutgoing.y) / 2
                )

                perpendicular = CGPoint(x: -avgDirection.y, y: avgDirection.x)
            }

            let length = sqrt(perpendicular.x * perpendicular.x + perpendicular.y * perpendicular.y)
            if length > 0 {
                perpendicular.x /= length
                perpendicular.y /= length
            } else {
                // If perpendicular is zero (180° turn), skip this point
                continue
            }

            let offsetDistance = thickness / 2.0
            let multiplier = isLeftSide ? 1.0 : -1.0
            let offsetPoint = CGPoint(
                x: point.location.x + perpendicular.x * offsetDistance * multiplier,
                y: point.location.y + perpendicular.y * offsetDistance * multiplier
            )

            offsetPoints.append(offsetPoint)
        }

        return offsetPoints
    }

    private func createBrushStrokeOutline(leftEdge: [CGPoint], rightEdge: [CGPoint]) -> VectorPath {
        var elements: [PathElement] = []

        guard !leftEdge.isEmpty && !rightEdge.isEmpty else {
            return VectorPath(elements: elements)
        }

        elements.append(.move(to: VectorPoint(leftEdge[0])))

        for i in 1..<leftEdge.count {
            elements.append(.line(to: VectorPoint(leftEdge[i])))
        }

        if let lastRightEdge = rightEdge.last {
            elements.append(.line(to: VectorPoint(lastRightEdge)))
        }

        for i in stride(from: rightEdge.count - 2, through: 0, by: -1) {
            elements.append(.line(to: VectorPoint(rightEdge[i])))
        }

        elements.append(.close)

        return VectorPath(elements: elements)
    }

    private func createSmoothBrushOutline(leftEdgePath: VectorPath, rightEdgePath: VectorPath) -> VectorPath {
        var elements: [PathElement] = []

        elements.append(contentsOf: leftEdgePath.elements)

        if let lastLeftPoint = leftEdgePath.elements.last {
            switch lastLeftPoint {
            case .move(_), .line(_), .curve(_, _, _), .quadCurve(_, _):
                if let firstRightElement = rightEdgePath.elements.first {
                    switch firstRightElement {
                    case .move(let rightPoint), .line(let rightPoint), .curve(let rightPoint, _, _), .quadCurve(let rightPoint, _):
                        elements.append(.line(to: rightPoint))
                    case .close:
                        break
                    }
                }
            case .close:
                break
            }
        }

        let rightElements = rightEdgePath.elements.dropFirst()
        elements.append(contentsOf: rightElements)

        elements.append(.close)

        return VectorPath(elements: elements)
    }

}
