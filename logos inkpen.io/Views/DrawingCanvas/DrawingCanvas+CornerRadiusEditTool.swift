//
//  DrawingCanvas+CornerRadiusEditTool.swift
//  logos inkpen.io
//
//  Live corner radius editing tool (Adobe Illustrator style)
//

import SwiftUI

extension DrawingCanvas {
    
    // MARK: - Corner Radius Edit Tool
    
    /// Shows corner radius edit controls when a rectangle-based shape is selected
    @ViewBuilder
    func cornerRadiusEditTool(geometry: GeometryProxy) -> some View {
        if let selectedShape = getSelectedRectangleShape() {
            
            // Get corner positions in screen coordinates - FIXED: Proper bounds for squares
            let boundsToUse = getProperShapeBounds(for: selectedShape)
            let corners = getCornerScreenPositions(bounds: boundsToUse, shape: selectedShape, geometry: geometry)
            
            ForEach(Array(corners.enumerated()), id: \.offset) { index, screenPosition in
                cornerRadiusHandle(
                    cornerIndex: index,
                    position: (isDraggingCorner && draggedCornerIndex == index) 
                        ? currentMousePosition
                        : getCornerScreenPositions(bounds: boundsToUse, shape: selectedShape, geometry: geometry)[index], // FIXED: Always recalculate positions
                    radius: selectedShape.cornerRadii[safe: index] ?? 0.0,
                    shape: selectedShape,
                    geometry: geometry
                )
            }
        }
    }
    
    /// Individual corner radius handle
    @ViewBuilder
    private func cornerRadiusHandle(
        cornerIndex: Int,
        position: CGPoint,
        radius: Double,
        shape: VectorShape,
        geometry: GeometryProxy
    ) -> some View {
        ZStack {
            // Outer circle
            Circle()
                .fill(Color.orange.opacity(0.8))
                .stroke(Color.white, lineWidth: 2.0)
                .frame(width: 12, height: 12)
            
            // Inner dot
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
        }
        .position(position)
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    handleCornerRadiusDrag(
                        cornerIndex: cornerIndex,
                        value: value,
                        shape: shape,
                        geometry: geometry
                    )
                }
                .onEnded { _ in
                    finishCornerRadiusDrag()
                }
        )
    }
    
    // MARK: - Helper Functions
    
    /// Get the currently selected rectangle-based shape (can have corner radius support)
    private func getSelectedRectangleShape() -> VectorShape? {
        guard document.selectedShapeIDs.count == 1 else { return nil }
        
        for layer in document.layers {
            for shape in layer.shapes {
                if document.selectedShapeIDs.contains(shape.id) && isRectangleBasedShape(shape) {
                    return shape
                }
            }
        }
        return nil
    }
    
    /// Check if a shape is a rectangle-based shape that can have corner radius
    private func isRectangleBasedShape(_ shape: VectorShape) -> Bool {
        let shapeName = shape.name.lowercased()
        return shapeName == "rectangle" || shapeName == "square" ||
               shapeName == "rounded rectangle" || shapeName == "pill"
    }
    
    /// Get proper bounds for a shape - ALWAYS uses current path bounds with transforms applied
    private func getProperShapeBounds(for shape: VectorShape) -> CGRect {
        // FIXED: Always use current path bounds AND apply any pending transforms (handles scaling!)
        // This ensures corner handles track the actual visual position/size of scaled objects
        var pathBounds = shape.path.cgPath.boundingBox
        
        // CRITICAL FIX: Apply any pending transforms (scaling, rotation, etc.)
        if !shape.transform.isIdentity {
            // Transform the bounds to match the actual displayed shape
            pathBounds = pathBounds.applying(shape.transform)
        }
        
        // FIXED: Check for squares more robustly - check both name AND if it's actually square-shaped
        let isSquareByName = shape.name.lowercased() == "square"
        let isSquareBySizeRatio = abs(pathBounds.width - pathBounds.height) < 1.0 // Within 1 point difference
        
        if isSquareByName || (isSquareBySizeRatio && shape.name.lowercased() == "rectangle") {
            // Make it a perfect square using the larger dimension to avoid shrinking
            let size = max(pathBounds.width, pathBounds.height)
            let squareBounds = CGRect(
                x: pathBounds.origin.x,
                y: pathBounds.origin.y,
                width: size,
                height: size
            )
            return squareBounds
        }
        
        return pathBounds
    }
    
    /// Extract actual corner points from a shape path (handles skewed shapes)
    private func getActualCornerPoints(from shape: VectorShape) -> [CGPoint] {
        let path = shape.path.cgPath
        
        // ALWAYS extract corner points from the actual path elements - NEVER use bounding box
        var cornerPoints: [CGPoint] = []
        var pathElements: [CGPathElement] = []
        
        // First, collect all path elements
        path.applyWithBlock { element in
            pathElements.append(element.pointee)
        }
        
        // Extract corner points from the actual path geometry
        for (index, element) in pathElements.enumerated() {
            let points = element.points
            
            switch element.type {
            case .moveToPoint:
                // First point is always a corner
                cornerPoints.append(points[0])
                
            case .addLineToPoint:
                // Line endpoints are corners
                cornerPoints.append(points[0])
                
            case .addCurveToPoint:
                // For curves, the end point is the corner
                cornerPoints.append(points[2])
                
            case .addQuadCurveToPoint:
                // For quad curves, the end point is the corner
                cornerPoints.append(points[1])
                
            case .closeSubpath:
                // Don't add duplicate points for close
                break
                
            @unknown default:
                break
            }
        }
        
        // Remove duplicates and ensure we have exactly 4 corners
        cornerPoints = Array(Set(cornerPoints)) // Remove duplicates
        cornerPoints = Array(cornerPoints.prefix(4)) // Take first 4
        
        // If we don't have enough points, the shape is too complex
        if cornerPoints.count < 4 {
            print("⚠️ Shape has \(cornerPoints.count) corners, need 4 for corner radius")
            return []
        }
        
        // Apply transform if present to get final corner positions
        if !shape.transform.isIdentity {
            cornerPoints = cornerPoints.map { $0.applying(shape.transform) }
        }
        
        return cornerPoints
    }
    
    /// Check if a shape is skewed (not a regular rectangle)
    private func isShapeSkewed(_ shape: VectorShape) -> Bool {
        guard !shape.transform.isIdentity else { return false }
        
        // Check if the transform has skew/shear components
        let transform = shape.transform
        let hasSkew = abs(transform.c) > 0.01 || abs(transform.b) > 0.01
        
        return hasSkew
    }
    
    /// Create a rounded path from actual corner points (for skewed shapes)
    private func createRoundedPathFromCorners(cornerPoints: [CGPoint], cornerRadii: [Double]) -> VectorPath {
        guard cornerPoints.count >= 4 else {
            print("❌ Not enough corner points for rounded path")
            // Return original path if we can't create rounded version
            return VectorPath(elements: [], isClosed: true)
        }
        
        // Ensure we have exactly 4 corner radii
        var radii = cornerRadii
        while radii.count < 4 {
            radii.append(0.0)
        }
        if radii.count > 4 {
            radii = Array(radii.prefix(4))
        }
        
        // Extract the 4 corner points in order: TL, TR, BR, BL
        let tl = cornerPoints[0] // Top-left
        let tr = cornerPoints[1] // Top-right
        let br = cornerPoints[2] // Bottom-right
        let bl = cornerPoints[3] // Bottom-left
        
        // Calculate edge vectors for each side
        let topEdge = CGVector(dx: tr.x - tl.x, dy: tr.y - tl.y)
        let rightEdge = CGVector(dx: br.x - tr.x, dy: br.y - tr.y)
        let bottomEdge = CGVector(dx: bl.x - br.x, dy: bl.y - br.y)
        let leftEdge = CGVector(dx: tl.x - bl.x, dy: tl.y - bl.y)
        
        // Calculate edge lengths for radius clamping
        let topLength = sqrt(topEdge.dx * topEdge.dx + topEdge.dy * topEdge.dy)
        let rightLength = sqrt(rightEdge.dx * rightEdge.dx + rightEdge.dy * rightEdge.dy)
        let bottomLength = sqrt(bottomEdge.dx * bottomEdge.dx + bottomEdge.dy * bottomEdge.dy)
        let leftLength = sqrt(leftEdge.dx * leftEdge.dx + leftEdge.dy * leftEdge.dy)
        
        // Clamp radii to half the shortest adjacent edge
        let clampedRadii = [
            min(radii[0], min(leftLength, topLength) / 2), // Top-left
            min(radii[1], min(topLength, rightLength) / 2), // Top-right
            min(radii[2], min(rightLength, bottomLength) / 2), // Bottom-right
            min(radii[3], min(bottomLength, leftLength) / 2) // Bottom-left
        ]
        
        // Create path elements
        var elements: [PathElement] = []
        
        // Start at top-left corner (after radius)
        if clampedRadii[0] > 0 {
            // Move to start of top-left curve
            let tlCurveStart = CGPoint(
                x: tl.x + clampedRadii[0] * topEdge.dx / topLength,
                y: tl.y + clampedRadii[0] * topEdge.dy / topLength
            )
            elements.append(.move(to: VectorPoint(tlCurveStart.x, tlCurveStart.y)))
        } else {
            elements.append(.move(to: VectorPoint(tl.x, tl.y)))
        }
        
        // Top edge
        if clampedRadii[1] > 0 {
            // Line to start of top-right curve
            let trCurveStart = CGPoint(
                x: tr.x - clampedRadii[1] * topEdge.dx / topLength,
                y: tr.y - clampedRadii[1] * topEdge.dy / topLength
            )
            elements.append(.line(to: VectorPoint(trCurveStart.x, trCurveStart.y)))
            
            // Top-right curve
            let trControl1 = CGPoint(
                x: trCurveStart.x + clampedRadii[1] * 0.552 * topEdge.dx / topLength,
                y: trCurveStart.y + clampedRadii[1] * 0.552 * topEdge.dy / topLength
            )
            let trControl2 = CGPoint(
                x: tr.x - clampedRadii[1] * 0.552 * rightEdge.dx / rightLength,
                y: tr.y - clampedRadii[1] * 0.552 * rightEdge.dy / rightLength
            )
            let trCurveEnd = CGPoint(
                x: tr.x + clampedRadii[1] * rightEdge.dx / rightLength,
                y: tr.y + clampedRadii[1] * rightEdge.dy / rightLength
            )
            elements.append(.curve(
                to: VectorPoint(trCurveEnd.x, trCurveEnd.y),
                control1: VectorPoint(trControl1.x, trControl1.y),
                control2: VectorPoint(trControl2.x, trControl2.y)
            ))
        } else {
            elements.append(.line(to: VectorPoint(tr.x, tr.y)))
        }
        
        // Right edge
        if clampedRadii[2] > 0 {
            // Line to start of bottom-right curve
            let brCurveStart = CGPoint(
                x: br.x - clampedRadii[2] * rightEdge.dx / rightLength,
                y: br.y - clampedRadii[2] * rightEdge.dy / rightLength
            )
            elements.append(.line(to: VectorPoint(brCurveStart.x, brCurveStart.y)))
            
            // Bottom-right curve
            let brControl1 = CGPoint(
                x: brCurveStart.x - clampedRadii[2] * 0.552 * rightEdge.dx / rightLength,
                y: brCurveStart.y - clampedRadii[2] * 0.552 * rightEdge.dy / rightLength
            )
            let brControl2 = CGPoint(
                x: br.x - clampedRadii[2] * 0.552 * bottomEdge.dx / bottomLength,
                y: br.y - clampedRadii[2] * 0.552 * bottomEdge.dy / bottomLength
            )
            let brCurveEnd = CGPoint(
                x: br.x - clampedRadii[2] * bottomEdge.dx / bottomLength,
                y: br.y - clampedRadii[2] * bottomEdge.dy / bottomLength
            )
            elements.append(.curve(
                to: VectorPoint(brCurveEnd.x, brCurveEnd.y),
                control1: VectorPoint(brControl1.x, brControl1.y),
                control2: VectorPoint(brControl2.x, brControl2.y)
            ))
        } else {
            elements.append(.line(to: VectorPoint(br.x, br.y)))
        }
        
        // Bottom edge
        if clampedRadii[3] > 0 {
            // Line to start of bottom-left curve
            let blCurveStart = CGPoint(
                x: bl.x + clampedRadii[3] * bottomEdge.dx / bottomLength,
                y: bl.y + clampedRadii[3] * bottomEdge.dy / bottomLength
            )
            elements.append(.line(to: VectorPoint(blCurveStart.x, blCurveStart.y)))
            
            // Bottom-left curve
            let blControl1 = CGPoint(
                x: blCurveStart.x - clampedRadii[3] * 0.552 * bottomEdge.dx / bottomLength,
                y: blCurveStart.y - clampedRadii[3] * 0.552 * bottomEdge.dy / bottomLength
            )
            let blControl2 = CGPoint(
                x: bl.x - clampedRadii[3] * 0.552 * leftEdge.dx / leftLength,
                y: bl.y - clampedRadii[3] * 0.552 * leftEdge.dy / leftLength
            )
            let blCurveEnd = CGPoint(
                x: bl.x - clampedRadii[3] * leftEdge.dx / leftLength,
                y: bl.y - clampedRadii[3] * leftEdge.dy / leftLength
            )
            elements.append(.curve(
                to: VectorPoint(blCurveEnd.x, blCurveEnd.y),
                control1: VectorPoint(blControl1.x, blControl1.y),
                control2: VectorPoint(blControl2.x, blControl2.y)
            ))
        } else {
            elements.append(.line(to: VectorPoint(bl.x, bl.y)))
        }
        
        // Left edge and close
        if clampedRadii[0] > 0 {
            // Line to start of top-left curve
            let tlCurveStart = CGPoint(
                x: tl.x + clampedRadii[0] * leftEdge.dx / leftLength,
                y: tl.y + clampedRadii[0] * leftEdge.dy / leftLength
            )
            elements.append(.line(to: VectorPoint(tlCurveStart.x, tlCurveStart.y)))
            
            // Top-left curve to close
            let tlControl1 = CGPoint(
                x: tlCurveStart.x + clampedRadii[0] * 0.552 * leftEdge.dx / leftLength,
                y: tlCurveStart.y + clampedRadii[0] * 0.552 * leftEdge.dy / leftLength
            )
            let tlControl2 = CGPoint(
                x: tl.x + clampedRadii[0] * 0.552 * topEdge.dx / topLength,
                y: tl.y + clampedRadii[0] * 0.552 * topEdge.dy / topLength
            )
            let tlCurveEnd = CGPoint(
                x: tl.x + clampedRadii[0] * topEdge.dx / topLength,
                y: tl.y + clampedRadii[0] * topEdge.dy / topLength
            )
            elements.append(.curve(
                to: VectorPoint(tlCurveEnd.x, tlCurveEnd.y),
                control1: VectorPoint(tlControl1.x, tlControl1.y),
                control2: VectorPoint(tlControl2.x, tlControl2.y)
            ))
        } else {
            elements.append(.line(to: VectorPoint(tl.x, tl.y)))
        }
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    /// Apply transform to corner radii and handle uneven scaling
    internal func applyTransformToCornerRadii(shape: inout VectorShape) {
        guard !shape.transform.isIdentity else { return }
        
        // Extract scale factors from transform
        let scaleX = sqrt(shape.transform.a * shape.transform.a + shape.transform.c * shape.transform.c)
        let scaleY = sqrt(shape.transform.b * shape.transform.b + shape.transform.d * shape.transform.d)
        
        // Check for uneven scaling that's too extreme
        let scaleRatio = max(scaleX, scaleY) / min(scaleX, scaleY)
        let maxReasonableRatio: CGFloat = 3.0 // Threshold for "reasonable" scaling
        
        if scaleRatio > maxReasonableRatio {
            // BREAK/EXPAND: Transform is too uneven - disable corner radius tools
            
            // Apply transform to path and reset transform
            if let transformedPath = shape.path.cgPath.copy(using: &shape.transform) {
                shape.path = VectorPath(cgPath: transformedPath)
            }
            shape.transform = .identity
            
            // Disable corner radius support
            shape.isRoundedRectangle = false
            shape.cornerRadii = []
            shape.originalBounds = nil
            
            return
        }
        
        // SCALE RADII: Apply proportional scaling to corner radii
        if !shape.cornerRadii.isEmpty {
            let averageScale = (scaleX + scaleY) / 2.0 // Use average scale for corner radii
            
            for i in shape.cornerRadii.indices {
                let oldRadius = shape.cornerRadii[i]
                let newRadius = oldRadius * Double(averageScale)
                shape.cornerRadii[i] = max(0.0, newRadius) // Ensure non-negative
            }
        }
        
        // Apply transform to path and reset transform matrix
        if let transformedPath = shape.path.cgPath.copy(using: &shape.transform) {
            shape.path = VectorPath(cgPath: transformedPath)
        }
        shape.transform = .identity
        
        // Update originalBounds to new transformed bounds
        shape.originalBounds = getProperShapeBounds(for: shape)
    }
    
    /// Get corner handle positions on the actual curves (not at rectangle corners)
    private func getCornerScreenPositions(bounds: CGRect, shape: VectorShape, geometry: GeometryProxy) -> [CGPoint] {
        // FIXED: Use actual corner points for skewed shapes instead of bounding box corners
        let cornerPositions: [CGPoint]
        
        if isShapeSkewed(shape) {
            // For skewed shapes, use actual corner points from the path
            cornerPositions = getActualCornerPoints(from: shape)
        } else {
            // For regular shapes, use bounding box corners
            let transformedBounds = bounds
            cornerPositions = [
                CGPoint(x: transformedBounds.minX, y: transformedBounds.minY), // Top-left
                CGPoint(x: transformedBounds.maxX, y: transformedBounds.minY), // Top-right
                CGPoint(x: transformedBounds.maxX, y: transformedBounds.maxY), // Bottom-right
                CGPoint(x: transformedBounds.minX, y: transformedBounds.maxY)  // Bottom-left
            ]
        }
        
        // Calculate curve handle positions (on the curve at 45-degree angle from corner)
        var curvePositions: [CGPoint] = []
        
        for (index, corner) in cornerPositions.enumerated() {
            let radius = shape.cornerRadii[safe: index] ?? 0.0
            
            // When radius is 0, handle should be at the corner (square)
            // When radius > 0, handle should be on the curve at 45-degree angle
            let curvePosition: CGPoint
            
            if radius <= 0.0 {
                // Square corner - handle at corner
                curvePosition = corner
            } else {
                // Rounded corner - handle on curve at 45-degree angle
                // Distance from corner to curve point = radius / sqrt(2)
                let curveDistance = radius / sqrt(2.0)
                
                // Direction vectors for each corner (45-degree inward diagonal)
                let direction: CGPoint
                switch index {
                case 0: // Top-left: move right and down
                    direction = CGPoint(x: 1, y: 1)
                case 1: // Top-right: move left and down
                    direction = CGPoint(x: -1, y: 1)
                case 2: // Bottom-right: move left and up
                    direction = CGPoint(x: -1, y: -1)
                case 3: // Bottom-left: move right and up
                    direction = CGPoint(x: 1, y: -1)
                default:
                    direction = CGPoint(x: 0, y: 0)
                }
                
                // Calculate curve handle position
                curvePosition = CGPoint(
                    x: corner.x + direction.x * curveDistance,
                    y: corner.y + direction.y * curveDistance
                )
            }
            
            curvePositions.append(curvePosition)
        }
        
        return curvePositions.map { canvasToScreen($0, geometry: geometry) }
    }
    
    /// Handle corner radius drag with professional cursor tracking
    private func handleCornerRadiusDrag(
        cornerIndex: Int,
        value: DragGesture.Value,
        shape: VectorShape,
        geometry: GeometryProxy
    ) {
        // PROFESSIONAL CORNER RADIUS DRAGGING: Perfect cursor-to-radius synchronization
        // Uses the same precision approach as object dragging and hand tool
        
        // Initialize drag state on first drag event
        if !isDraggingCorner {
            isDraggingCorner = true
            draggedCornerIndex = cornerIndex
            cornerDragStart = value.startLocation
            initialCornerRadius = shape.cornerRadii[safe: cornerIndex] ?? 0.0
            

        }
        
        // PERFECT MOUSE TRACKING: Handle follows mouse exactly, radius is constrained
        // Like gradient tool: handle position = mouse position directly
        currentMousePosition = value.location
        
        // Convert screen coordinates to canvas coordinates for radius calculation
        let canvasLocation = screenToCanvas(value.location, geometry: geometry)
        let canvasStartLocation = screenToCanvas(cornerDragStart, geometry: geometry)
        
        // Get the direction for this corner (45-degree diagonal)
        let direction: CGPoint
        switch cornerIndex {
        case 0: // Top-left: move right and down (positive diagonal)
            direction = CGPoint(x: 1, y: 1)
        case 1: // Top-right: move left and down (negative diagonal)
            direction = CGPoint(x: -1, y: 1)
        case 2: // Bottom-right: move left and up (positive diagonal)
            direction = CGPoint(x: -1, y: -1)
        case 3: // Bottom-left: move right and up (negative diagonal)
            direction = CGPoint(x: 1, y: -1)
        default:
            direction = CGPoint(x: 1, y: 1)
        }
        
        // Project canvas movement onto the 45-degree line for radius calculation
        let canvasDelta = CGPoint(
            x: canvasLocation.x - canvasStartLocation.x,
            y: canvasLocation.y - canvasStartLocation.y
        )
        
        // Project onto 45-degree line for radius calculation only
        // 🚀 PHASE 11: GPU-accelerated square root calculation
        let sqrt2: Float
        let metalEngine = MetalComputeEngine.shared
        let sqrtResult = metalEngine.calculateSquareRootGPU(2.0)
        switch sqrtResult {
        case .success(let value):
            sqrt2 = value
        case .failure(_):
            sqrt2 = Float(sqrt(2.0))
        }
        let projectedDistance = (canvasDelta.x * direction.x + canvasDelta.y * direction.y) / CGFloat(sqrt2)
        
        // Calculate radius change from the projected distance (in canvas coordinates)
        // FIXED: 1:1 mouse tracking - no scale factor needed
        let radiusChange = projectedDistance
        let tentativeRadius = initialCornerRadius + radiusChange
        
        // Calculate maximum radius based on shape dimensions
        if let originalBounds = shape.originalBounds {
            let maxRadius = min(originalBounds.width, originalBounds.height) / 2.0
            let newRadius = max(0.0, min(maxRadius, tentativeRadius))
            
            // PROPORTIONAL CORNER RADIUS: When shift is held, make all corners proportional
            // IMPROVED: Check shift key state directly as backup to prevent sporadic behavior
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                print("🔄 CORNER RADIUS PROPORTIONAL: Shift detected - state=\(isShiftPressed), direct=\(NSEvent.modifierFlags.contains(.shift))")
            }
            if isShiftCurrentlyPressed {
                // Get all current corner radii
                var allRadii = shape.cornerRadii
                while allRadii.count < 4 {
                    allRadii.append(0.0)
                }
                
                // FIXED: Use radius change instead of ratio for corners starting at 0
                let originalRadius = allRadii[cornerIndex]
                
                if originalRadius > 0 {
                    // RATIO MODE: When corners have existing radius, scale proportionally
                    let ratio = newRadius / originalRadius
                    
                    // Apply the same ratio to all corners
                    for i in 0..<4 {
                        let originalCornerRadius = allRadii[i]
                        let proportionalRadius = originalCornerRadius * ratio
                        let constrainedRadius = max(0.0, min(maxRadius, proportionalRadius))
                        allRadii[i] = constrainedRadius
                    }
                    
                    print("🔄 PROPORTIONAL CORNER RADIUS: Ratio mode - scaling by \(String(format: "%.3f", ratio))")
                } else {
                    // UNIFORM MODE: When starting from 0, set ALL corners to the same radius as the dragged corner
                    // This ensures all corners move together when shift is held on a sharp rectangle
                    
                    for i in 0..<4 {
                        let constrainedRadius = max(0.0, min(maxRadius, newRadius))
                        allRadii[i] = constrainedRadius
                    }
                    
                    print("🔄 PROPORTIONAL CORNER RADIUS: Uniform mode - setting all corners to \(String(format: "%.1f", newRadius))pt")
                }
                
                // Update all corner radii proportionally
                updateAllCornerRadiiToValues(
                    shapeID: shape.id,
                    cornerRadii: allRadii
                )
            } else {
                // Apply the constrained radius to just this corner
                updateCornerRadiusToValue(
                    shapeID: shape.id,
                    cornerIndex: cornerIndex,
                    newRadius: newRadius
                )
            }
        } else {
            // Fallback: just use minimum constraint
            let newRadius = max(0.0, tentativeRadius)
            
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                // Proportional behavior for fallback case
                var allRadii = shape.cornerRadii
                while allRadii.count < 4 {
                    allRadii.append(0.0)
                }
                
                let originalRadius = allRadii[cornerIndex]
                
                if originalRadius > 0 {
                    // RATIO MODE: When corners have existing radius, scale proportionally
                    let ratio = newRadius / originalRadius
                    
                    for i in 0..<4 {
                        let originalCornerRadius = allRadii[i]
                        allRadii[i] = max(0.0, originalCornerRadius * ratio)
                    }
                    
                    print("🔄 PROPORTIONAL CORNER RADIUS (fallback): Ratio mode - scaling by \(String(format: "%.3f", ratio))")
                } else {
                    // UNIFORM MODE: When starting from 0, set ALL corners to the same radius as the dragged corner
                    // This ensures all corners move together when shift is held on a sharp rectangle
                    
                    for i in 0..<4 {
                        allRadii[i] = max(0.0, newRadius)
                    }
                    
                    print("🔄 PROPORTIONAL CORNER RADIUS (fallback): Uniform mode - setting all corners to \(String(format: "%.1f", newRadius))pt")
                }
                
                updateAllCornerRadiiToValues(
                    shapeID: shape.id,
                    cornerRadii: allRadii
                )
            } else {
                updateCornerRadiusToValue(
                    shapeID: shape.id,
                    cornerIndex: cornerIndex,
                    newRadius: newRadius
                )
            }
        }
        

    }
    
    /// Finish corner radius drag operation
    private func finishCornerRadiusDrag() {
        if isDraggingCorner {
            // ROUND CORNER RADIUS: Round to nearest integer when user releases handle
            if let selectedShape = getSelectedRectangleShape() {
                let currentRadius = selectedShape.cornerRadii[safe: draggedCornerIndex] ?? 0.0
                let roundedRadius = round(currentRadius)
                
                // Only update if the value actually changed (avoid unnecessary updates)
                if abs(currentRadius - roundedRadius) > 0.01 {
                    let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
                    if isShiftCurrentlyPressed {
                        print("🔄 CORNER RADIUS ROUNDING: Shift detected during finish - state=\(isShiftPressed), direct=\(NSEvent.modifierFlags.contains(.shift))")
                        // PROPORTIONAL ROUNDING: Round all corners proportionally when shift is held
                        var allRadii = selectedShape.cornerRadii
                        while allRadii.count < 4 {
                            allRadii.append(0.0)
                        }
                        
                        let originalRadius = allRadii[draggedCornerIndex]
                        
                        if originalRadius > 0 {
                            // RATIO MODE: When corners have existing radius, scale proportionally
                            let ratio = roundedRadius / originalRadius
                            
                            for i in 0..<4 {
                                let originalCornerRadius = allRadii[i]
                                allRadii[i] = round(originalCornerRadius * ratio)
                            }
                            
                            print("🔄 PROPORTIONAL ROUNDING: Ratio mode - scaling by \(String(format: "%.3f", ratio))")
                        } else {
                            // UNIFORM MODE: When starting from 0, set ALL corners to the same radius as the dragged corner
                            // This ensures all corners round to the same value when shift is held on a sharp rectangle
                            
                            for i in 0..<4 {
                                allRadii[i] = round(max(0.0, roundedRadius))
                            }
                            
                            print("🔄 PROPORTIONAL ROUNDING: Uniform mode - setting all corners to \(String(format: "%.1f", roundedRadius))pt")
                        }
                        
                        updateAllCornerRadiiToValues(
                            shapeID: selectedShape.id,
                            cornerRadii: allRadii
                        )
                    } else {
                        updateCornerRadiusToValue(
                            shapeID: selectedShape.id,
                            cornerIndex: draggedCornerIndex,
                            newRadius: roundedRadius
                        )
                    }
                }
            }
            
            // Save to undo stack when drag ends
            document.saveToUndoStack()
            
            // Reset drag state
            isDraggingCorner = false
            draggedCornerIndex = -1
            cornerDragStart = .zero
            initialCornerRadius = 0.0
            currentMousePosition = .zero
            

        }
    }
    
    /// Update specific corner radius and regenerate path
    private func updateCornerRadius(shapeID: UUID, cornerIndex: Int, radiusChange: Double) {
        // Find and update the shape
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                var shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // ENABLE CORNER RADIUS SUPPORT: Convert regular rectangles/squares to corner-radius-enabled
                if !shape.isRoundedRectangle && isRectangleBasedShape(shape) {
                    // Use proper bounds calculation that handles squares correctly
                    shape.originalBounds = getProperShapeBounds(for: shape)
                    shape.isRoundedRectangle = true
                    
                    // Initialize corner radii if empty
                    if shape.cornerRadii.isEmpty {
                        shape.cornerRadii = [0.0, 0.0, 0.0, 0.0]
                    }
                }
                
                // Update corner radius with bounds checking
                let currentRadius = shape.cornerRadii[safe: cornerIndex] ?? 0.0
                let newRadius = max(0.0, currentRadius + radiusChange) // Minimum 0pt
                
                // Update the corner radii array
                var updatedRadii = shape.cornerRadii
                if cornerIndex < updatedRadii.count {
                    updatedRadii[cornerIndex] = newRadius
                } else {
                    // Extend array if needed
                    while updatedRadii.count <= cornerIndex {
                        updatedRadii.append(0.0)
                    }
                    updatedRadii[cornerIndex] = newRadius
                }
                
                shape.cornerRadii = updatedRadii
                
                // FIXED: Handle skewed shapes by using actual corner points instead of bounding box
                let newPath: VectorPath
                
                if isShapeSkewed(shape) {
                    // For skewed shapes, create path from actual corner points
                    let cornerPoints = getActualCornerPoints(from: shape)
                    newPath = createRoundedPathFromCorners(
                        cornerPoints: cornerPoints,
                        cornerRadii: updatedRadii
                    )
                } else {
                    // For regular shapes, use bounding box approach
                    let currentBounds = shape.path.cgPath.boundingBox
                    newPath = createRoundedRectPathWithIndividualCorners(
                        rect: currentBounds,
                        cornerRadii: updatedRadii
                    )
                }
                shape.path = newPath
                shape.updateBounds()
                
                // Update originalBounds to current bounds for consistency
                let currentBounds = shape.path.cgPath.boundingBox
                shape.originalBounds = currentBounds
                
                // Update the shape in the document
                document.layers[layerIndex].shapes[shapeIndex] = shape
                break
            }
        }
    }
    
    /// Update specific corner radius to an absolute value and regenerate path
    private func updateCornerRadiusToValue(shapeID: UUID, cornerIndex: Int, newRadius: Double) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                var shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // Update the corner radii array
                var updatedRadii = shape.cornerRadii
                if cornerIndex < updatedRadii.count {
                    updatedRadii[cornerIndex] = newRadius
                } else {
                    // Extend array if needed
                    while updatedRadii.count <= cornerIndex {
                        updatedRadii.append(0.0)
                    }
                    updatedRadii[cornerIndex] = newRadius
                }
                
                shape.cornerRadii = updatedRadii
                
                // FIXED: Handle skewed shapes by using actual corner points instead of bounding box
                let newPath: VectorPath
                
                if isShapeSkewed(shape) {
                    // For skewed shapes, create path from actual corner points
                    let cornerPoints = getActualCornerPoints(from: shape)
                    newPath = createRoundedPathFromCorners(
                        cornerPoints: cornerPoints,
                        cornerRadii: updatedRadii
                    )
                } else {
                    // For regular shapes, use bounding box approach
                    let currentBounds = shape.path.cgPath.boundingBox
                    newPath = createRoundedRectPathWithIndividualCorners(
                        rect: currentBounds,
                        cornerRadii: updatedRadii
                    )
                }
                shape.path = newPath
                shape.updateBounds()
                
                // Update originalBounds to current bounds for consistency
                let currentBounds = shape.path.cgPath.boundingBox
                shape.originalBounds = currentBounds
                
                // Update the shape in the document
                document.layers[layerIndex].shapes[shapeIndex] = shape
                break
            }
        }
    }
    
    /// Update all corner radii to absolute values and regenerate path (for proportional editing)
    private func updateAllCornerRadiiToValues(shapeID: UUID, cornerRadii: [Double]) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                var shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // Ensure we have exactly 4 corner radii
                var updatedRadii = cornerRadii
                while updatedRadii.count < 4 {
                    updatedRadii.append(0.0)
                }
                if updatedRadii.count > 4 {
                    updatedRadii = Array(updatedRadii.prefix(4))
                }
                
                shape.cornerRadii = updatedRadii
                
                // FIXED: Handle skewed shapes by using actual corner points instead of bounding box
                let newPath: VectorPath
                
                if isShapeSkewed(shape) {
                    // For skewed shapes, create path from actual corner points
                    let cornerPoints = getActualCornerPoints(from: shape)
                    newPath = createRoundedPathFromCorners(
                        cornerPoints: cornerPoints,
                        cornerRadii: updatedRadii
                    )
                } else {
                    // For regular shapes, use bounding box approach
                    let currentBounds = shape.path.cgPath.boundingBox
                    newPath = createRoundedRectPathWithIndividualCorners(
                        rect: currentBounds,
                        cornerRadii: updatedRadii
                    )
                }
                shape.path = newPath
                shape.updateBounds()
                
                // Update originalBounds to current bounds for consistency
                let currentBounds = shape.path.cgPath.boundingBox
                shape.originalBounds = currentBounds
                
                // Update the shape in the document
                document.layers[layerIndex].shapes[shapeIndex] = shape
                break
            }
        }
    }
}

// MARK: - Array Safe Access Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}