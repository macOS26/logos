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

        document.viewState.hasPressureInput = PressureManager.shared.hasRealPressureInput

        // Use current pressure instead of hardcoded 1.0 to avoid false positive bulge at start
        let startPressure = PressureManager.shared.currentPressure
        brushRawPoints = [BrushPoint(location: location, pressure: startPressure)]
        brushSimplifiedPoints = []

        PressureManager.shared.resetForNewDrawing()

        let startPoint = VectorPoint(location)
        brushPath = VectorPath(elements: [.move(to: startPoint)])

        let strokeStyle: StrokeStyle? = ApplicationSettings.shared.brushApplyNoStroke ? nil : StrokeStyle(
            color: getCurrentStrokeColor(),
            width: getCurrentStrokeWidth(),
            lineCap: document.strokeDefaults.lineCap,
            lineJoin: document.strokeDefaults.lineJoin,
            miterLimit: document.strokeDefaults.miterLimit,
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

        document.viewState.selectedObjectIDs.removeAll()
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

        // Use Metal GPU acceleration for point deduplication if available
        var dedupedPoints: [BrushPoint] = []
        let dupThreshold = ApplicationSettings.shared.currentBrushSmoothingTolerance

        // Try Metal GPU acceleration for large point counts
        if ApplicationSettings.shared.useMetalAcceleration && brushRawPoints.count > 50 {
            let points = brushRawPoints.map { $0.location }
            let pressures = brushRawPoints.map { Float($0.pressure) }

            if let result = MetalComputeEngine.shared.removeCoincidentPointsGPU(
                points,
                pressures: pressures,
                tolerance: Float(dupThreshold)
            ).success {
                let (cleanedPoints, cleanedPressures) = result
                dedupedPoints = zip(cleanedPoints, cleanedPressures ?? pressures).map {
                    BrushPoint(location: $0.0, pressure: Double($0.1))
                }
                Log.info("🎨 Metal GPU: Reduced \(brushRawPoints.count) points to \(dedupedPoints.count)", category: .general)
            } else {
                // Fallback to CPU
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
            }
        } else {
            // Use CPU for small point counts (overhead not worth it)
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
        }

        var pointsToProcess = dedupedPoints

        // Handle straight lines with interpolation
        if dedupedPoints.count == 2 {
            let startPoint = dedupedPoints[0]
            let endPoint = dedupedPoints[1]
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

        let dedupedLocations = pointsToProcess.map { $0.location }

        if dedupedLocations.count >= 2 {
            // Use the same smooth path generation as the final version
            let newPath = generateSmoothVariableWidthPath(
                centerPoints: dedupedLocations,
                rawPoints: pointsToProcess,
                thickness: ApplicationSettings.shared.currentBrushThickness,
                pressureSensitivity: 0.5,
                taper: 0.5
            )
            return newPath
        }

        return VectorPath(elements: [.move(to: VectorPoint(dedupedLocations[0]))])
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
            thickness: ApplicationSettings.shared.currentBrushThickness,
            pressureSensitivity: 0.5,
            taper: 0.5
        )

        var finalShape = VectorShape(
            name: "Brush Stroke",
            path: brushStrokePath,
            strokeStyle: ApplicationSettings.shared.brushApplyNoStroke ? nil : StrokeStyle(
                color: getCurrentStrokeColor(),
                width: getCurrentStrokeWidth(),
                opacity: getCurrentStrokeOpacity()
            ),
            fillStyle: FillStyle(
                color: getCurrentFillColor(),
                opacity: getCurrentFillOpacity()
            )
        )

        if ApplicationSettings.shared.brushRemoveOverlap {
            let cg = finalShape.path.cgPath
            var cleaned: CGPath? = nil
            cleaned = CoreGraphicsPathOperations.normalized(cg, using: .winding)
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.normalized(cg, using: .evenOdd) }
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.union(cg, cg, using: .winding) }
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.union(cg, cg, using: .evenOdd) }
            if let cleanedPath = cleaned, !cleanedPath.isEmpty, isPathBoundsFinite(cleanedPath.boundingBox) {
                finalShape.path = VectorPath(cgPath: cleanedPath)
            }

            let passes = ApplicationSettings.shared.brushCoincidentPointPasses
            if passes > 0 {
                // For now, just use CPU path operations since extracting points from CGPath is complex
                for _ in 0..<passes {
                    finalShape.path = ProfessionalPathOperations.mergeAdjacentCoincidentPoints(in: finalShape.path, tolerance: 1.1)
                }
            }
        }

        document.addShapeToFront(finalShape)

    }

    private func finalizeFromPreview(_ preview: VectorPath) {
        guard document.selectedLayerIndex != nil else { return }

        guard brushRawPoints.count >= 2 else { return }

        var dedupedPoints: [BrushPoint] = []
        let dupThreshold = ApplicationSettings.shared.currentBrushSmoothingTolerance

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
                thickness: ApplicationSettings.shared.currentBrushThickness,
                pressureSensitivity: 0.5,
                taper: 0.5
            )
        } else {
            finalPath = preview
        }

        let strokeStyle: StrokeStyle? = ApplicationSettings.shared.brushApplyNoStroke ? nil : StrokeStyle(
            color: getCurrentStrokeColor(),
            width: getCurrentStrokeWidth(),
            lineCap: document.strokeDefaults.lineCap,
            lineJoin: document.strokeDefaults.lineJoin,
            miterLimit: document.strokeDefaults.miterLimit,
            opacity: getCurrentStrokeOpacity()
        )
        let fillStyle = FillStyle(color: getCurrentFillColor(), opacity: getCurrentFillOpacity())

        if ApplicationSettings.shared.brushRemoveOverlap {
            let currentPath = finalPath.cgPath
            var cleaned: CGPath? = nil
            cleaned = CoreGraphicsPathOperations.union(currentPath, currentPath, using: .winding)
            if cleaned == nil {
                cleaned = CoreGraphicsPathOperations.normalized(currentPath, using: .winding)
            }

            if let cleanedPath = cleaned, !cleanedPath.isEmpty, isPathBoundsFinite(cleanedPath.boundingBox) {
                finalPath = VectorPath(cgPath: cleanedPath, fillRule: .winding)
            }

            let passes = ApplicationSettings.shared.brushCoincidentPointPasses
            if passes > 0 {
                // For now, just use CPU path operations since extracting points from CGPath is complex
                for _ in 0..<passes {
                    finalPath = ProfessionalPathOperations.mergeAdjacentCoincidentPoints(in: finalPath, tolerance: 1.1)
                }
            }
        }
        let shape = VectorShape(name: "Brush Stroke", path: finalPath, geometricType: .brushStroke, strokeStyle: strokeStyle, fillStyle: fillStyle)
        document.addShape(shape)
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

            let taperStart = max(0.0, ApplicationSettings.shared.currentBrushTaperStart)
            let taperEnd = max(0.0, ApplicationSettings.shared.currentBrushTaperEnd)
            var taperMultiplier = 1.0

            if taperStart > 0 && progress < taperStart {
                let t = progress / taperStart
                taperMultiplier = pow(t, 1.5)
            } else if taperEnd > 0 && progress > (1.0 - taperEnd) {
                let t = (1.0 - progress) / taperEnd
                taperMultiplier = pow(t, 1.5)
            }

            finalThickness *= (taperMultiplier * mappedPressure)

            let minThickness = ApplicationSettings.shared.currentBrushMinTaperThickness
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

            let taperStart = max(0.0, ApplicationSettings.shared.currentBrushTaperStart)
            let taperEnd = max(0.0, ApplicationSettings.shared.currentBrushTaperEnd)
            var taperMultiplier = 1.0

            if taperStart > 0 && progress < taperStart {
                let t = progress / taperStart
                taperMultiplier = pow(t, 1.5)
            } else if taperEnd > 0 && progress > (1.0 - taperEnd) {
                let t = (1.0 - progress) / taperEnd
                taperMultiplier = pow(t, 1.5)
            }

            finalThickness *= (taperMultiplier * mappedPressure)

            let minThickness = ApplicationSettings.shared.currentBrushMinTaperThickness
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

        // Apply coincident point removal based on user setting
        let passes = ApplicationSettings.shared.brushCoincidentPointPasses
        if passes > 0 {
            return DrawingCanvasPathHelpers.removeCoincidentPoints(offsetPoints, passes: passes, tolerance: 0.1)
        }

        return offsetPoints
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
