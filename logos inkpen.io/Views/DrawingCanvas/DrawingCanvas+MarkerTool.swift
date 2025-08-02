//
//  DrawingCanvas+MarkerTool.swift
//  logos inkpen.io
//
//  Marker tool - creates smooth strokes with circular felt-tip marker
//  Based on Sharpie, Rapidograph, and other felt-tip markers
//

import SwiftUI
import Foundation

extension DrawingCanvas {
    
    // MARK: - Marker Tool Management
    
    internal func cancelMarkerDrawing() {
        markerPath = nil
        markerRawPoints.removeAll()
        markerSimplifiedPoints.removeAll()
        isMarkerDrawing = false
        activeMarkerShape = nil
    }
    
    internal func handleMarkerDragStart(at location: CGPoint) {
        // Start new marker stroke with proper initialization
        guard !isMarkerDrawing else { return }
        
        // Initialize marker drawing state
        isMarkerDrawing = true
        markerRawPoints = [MarkerPoint(location: location, pressure: 1.0, timestamp: Date())]
        markerSimplifiedPoints = []
        
        // Reset pressure manager for new drawing
        PressureManager.shared.resetForNewDrawing()
        
        // Create initial VectorPath for center line
        let startPoint = VectorPoint(location)
        markerPath = VectorPath(elements: [.move(to: startPoint)])
        
        // Create real VectorShape for marker stroke using current user settings
        // MARKER SPECIFIC: Creates variable width filled shapes instead of strokes
        let strokeColor = document.markerApplyNoStroke ? nil : getCurrentStrokeColor()
        let strokeWidth = getCurrentStrokeWidth() // Use stroke weight from fill/stroke tool
        
        // For marker tool: if "Use Fill as Stroke" is enabled, use fill color for both fill and stroke
        // Otherwise, use stroke color for both fill and stroke
        let markerFillColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        let markerStrokeColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        
        let strokeStyle = strokeColor != nil ? StrokeStyle(
            color: markerStrokeColor,
            width: strokeWidth,
            lineCap: .round,
            lineJoin: .round,
            opacity: getCurrentStrokeOpacity()
        ) : nil
        
        let fillStyle = FillStyle(
            color: markerFillColor,
            opacity: getCurrentFillOpacity()
        )
        
        activeMarkerShape = VectorShape(
            name: "Marker Stroke",
            path: markerPath!,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        // Add the preview shape to the document immediately
        document.addShape(activeMarkerShape!)
        
        print("🖊️ MARKER: Started drawing at \(location)")
    }
    
    internal func handleMarkerDragUpdate(at location: CGPoint) {
        guard isMarkerDrawing else { return }
        
        // Get pressure using smart detection (real or simulated)
        let pressure = PressureManager.shared.getPressure(for: location, sensitivity: document.currentMarkerPressureSensitivity)
        
        // Add point to raw path with pressure data
        let markerPoint = MarkerPoint(location: location, pressure: pressure, timestamp: Date())
        markerRawPoints.append(markerPoint)
        
        // Update real-time preview
        updateMarkerPreview()
        
        // Limit raw points array to prevent memory issues
        if markerRawPoints.count > 1000 {
            // Keep last 800 points
            markerRawPoints = Array(markerRawPoints.suffix(800))
        }
    }
    
    internal func handleMarkerDragEnd() {
        guard isMarkerDrawing else { return }
        
        print("🖊️ MARKER: Finishing drawing with \(markerRawPoints.count) raw points")
        
        // Process marker stroke to create smooth felt-tip stroke
        processMarkerStroke()
        
        // Clean up state
        cancelMarkerDrawing()
        
        // AUTO-DESELECT: Clear selection after completing marker stroke
        // This allows user to immediately change colors for the next stroke
        document.selectedShapeIDs.removeAll()
        print("🎨 MARKER: Auto-deselected shape to enable color changes for next stroke")
        
        print("✅ MARKER: Stroke completed and converted to smooth felt-tip stroke")
    }
    
    // MARK: - Pressure Simulation for Felt-Tip Marker
    
    private func calculateMarkerPressure(at location: CGPoint) -> Double {
        // If pressure sensitivity is disabled, return constant pressure
        if !appState.pressureSensitivityEnabled {
            return 1.0
        }
        
        guard markerRawPoints.count > 1 else { return 1.0 }
        
        let lastPoint = markerRawPoints.last!.location
        let distance = sqrt(pow(location.x - lastPoint.x, 2) + pow(location.y - lastPoint.y, 2))
        
        // Simulate pressure based on drawing speed for felt-tip marker
        // Fast drawing = light pressure (thin line), slow drawing = heavy pressure (thick line)
        let maxSpeed: Double = 100.0 // Maximum pixels per measurement
        let normalizedSpeed = min(distance / maxSpeed, 1.0)
        let basePressure = 1.0 - (normalizedSpeed * 0.5) // Reduce pressure with speed
        
        // Apply current marker sensitivity setting (dedicated marker settings)
        let sensitivity = document.currentMarkerPressureSensitivity
        let pressureVariation = (basePressure - 0.5) * sensitivity
        
        return max(0.1, min(1.0, 0.5 + pressureVariation))
    }
    
    // MARK: - Real-time Preview
    
    private func updateMarkerPreview() {
        guard let activeMarkerShape = activeMarkerShape,
              markerRawPoints.count >= 2,
              let layerIndex = document.selectedLayerIndex else { return }
        
        // LIVE PREVIEW: Generate actual felt-tip marker stroke in real-time!
        let previewPath = generateMarkerLivePreviewPath()
        
        // Find and update the shape in the document with the REAL marker preview
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == activeMarkerShape.id }) {
            document.layers[layerIndex].shapes[shapeIndex].path = previewPath
            
            // Update colors using current user settings and marker options
            let strokeColor = document.markerApplyNoStroke ? nil : getCurrentStrokeColor()
            let strokeWidth = getCurrentStrokeWidth()
            
            // For marker tool: if "Use Fill as Stroke" is enabled, use fill color for both fill and stroke
            // Otherwise, use stroke color for both fill and stroke
            let markerFillColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
            let markerStrokeColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
            
            document.layers[layerIndex].shapes[shapeIndex].strokeStyle = strokeColor != nil ? StrokeStyle(
                color: markerStrokeColor,
                width: strokeWidth,
                lineCap: .round,
                lineJoin: .round,
                opacity: getCurrentStrokeOpacity()
            ) : nil
            
            document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                color: markerFillColor,
                opacity: getCurrentFillOpacity()
            )
        }
    }
    
    /// Generate live preview of the felt-tip marker stroke as the user draws
    private func generateMarkerLivePreviewPath() -> VectorPath {
        guard markerRawPoints.count >= 2 else {
            // Fallback for insufficient points
            return VectorPath(elements: [.move(to: VectorPoint(markerRawPoints[0].location))])
        }
        
        // Show the COMPLETE stroke, not just recent points
        let rawPointLocations = markerRawPoints.map { $0.location }
        
        // PERFORMANCE OPTIMIZATION: Use a slightly higher tolerance for live preview
        let previewSmoothingTolerance = document.currentMarkerSmoothingTolerance * 1.25
        let simplifiedPoints = douglasPeuckerSimplify(
            points: rawPointLocations,
            tolerance: previewSmoothingTolerance
        )
        
        // Generate smooth felt-tip marker stroke
        if simplifiedPoints.count >= 2 {
            return createSmoothMarkerStroke(
                centerPoints: simplifiedPoints,
                recentRawPoints: markerRawPoints
            )
        } else {
            // Fallback for single point - create a small dot
            return createMarkerDot(at: markerRawPoints[0].location)
        }
    }
    
    // MARK: - Marker Stroke Processing
    
    private func processMarkerStroke() {
        guard markerRawPoints.count >= 3,
              let activeMarkerShape = activeMarkerShape,
              let layerIndex = document.selectedLayerIndex else { 
            print("🖊️ MARKER: Too few points (\(markerRawPoints.count)) - keeping as simple stroke")
            return 
        }
        
        // Step 1: Simplify the raw points using Douglas-Peucker algorithm (marker-specific)
        let smoothingTolerance = document.currentMarkerSmoothingTolerance
        markerSimplifiedPoints = douglasPeuckerSimplify(
            points: markerRawPoints.map { $0.location },
            tolerance: smoothingTolerance
        )
        
        // Step 2: Generate smooth felt-tip marker stroke
        let markerStrokePath = createFinalMarkerStroke(
            centerPoints: markerSimplifiedPoints,
            recentRawPoints: markerRawPoints
        )
        
        // Step 3: Replace the preview shape with the final marker stroke
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == activeMarkerShape.id }) {
            // Update the shape with final marker stroke using current user settings and toggles
            var finalShape = document.layers[layerIndex].shapes[shapeIndex]
            finalShape.path = markerStrokePath
            
            let strokeColor = document.markerApplyNoStroke ? nil : getCurrentStrokeColor()
            let strokeWidth = getCurrentStrokeWidth()
            
            // For marker tool: if "Use Fill Color for Stroke" is enabled, use fill color for both fill and stroke
            // Otherwise, use stroke color for both fill and stroke
            let markerFillColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
            let markerStrokeColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
            
            finalShape.strokeStyle = strokeColor != nil ? StrokeStyle(
                color: markerStrokeColor,
                width: strokeWidth,
                lineCap: .round,
                lineJoin: .round,
                opacity: getCurrentStrokeOpacity()
            ) : nil
            
            finalShape.fillStyle = FillStyle(
                color: markerFillColor,
                opacity: getCurrentFillOpacity()
            )
            
            document.layers[layerIndex].shapes[shapeIndex] = finalShape
            
            // Apply self-union operation if remove overlap is enabled
            if document.markerRemoveOverlap {
                print("🔍 MARKER DEBUG: === MARKER REMOVE OVERLAP ENABLED ===")
                print("🔍 MARKER DEBUG: About to call applySelfUnionToMarkerStroke with shapeIndex: \(shapeIndex)")
                print("🔍 MARKER DEBUG: Layer \(layerIndex) has \(document.layers[layerIndex].shapes.count) shapes BEFORE remove overlap")
                
                applySelfUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
                
                print("🔍 MARKER DEBUG: Layer \(layerIndex) has \(document.layers[layerIndex].shapes.count) shapes AFTER remove overlap")
                print("🔍 MARKER DEBUG: === MARKER REMOVE OVERLAP COMPLETED ===")
            }
        } else {
            print("🚨 MARKER ERROR: Could not find activeMarkerShape in layer! ID: \(activeMarkerShape.id)")
        }
        
        print("🖊️ MARKER: Generated smooth felt-tip stroke with \(markerSimplifiedPoints.count) control points")
    }
    
    // MARK: - Marker Stroke Generation
    
    /// Generate smooth felt-tip marker stroke with variable width
    private func createSmoothMarkerStroke(centerPoints: [CGPoint], recentRawPoints: [MarkerPoint]) -> VectorPath {
        guard centerPoints.count >= 2 else {
            // Fallback for single point - create a dot
            return createMarkerDot(at: centerPoints[0])
        }
        
        // Create variable-width felt-tip marker stroke
        return createVariableWidthMarkerStroke(centerPoints: centerPoints, rawPoints: recentRawPoints)
    }
    
    /// Create final marker stroke with proper smoothing
    private func createFinalMarkerStroke(centerPoints: [CGPoint], recentRawPoints: [MarkerPoint]) -> VectorPath {
        guard centerPoints.count >= 2 else {
            // Fallback for single point - create a dot
            return createMarkerDot(at: centerPoints[0])
        }
        
        // Create variable-width felt-tip marker stroke
        return createVariableWidthMarkerStroke(centerPoints: centerPoints, rawPoints: recentRawPoints)
    }
    
    /// Create variable-width felt-tip marker stroke with realistic pressure simulation and SMOOTH BEZIER CURVES
    private func createVariableWidthMarkerStroke(centerPoints: [CGPoint], rawPoints: [MarkerPoint]) -> VectorPath {
        guard centerPoints.count >= 2 else {
            return createMarkerDot(at: centerPoints[0])
        }
        
        // Calculate variable thickness at each simplified point with pressure and tapering
        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []
        
        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)
            
            // Get pressure at this point
            let pressure = getPressureAtPoint(point, rawPoints: rawPoints)
            
            // Base thickness from marker settings
            var finalThickness = document.currentMarkerTipSize
            
            // Apply tapering at start and end (like brush tool)
            let startTaper = document.currentMarkerTaperStart
            let endTaper = document.currentMarkerTaperEnd
            
            if progress < startTaper {
                // Taper from 0 to full thickness at start
                finalThickness *= (progress / startTaper)
            } else if progress > (1.0 - endTaper) {
                // Taper from full thickness to 0 at end
                let endProgress = (1.0 - progress) / endTaper
                finalThickness *= endProgress
            }
            
            // Apply pressure variation (30% to 100% of base thickness)
            finalThickness *= (0.3 + pressure * 0.7)
            
            // Apply feathering effect for felt-tip appearance
            let feathering = document.currentMarkerFeathering
            finalThickness *= (1.0 - feathering * 0.2) // Slight thickness reduction for feathering
            
            thicknessPoints.append((location: point, thickness: finalThickness))
        }
        
        // Generate left and right edge points with variable thickness
        let leftEdgePoints = generateMarkerOffsetPoints(centerPoints: thicknessPoints, isLeftSide: true)
        let rightEdgePoints = generateMarkerOffsetPoints(centerPoints: thicknessPoints, isLeftSide: false)
        
        // Create simple filled outline like brush tool - NO COMPLEX CAPS!
        return createSimpleMarkerOutline(leftEdgePoints: leftEdgePoints, rightEdgePoints: rightEdgePoints)
    }
    
    /// Get pressure at a specific point by interpolating from raw points
    private func getPressureAtPoint(_ point: CGPoint, rawPoints: [MarkerPoint]) -> Double {
        guard rawPoints.count > 0 else { return 1.0 }
        
        // Find the closest raw point
        var closestDistance = Double.infinity
        var closestPressure: Double = 1.0
        
        for rawPoint in rawPoints {
            let distance = sqrt(pow(point.x - rawPoint.location.x, 2) + pow(point.y - rawPoint.location.y, 2))
            if distance < closestDistance {
                closestDistance = distance
                closestPressure = rawPoint.pressure
            }
        }
        
        return closestPressure
    }
    
    /// Generate offset points for marker edges with variable thickness
    private func generateMarkerOffsetPoints(centerPoints: [(location: CGPoint, thickness: Double)], isLeftSide: Bool) -> [CGPoint] {
        var offsetPoints: [CGPoint] = []
        
        for i in 0..<centerPoints.count {
            let point = centerPoints[i]
            let thickness = point.thickness
            
            // Calculate perpendicular direction for offset
            var perpendicular: CGPoint
            
            if i == 0 {
                // Use direction to next point
                if i + 1 < centerPoints.count {
                    let nextPoint = centerPoints[i + 1].location
                    let direction = CGPoint(x: nextPoint.x - point.location.x, y: nextPoint.y - point.location.y)
                    perpendicular = CGPoint(x: -direction.y, y: direction.x)
                } else {
                    perpendicular = CGPoint(x: 0, y: 1) // Default vertical
                }
            } else if i == centerPoints.count - 1 {
                // Use direction from previous point
                let prevPoint = centerPoints[i - 1].location
                let direction = CGPoint(x: point.location.x - prevPoint.x, y: point.location.y - prevPoint.y)
                perpendicular = CGPoint(x: -direction.y, y: direction.x)
            } else {
                // Use average direction from previous and next points
                let prevPoint = centerPoints[i - 1].location
                let nextPoint = centerPoints[i + 1].location
                let direction = CGPoint(x: nextPoint.x - prevPoint.x, y: nextPoint.y - prevPoint.y)
                perpendicular = CGPoint(x: -direction.y, y: direction.x)
            }
            
            // Normalize perpendicular vector
            let length = sqrt(perpendicular.x * perpendicular.x + perpendicular.y * perpendicular.y)
            if length > 0 {
                perpendicular = CGPoint(x: perpendicular.x / length, y: perpendicular.y / length)
            }
            
            // Calculate offset distance (half thickness on each side)
            let offsetDistance = thickness / 2.0
            let multiplier: Double = isLeftSide ? 1.0 : -1.0
            
            let offsetPoint = CGPoint(
                x: point.location.x + perpendicular.x * offsetDistance * multiplier,
                y: point.location.y + perpendicular.y * offsetDistance * multiplier
            )
            
            offsetPoints.append(offsetPoint)
        }
        
        return offsetPoints
    }
    
    /// Create smooth bezier path from points (same algorithm as brush and freehand tools)
    private func createSmoothBezierPath(from points: [CGPoint]) -> VectorPath {
        guard points.count >= 2 else {
            return VectorPath(elements: [])
        }
        
        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(points[0])))
        
        if points.count == 2 {
            // Simple line for two points
            elements.append(.line(to: VectorPoint(points[1])))
        } else {
            // Create smooth curves through all points
            let curveSegments = fitBezierCurves(through: points)
            elements.append(contentsOf: curveSegments)
        }
        
        return VectorPath(elements: elements)
    }
    
    /// Create simple marker outline like brush tool - just a filled stroke shape
    private func createSimpleMarkerOutline(leftEdgePoints: [CGPoint], rightEdgePoints: [CGPoint]) -> VectorPath {
        guard leftEdgePoints.count >= 2 && rightEdgePoints.count >= 2 else {
            // Fallback for insufficient points
            if let firstPoint = leftEdgePoints.first {
                return VectorPath(elements: [.move(to: VectorPoint(firstPoint))])
            }
            return VectorPath(elements: [])
        }
        
        var elements: [PathElement] = []
        
        // Start at first left point
        elements.append(.move(to: VectorPoint(leftEdgePoints[0])))
        
        // Create smooth bezier curves along left edge
        if leftEdgePoints.count == 2 {
            elements.append(.line(to: VectorPoint(leftEdgePoints[1])))
        } else {
            let leftCurves = fitBezierCurves(through: leftEdgePoints)
            elements.append(contentsOf: leftCurves)
        }
        
        // Connect to right edge at end (smooth transition)
        elements.append(.line(to: VectorPoint(rightEdgePoints.last!)))
        
        // Create smooth bezier curves along right edge (in reverse)
        let reversedRightPoints = rightEdgePoints.reversed()
        if reversedRightPoints.count == 2 {
            elements.append(.line(to: VectorPoint(Array(reversedRightPoints)[1])))
        } else {
            let rightCurves = fitBezierCurves(through: Array(reversedRightPoints))
            elements.append(contentsOf: rightCurves)
        }
        
        // Close back to start
        elements.append(.close)
        
        return VectorPath(elements: elements)
    }
    
    /// Create a small dot for single marker points
    private func createMarkerDot(at center: CGPoint) -> VectorPath {
        // Create a small circle for single points using marker settings
        let radius = document.currentMarkerTipSize / 2.0
        var elements: [PathElement] = []
        
        // Create a circle using bezier curves (4 curve segments)
        let controlPointDistance = radius * 0.552284749831 // Magic number for circle approximation
        
        // Start at right point
        elements.append(.move(to: VectorPoint(center.x + radius, center.y)))
        
        // Top curve
        elements.append(.curve(
            to: VectorPoint(center.x, center.y + radius),
            control1: VectorPoint(center.x + radius, center.y + controlPointDistance),
            control2: VectorPoint(center.x + controlPointDistance, center.y + radius)
        ))
        
        // Left curve
        elements.append(.curve(
            to: VectorPoint(center.x - radius, center.y),
            control1: VectorPoint(center.x - controlPointDistance, center.y + radius),
            control2: VectorPoint(center.x - radius, center.y + controlPointDistance)
        ))
        
        // Bottom curve
        elements.append(.curve(
            to: VectorPoint(center.x, center.y - radius),
            control1: VectorPoint(center.x - radius, center.y - controlPointDistance),
            control2: VectorPoint(center.x - controlPointDistance, center.y - radius)
        ))
        
        // Right curve (back to start)
        elements.append(.curve(
            to: VectorPoint(center.x + radius, center.y),
            control1: VectorPoint(center.x + controlPointDistance, center.y - radius),
            control2: VectorPoint(center.x + radius, center.y - controlPointDistance)
        ))
        
        elements.append(.close)
        
        return VectorPath(elements: elements)
    }
    
    // MARK: - Shared Algorithm Functions (Same as Freehand/Brush Tools)
    
    private func douglasPeuckerSimplify(points: [CGPoint], tolerance: Double) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        return douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: 0, endIndex: points.count - 1)
    }
    
    private func douglasPeuckerRecursive(points: [CGPoint], tolerance: Double, startIndex: Int, endIndex: Int) -> [CGPoint] {
        guard endIndex - startIndex > 1 else {
            return [points[startIndex], points[endIndex]]
        }
        
        let startPoint = points[startIndex]
        let endPoint = points[endIndex]
        
        // Find the point with maximum distance from the line segment
        var maxDistance: Double = 0
        var maxIndex = startIndex
        
        for i in (startIndex + 1)..<endIndex {
            let distance = perpendicularDistance(point: points[i], lineStart: startPoint, lineEnd: endPoint)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        // If the maximum distance is greater than tolerance, recursively simplify
        if maxDistance > tolerance {
            // Recursively simplify the two segments
            let leftSegment = douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: startIndex, endIndex: maxIndex)
            let rightSegment = douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: maxIndex, endIndex: endIndex)
            
            // Combine segments (remove duplicate point at the connection)
            return leftSegment + Array(rightSegment.dropFirst())
        } else {
            // All points between start and end are within tolerance - return only endpoints
            return [startPoint, endPoint]
        }
    }
    
    private func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let A = lineEnd.y - lineStart.y
        let B = lineStart.x - lineEnd.x
        let C = lineEnd.x * lineStart.y - lineStart.x * lineEnd.y
        
        let distance = abs(A * point.x + B * point.y + C) / sqrt(A * A + B * B)
        return distance
    }
    
    private func fitBezierCurves(through points: [CGPoint]) -> [PathElement] {
        var elements: [PathElement] = []
        
        // Use a simple curve fitting approach that creates smooth C1 continuous curves
        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            
            // MARKER SPECIFIC: Make only first and last segments lines (corner points)
            // The second and second-last points should be smooth for better marker appearance
            let isFirstSegment = (i == 1)
            let isLastSegment = (i == points.count - 1)
            
            if isFirstSegment || isLastSegment {
                // Create corner points only for start and end - no handles
                elements.append(.line(to: VectorPoint(p1)))
            } else {
                // Calculate control points for smooth curves (middle segments only)
                let tension: Double = 0.25 // Curve tension factor
                let distance = sqrt(pow(p1.x - p0.x, 2) + pow(p1.y - p0.y, 2))
                
                // Calculate tangent directions
                let prevTangent = i > 1 ? calculateTangent(p0: points[i - 2], p1: p0, p2: p1) : CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
                let nextTangent = i < points.count - 1 ? calculateTangent(p0: p0, p1: p1, p2: points[i + 1]) : CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
                
                // Create control points
                let controlLength = distance * tension
                
                let control1 = CGPoint(
                    x: p0.x + prevTangent.x * controlLength,
                    y: p0.y + prevTangent.y * controlLength
                )
                
                let control2 = CGPoint(
                    x: p1.x - nextTangent.x * controlLength,
                    y: p1.y - nextTangent.y * controlLength
                )
                
                elements.append(.curve(
                    to: VectorPoint(p1),
                    control1: VectorPoint(control1),
                    control2: VectorPoint(control2)
                ))
            }
        }
        
        return elements
    }
    
    private func calculateTangent(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        // Calculate normalized tangent direction at p1
        let dx1 = p1.x - p0.x
        let dy1 = p1.y - p0.y
        let dx2 = p2.x - p1.x
        let dy2 = p2.y - p1.y
        
        // Average the two segments
        let avgDx = (dx1 + dx2) / 2
        let avgDy = (dy1 + dy2) / 2
        
        // Normalize
        let length = sqrt(avgDx * avgDx + avgDy * avgDy)
        if length > 0 {
            return CGPoint(x: avgDx / length, y: avgDy / length)
        } else {
            return CGPoint(x: 1, y: 0)
        }
    }
    
    // MARK: - Remove Overlap Functionality
    
    /// Apply self-union operation to remove overlapping areas within the single marker stroke
    private func applySelfUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        print("🔍 MARKER OVERLAP DEBUG: === STARTING SELF-UNION OPERATION ===")
        print("🔍 MARKER OVERLAP DEBUG: Target shapeIndex: \(shapeIndex), layerIndex: \(layerIndex)")
        print("🔍 MARKER OVERLAP DEBUG: BEFORE operation - Layer has \(document.layers[layerIndex].shapes.count) shapes:")
        for (i, shape) in document.layers[layerIndex].shapes.enumerated() {
            print("🔍 MARKER OVERLAP DEBUG:   Shape \(i): '\(shape.name)' ID: \(shape.id)")
        }
        
        guard shapeIndex < document.layers[layerIndex].shapes.count else { 
            print("🚨 MARKER ERROR: Shape index \(shapeIndex) out of bounds! Layer has \(document.layers[layerIndex].shapes.count) shapes")
            return 
        }
        
        let markerStroke = document.layers[layerIndex].shapes[shapeIndex]
        
        // VERIFY: Make sure we're operating on the correct shape
        guard markerStroke.id == activeMarkerShape?.id else {
            print("🚨 MARKER ERROR: Shape ID mismatch! Expected \(activeMarkerShape?.id ?? UUID()), got \(markerStroke.id)")
            print("🚨 MARKER ERROR: This would affect the WRONG shape - ABORTING self-union")
            return
        }
        
        print("🔍 MARKER OVERLAP DEBUG: ✅ Verified correct shape - proceeding with self-union")
        
        // Handle different behaviors based on stroke/fill color matching
        let hasStroke = markerStroke.strokeStyle != nil
        let hasFill = markerStroke.fillStyle != nil
        
        if hasStroke && hasFill {
            let strokeColor = markerStroke.strokeStyle!.color
            let fillColor = markerStroke.fillStyle!.color
            
            if strokeColor == fillColor {
                // Same color: expand stroke and combine with fill as one shape
                print("🔍 MARKER OVERLAP DEBUG: Stroke and fill are same color - expanding stroke and combining")
                applyExpandedStrokeUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
            } else {
                // Different colors: union stroke separately, union fill separately
                print("🔍 MARKER OVERLAP DEBUG: Stroke and fill are different colors - processing separately")
                applyDualUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
            }
        } else {
            // Only stroke or only fill: simple union
            print("🔍 MARKER OVERLAP DEBUG: Single color mode - applying simple union")
            applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
        }
    }
    
    /// Apply union operation for markers with same stroke/fill color or single color
    private func applySingleUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        let markerStroke = document.layers[layerIndex].shapes[shapeIndex]
        
        // Convert VectorPath to CGPath for boolean operations
        let originalPath = markerStroke.path.cgPath
        
        // SAFETY CHECK: Ensure path is valid before union operation
        guard !originalPath.isEmpty else {
            print("🚨 MARKER ERROR: Original path is empty - ABORTING self-union")
            return
        }
        
        // SAFETY CHECK: Verify path has valid bounds
        let pathBounds = originalPath.boundingBox
        guard isPathBoundsFinite(pathBounds) && !pathBounds.isNull else {
            print("🚨 MARKER ERROR: Path has invalid bounds - ABORTING self-union")
            return
        }
        
        // Apply self-union to remove any self-intersections within the marker stroke
        if let cleanedPath = CoreGraphicsPathOperations.union(originalPath, originalPath) {
            // SAFETY CHECK: Verify the result path is valid
            guard !cleanedPath.isEmpty && isPathBoundsFinite(cleanedPath.boundingBox) else {
                print("🚨 MARKER ERROR: Union operation produced invalid path - keeping original")
                return
            }
            
            let cleanedVectorPath = VectorPath(cgPath: cleanedPath)
            
            print("🔍 MARKER OVERLAP DEBUG: About to update shape at index \(shapeIndex)")
            print("🔍 MARKER OVERLAP DEBUG: Current shapes count: \(document.layers[layerIndex].shapes.count)")
            
            // Update the marker stroke with the cleaned path
            document.layers[layerIndex].shapes[shapeIndex].path = cleanedVectorPath
            
            print("🔍 MARKER OVERLAP DEBUG: ✅ Updated shape at index \(shapeIndex)")
            print("🖊️ MARKER: Applied self-union to remove overlapping areas within marker stroke")
        } else {
            print("🖊️ MARKER: Self-union operation failed, keeping original path")
        }
    }
    
    /// Apply expanded stroke union for markers with same stroke/fill color
    private func applyExpandedStrokeUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        let markerStroke = document.layers[layerIndex].shapes[shapeIndex]
        
        // Convert VectorPath to CGPath for boolean operations
        let originalPath = markerStroke.path.cgPath
        
        // SAFETY CHECK: Ensure path is valid before union operation
        guard !originalPath.isEmpty else {
            print("🚨 MARKER ERROR: Original path is empty - ABORTING expanded stroke union")
            return
        }
        
        // SAFETY CHECK: Verify path has valid bounds
        let pathBounds = originalPath.boundingBox
        guard isPathBoundsFinite(pathBounds) && !pathBounds.isNull else {
            print("🚨 MARKER ERROR: Path has invalid bounds - ABORTING expanded stroke union")
            return
        }
        
        // Step 1: Expand the stroke of the original path
        if let strokeStyle = markerStroke.strokeStyle,
           let expandedStroke = PathOperations.outlineStroke(path: originalPath, strokeStyle: strokeStyle) {
            
            // Step 2: Union the expanded stroke with itself to remove overlaps
            if let unionedExpandedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .winding) {
                
                // Step 3: Union the expanded stroke with the original fill path
                if let finalPath = CoreGraphicsPathOperations.union(originalPath, unionedExpandedStroke, using: .winding) {
                    
                    // SAFETY CHECK: Verify the result path is valid
                    guard !finalPath.isEmpty && isPathBoundsFinite(finalPath.boundingBox) else {
                        print("🚨 MARKER ERROR: Final union operation produced invalid path - keeping original")
                        return
                    }
                    
                    let finalVectorPath = VectorPath(cgPath: finalPath)
                    
                    print("🔍 MARKER OVERLAP DEBUG: About to update shape at index \(shapeIndex)")
                    print("🔍 MARKER OVERLAP DEBUG: Current shapes count: \(document.layers[layerIndex].shapes.count)")
                    
                    // Update the marker stroke with the combined path and remove the stroke style
                    var updatedShape = markerStroke
                    updatedShape.path = finalVectorPath
                    updatedShape.strokeStyle = nil // Remove stroke since it's now part of the fill
                    updatedShape.fillStyle = FillStyle(
                        color: markerStroke.strokeStyle!.color, // Use stroke color for the combined fill
                        opacity: markerStroke.strokeStyle!.opacity
                    )
                    
                    document.layers[layerIndex].shapes[shapeIndex] = updatedShape
                    
                    print("🔍 MARKER OVERLAP DEBUG: ✅ Updated shape at index \(shapeIndex) with expanded stroke combined")
                    print("🖊️ MARKER: Applied expanded stroke union - stroke and fill combined as single shape")
                } else {
                    print("🖊️ MARKER: Final union operation failed, keeping original path")
                }
            } else {
                print("🖊️ MARKER: Expanded stroke union operation failed, keeping original path")
            }
        } else {
            print("🖊️ MARKER: Stroke expansion failed, falling back to simple union")
            applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
        }
    }
    
    /// Apply separate union operations for markers with different stroke/fill colors
    private func applyDualUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        let markerStroke = document.layers[layerIndex].shapes[shapeIndex]
        
        // For different colors, we need to expand the stroke and union separately
        if let strokeStyle = markerStroke.strokeStyle {
            // Expand the stroke of the original path
            if let expandedStroke = PathOperations.outlineStroke(path: markerStroke.path.cgPath, strokeStyle: strokeStyle) {
                // Union the expanded stroke with itself
                if let unionedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .winding) {
                    // Create a new shape for the unioned stroke
                    let strokeVectorPath = VectorPath(cgPath: unionedStroke)
                    let strokeShape = VectorShape(
                        name: "Marker Stroke (Outline)",
                        path: strokeVectorPath,
                        strokeStyle: nil, // Convert to fill
                        fillStyle: FillStyle(color: strokeStyle.color, opacity: strokeStyle.opacity)
                    )
                    
                    // Replace the original shape's stroke with no stroke and union the fill separately
                    var originalShape = markerStroke
                    originalShape.strokeStyle = nil // Remove stroke since we created separate stroke shape
                    
                    // Union the fill path with itself
                    if let cleanedFillPath = CoreGraphicsPathOperations.union(markerStroke.path.cgPath, markerStroke.path.cgPath) {
                        originalShape.path = VectorPath(cgPath: cleanedFillPath)
                    }
                    
                    // Update the original shape (now fill-only)
                    document.layers[layerIndex].shapes[shapeIndex] = originalShape
                    
                    // Add the stroke shape
                    document.layers[layerIndex].shapes.append(strokeShape)
                    
                    print("🖊️ MARKER: Applied dual union - separated stroke and fill with different colors")
                } else {
                    print("🖊️ MARKER: Stroke union operation failed")
                    applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
                }
            } else {
                print("🖊️ MARKER: Stroke expansion failed")
                applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
            }
        } else {
            // No stroke, just union the fill
            applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
        }
    }
    
    // MARK: - Helper Functions (Same as Brush Tool)
    
    /// Get the current fill color that the user has set (same logic as StrokeFillPanel)
    private func getCurrentFillColor() -> VectorColor {
        // PRIORITY 1: If text objects are selected, use their fill color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.fillColor
        }
        
        // PRIORITY 2: If shapes are selected, use their color
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let fillColor = shape.fillStyle?.color {
            return fillColor
        }
        
        // PRIORITY 3: Use default color for new shapes
        return document.defaultFillColor
    }
    
    /// Get the current fill opacity that the user has set (same logic as StrokeFillPanel)
    private func getCurrentFillOpacity() -> Double {
        // PRIORITY 1: If text objects are selected, use their fill opacity
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.fillOpacity
        }
        
        // PRIORITY 2: If shapes are selected, use their opacity
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let opacity = shape.fillStyle?.opacity {
            return opacity
        }
        
        // PRIORITY 3: Use default opacity for new shapes
        return document.defaultFillOpacity
    }
    
    /// Get the current stroke color that the user has set
    private func getCurrentStrokeColor() -> VectorColor {
        // PRIORITY 1: If text objects are selected, use their stroke color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.strokeColor
        }
        
        // PRIORITY 2: If shapes are selected, use their color
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let strokeColor = shape.strokeStyle?.color {
            return strokeColor
        }
        
        // PRIORITY 3: Use default color for new shapes
        return document.defaultStrokeColor
    }
    
    /// Get the current stroke opacity that the user has set
    private func getCurrentStrokeOpacity() -> Double {
        // PRIORITY 1: If text objects are selected, use their stroke opacity
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.strokeOpacity
        }
        
        // PRIORITY 2: If shapes are selected, use their opacity
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let opacity = shape.strokeStyle?.opacity {
            return opacity
        }
        
        // PRIORITY 3: Use default opacity for new shapes
        return document.defaultStrokeOpacity
    }
    
    /// Get the current stroke width that the user has set
    private func getCurrentStrokeWidth() -> Double {
        // PRIORITY 1: If text objects are selected, use their stroke width
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.strokeWidth
        }
        
        // PRIORITY 2: If shapes are selected, use their width
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let width = shape.strokeStyle?.width {
            return width
        }
        
        // PRIORITY 3: Use default width for new shapes
        return document.defaultStrokeWidth
    }
}

// MARK: - Marker Point Data Structure

struct MarkerPoint {
    let location: CGPoint
    let pressure: Double // 0.0 to 1.0
    let timestamp: Date
    
    init(location: CGPoint, pressure: Double = 1.0, timestamp: Date = Date()) {
        self.location = location
        self.pressure = max(0.0, min(1.0, pressure)) // Clamp between 0 and 1
        self.timestamp = timestamp
    }
} 