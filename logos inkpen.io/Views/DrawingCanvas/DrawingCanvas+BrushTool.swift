import SwiftUI
import simd

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

        // Brush strokes should never have a stroke outline - they ARE the stroke
        let strokeStyle: StrokeStyle? = nil
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

        // Apply deduplication to preview points for smoother rendering
        // Keep using CPU for live preview to avoid Metal overhead
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
            strokeStyle: nil,  // Brush strokes are fill-only, never stroked
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

            // Skip CPU coincident point removal - not needed with current processing
            // Metal or CPU deduplication already happened in finalizeFromPreview
        }

        document.addShapeToFront(finalShape)

    }

    private func finalizeFromPreview(_ preview: VectorPath) {
        guard document.selectedLayerIndex != nil else { return }

        guard brushRawPoints.count >= 2 else { return }

        var dedupedPoints: [BrushPoint] = []
        let dupThreshold = ApplicationSettings.shared.currentBrushSmoothingTolerance

        // Use Metal GPU for coincident point removal
        var usedMetal = false
        if brushRawPoints.count > 10 {  // Only use Metal for larger paths where it's beneficial
            print("🚀 FINAL: Using Metal GPU to simplify \(brushRawPoints.count) points")

            // Convert to Metal-ready format (Metal functions handle SIMD internally)
            let pressures = brushRawPoints.map { Float($0.pressure) }

            let result = MetalComputeEngine.shared.removeCoincidentPointsGPU(
                brushRawPoints.map { $0.location },
                pressures: pressures,
                tolerance: Float(dupThreshold)
            )

            switch result {
            case .success(let (cleanedPoints, cleanedPressures)):
                if let pressures = cleanedPressures {
                    dedupedPoints = zip(cleanedPoints, pressures).map {
                        BrushPoint(location: $0.0, pressure: Double($0.1))
                    }
                    print("✅ Metal GPU simplified: \(brushRawPoints.count) → \(dedupedPoints.count) points")
                } else {
                    dedupedPoints = cleanedPoints.map {
                        BrushPoint(location: $0, pressure: 1.0)
                    }
                }
                usedMetal = true  // Mark that we successfully used Metal
            case .failure(let error):
                print("⚠️ Metal failed: \(error), using CPU fallback")
                usedMetal = false  // Metal failed, will use CPU
                // CPU fallback
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
        }

        // Only use CPU if Metal wasn't used
        if !usedMetal {
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

        // Brush strokes should never have a stroke outline - they ARE the stroke
        let strokeStyle: StrokeStyle? = nil
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

            // Skip CPU coincident point removal if Metal already handled it
            // This prevents the duplicate processing that was causing artifacts
            // Metal has already done the simplification
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
                    let distance = point.distance(to: rawPoint.location)
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

    // SIMD-optimized brush offset calculation for real-time drawing performance
    private func generateOffsetPoints(centerPoints: [(location: CGPoint, thickness: Double)], isLeftSide: Bool) -> [CGPoint] {
        var offsetPoints: [CGPoint] = []

        for i in 0..<centerPoints.count {
            let point = centerPoints[i]
            let thickness = point.thickness
            var perpVec: SIMD2<Double>

            if i == 0 {
                if i + 1 < centerPoints.count {
                    let nextPoint = centerPoints[i + 1].location
                    // SIMD vector subtraction
                    let dir = nextPoint.simd - point.location.simd
                    perpVec = SIMD2(-dir.y, dir.x)
                } else {
                    perpVec = SIMD2(0, 1)
                }
            } else if i == centerPoints.count - 1 {
                let prevPoint = centerPoints[i - 1].location
                // SIMD vector subtraction
                let dir = point.location.simd - prevPoint.simd
                perpVec = SIMD2(-dir.y, dir.x)
            } else {
                let prevPoint = centerPoints[i - 1].location
                let nextPoint = centerPoints[i + 1].location
                let incomingDir = point.location.simd - prevPoint.simd
                let outgoingDir = nextPoint.simd - point.location.simd

                // SIMD normalize with length check
                let incomingLen = simd_length(incomingDir)
                let outgoingLen = simd_length(outgoingDir)

                let normIncoming = incomingLen > 0 ? simd_normalize(incomingDir) : incomingDir
                let normOutgoing = outgoingLen > 0 ? simd_normalize(outgoingDir) : outgoingDir

                // SIMD average and perpendicular
                let avgDirection = (normIncoming + normOutgoing) * 0.5
                perpVec = SIMD2(-avgDirection.y, avgDirection.x)
            }

            // SIMD normalize perpendicular
            let length = simd_length(perpVec)
            if length > 0 {
                perpVec = simd_normalize(perpVec)
            } else {
                continue
            }

            // SIMD offset calculation
            let offsetDistance = thickness / 2.0
            let multiplier = isLeftSide ? 1.0 : -1.0
            let offsetVec = point.location.simd + perpVec * offsetDistance * multiplier
            let offsetPoint = CGPoint(offsetVec)

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
        // Create a path that traces the outline: down left side, across bottom, up right side, across top
        // But we need to connect the paths properly without an explicit close
        var elements: [PathElement] = []

        // Add the left edge (going from start to end)
        elements.append(contentsOf: leftEdgePath.elements)

        // Connect to the right edge (already reversed, so goes from end back to start)
        // Skip the first move command to make it continuous
        var isFirst = true
        for element in rightEdgePath.elements {
            if isFirst {
                isFirst = false
                switch element {
                case .move(_):
                    // Skip the move - we're already positioned at the end of left edge
                    continue
                default:
                    break
                }
            }
            elements.append(element)
        }

        // DON'T add .close - the fill rule will handle it
        // The path naturally forms a closed shape without the explicit close line
        return VectorPath(elements: elements)
    }

}
