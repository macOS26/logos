//
//  DrawingCanvas+ShapeDrawing.swift
//  logos inkpen.io
//
//  Shape drawing functionality
//

import SwiftUI

extension DrawingCanvas {
    // Helper function to handle GPU distance calculation with fallback
    private func calculateDistanceWithFallback(from point1: CGPoint, to point2: CGPoint) -> Float {
        let metalEngine = MetalComputeEngine.shared
        let distanceResult = metalEngine.calculatePointDistanceGPU(from: point1, to: point2)
        switch distanceResult {
        case .success(let distance):
            return distance
        case .failure(_):
            // CPU fallback
            let dx = point2.x - point1.x
            let dy = point2.y - point1.y
            return Float(sqrt(dx * dx + dy * dy))
        }
    }
    
    internal func handleShapeDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        // PROFESSIONAL SHAPE DRAWING: Perfect cursor-to-shape synchronization
        // Uses the same precision approach as hand tool and object dragging
        // This eliminates floating-point accumulation errors from DragGesture.translation
        
        // CRITICAL FIX: Shape tools should only work on DRAG, not click
        // Calculate actual drag distance to distinguish click vs drag
        // 🚀 PHASE 11: GPU-accelerated distance calculation
        let dragDistance = calculateDistanceWithFallback(from: value.startLocation, to: value.location)
        
        // All geometric shapes: allow drawing from 0×0 without any minimum distance
        // This controls how small the object can be at creation (not a drag threshold)
        let minimumDragThreshold: Double = 0.0
        
        // Only proceed with shape creation if user has dragged significantly
        if Double(dragDistance) < minimumDragThreshold {
            Log.info("🎨 SHAPE TOOL: Drag distance (\(String(format: "%.1f", dragDistance))px) below threshold - CLICK IGNORED (shapes are drag-only)", category: .shapes)
            return
        }
        
        if !isDrawing {
            // CRITICAL: Only initialize state once per drag operation
            isDrawing = true
            
            // Capture reference cursor position (like hand tool)
            shapeDragStart = value.startLocation
            
            // Convert to canvas coordinates for initial position
            shapeStartPoint = screenToCanvas(value.startLocation, geometry: geometry)
            drawingStartPoint = shapeStartPoint
            
            Log.info("🎨 SHAPE DRAWING: Started at cursor position (\(String(format: "%.1f", shapeDragStart.x)), \(String(format: "%.1f", shapeDragStart.y)))", category: .shapes)
            Log.info("🎨 SHAPE TOOL: Drag distance (\(String(format: "%.1f", dragDistance))px) above threshold - starting shape creation", category: .shapes)
        }
        
        // Calculate cursor movement from reference location (perfect 1:1 tracking)
        let cursorDelta = CGPoint(
            x: value.location.x - shapeDragStart.x,
            y: value.location.y - shapeDragStart.y
        )
        
        // Convert screen delta to canvas delta (accounting for zoom)
        let preciseZoom = Double(document.zoomLevel)
        let canvasDelta = CGPoint(
            x: cursorDelta.x / preciseZoom,
            y: cursorDelta.y / preciseZoom
        )
        
        // Calculate current location based on initial position + cursor delta
        let currentLocation = CGPoint(
            x: shapeStartPoint.x + canvasDelta.x,
            y: shapeStartPoint.y + canvasDelta.y
        )
        
        // Professional verification logging (only for significant movements)
        if abs(canvasDelta.x) > 2 || abs(canvasDelta.y) > 2 {
            // Perfect sync maintained - canvas delta tracking
        }
        
        guard let startPoint = drawingStartPoint else { return }
        
        // Create preview path based on tool
        switch document.currentTool {
        case .line:
            currentPath = VectorPath(elements: [
                .move(to: VectorPoint(startPoint)),
                .line(to: VectorPoint(currentLocation))
            ])
        case .rectangle:
            // Rectangle aligned to cursor with pixel-precise edges
            var minX = min(startPoint.x, currentLocation.x)
            var maxX = max(startPoint.x, currentLocation.x)
            var minY = min(startPoint.y, currentLocation.y)
            var maxY = max(startPoint.y, currentLocation.y)

            // Shift the edge under the cursor inward by half a screen pixel (in canvas units)
            let halfPixelInCanvas = 0.5 / document.zoomLevel
            if currentLocation.x >= startPoint.x {
                maxX -= halfPixelInCanvas
            } else {
                minX += halfPixelInCanvas
            }
            if currentLocation.y >= startPoint.y {
                maxY -= halfPixelInCanvas
            } else {
                minY += halfPixelInCanvas
            }

            currentPath = VectorPath(elements: [
                .move(to: VectorPoint(minX, minY)),
                .line(to: VectorPoint(maxX, minY)),
                .line(to: VectorPoint(maxX, maxY)),
                .line(to: VectorPoint(minX, maxY)),
                .close
            ], isClosed: true)
        case .square:
            // FIXED: Pin square from exact start point and grow square in direction of cursor movement
            // This ensures consistent behavior with rectangle tool - top-left corner stays pinned
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            
            // Use the larger absolute delta to maintain square proportions while following cursor direction
            let size = max(abs(dragDeltaX), abs(dragDeltaY))
            
            // Create square that grows from startPoint in the direction of cursor movement
            let squareRect = CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: dragDeltaX >= 0 ? size : -size,
                height: dragDeltaY >= 0 ? size : -size
            )
            currentPath = VectorPath(elements: [
                .move(to: VectorPoint(squareRect.minX, squareRect.minY)),
                .line(to: VectorPoint(squareRect.maxX, squareRect.minY)),
                .line(to: VectorPoint(squareRect.maxX, squareRect.maxY)),
                .line(to: VectorPoint(squareRect.minX, squareRect.maxY)),
                .close
            ], isClosed: true)
        case .roundedRectangle:
            // FIXED: Pin rounded rectangle from start point like rectangle tool
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            let rect = CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: dragDeltaX,
                height: dragDeltaY
            )
            let normalizedRect = CGRect(
                x: min(rect.minX, rect.maxX),
                y: min(rect.minY, rect.maxY),
                width: abs(rect.width),
                height: abs(rect.height)
            )
            // Use 20pt radius for drawing preview (matches creation default)
            let cornerRadius: Double = 20.0
            currentPath = createRoundedRectPath(rect: normalizedRect, cornerRadius: cornerRadius)
        case .pill:
            // FIXED: Pin pill from start point like rectangle tool
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            let rect = CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: dragDeltaX,
                height: dragDeltaY
            )
            let normalizedRect = CGRect(
                x: min(rect.minX, rect.maxX),
                y: min(rect.minY, rect.maxY),
                width: abs(rect.width),
                height: abs(rect.height)
            )
            let cornerRadius = min(normalizedRect.width, normalizedRect.height) / 2 // Half of smallest dimension
            currentPath = createRoundedRectPath(rect: normalizedRect, cornerRadius: cornerRadius)
        case .circle:
            // FIXED: Pin circle from start point like rectangle tool
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            let rect = CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: dragDeltaX,
                height: dragDeltaY
            )
            currentPath = createCirclePath(rect: rect)
        case .ellipse:
            // FIXED: Pin ellipse from start point like rectangle tool
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            let rect = CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: dragDeltaX,
                height: dragDeltaY
            )
            currentPath = createEllipsePath(rect: rect)
        case .oval:
            // FIXED: Pin oval from start point like rectangle tool
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            let rect = CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: dragDeltaX,
                height: dragDeltaY
            )
            // Normalize the rectangle to ensure proper oval construction
            let normalizedRect = CGRect(
                x: min(rect.minX, rect.maxX),
                y: min(rect.minY, rect.maxY),
                width: abs(rect.width),
                height: abs(rect.height)
            )
            // Use the new oval path function that creates a true oval using circular arcs
            currentPath = createOvalPath(rect: normalizedRect)
        case .egg:
            // FIXED: Pin egg from start point like rectangle tool
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            let rect = CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: dragDeltaX,
                height: dragDeltaY
            )
            // Normalize the rectangle to ensure proper egg construction
            let normalizedRect = CGRect(
                x: min(rect.minX, rect.maxX),
                y: min(rect.minY, rect.maxY),
                width: abs(rect.width),
                height: abs(rect.height)
            )
            // Use the egg path function that creates a true egg shape
            currentPath = createEggPath(rect: normalizedRect)
        case .equilateralTriangle:
            // FIXED: Use square tool's pinning approach to prevent drift + make truly equilateral
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            
            // Use the larger absolute delta to maintain equilateral proportions
            let size = max(abs(dragDeltaX), abs(dragDeltaY))
            
            // Create equilateral triangle that grows from startPoint in direction of cursor
            // For equilateral triangle: height = side * sqrt(3)/2, so side = height * 2/sqrt(3)
            let triangleHeight = dragDeltaY >= 0 ? size : -size
            // 🚀 PHASE 11: GPU-accelerated square root calculation
            let sqrt3: Float
            let metalEngine = MetalComputeEngine.shared
            let sqrtResult = metalEngine.calculateSquareRootGPU(3.0)
            switch sqrtResult {
            case .success(let value):
                sqrt3 = value
            case .failure(_):
                sqrt3 = Float(sqrt(3.0))
            }
            let triangleWidth = CGFloat(abs(triangleHeight) * 2.0 / Double(sqrt3)) // Convert height to equilateral base width
            
            // Pin triangle from start point (upper left corner of bounding box)
            let triangleRect = CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: dragDeltaX >= 0 ? triangleWidth : -triangleWidth,
                height: triangleHeight
            )
            
            // Create true equilateral triangle with equal side lengths
            let centerX = triangleRect.midX
            let topY = triangleRect.minY
            let bottomY = triangleRect.maxY
            let baseHalfWidth = triangleWidth / 2.0
            
            currentPath = VectorPath(elements: [
                .move(to: VectorPoint(centerX, topY)),
                .line(to: VectorPoint(centerX - baseHalfWidth, bottomY)),
                .line(to: VectorPoint(centerX + baseHalfWidth, bottomY)),
                .close
            ], isClosed: true)
            
            // DEBUG: Add visual bounding box to verify no drift (pin upper left corner)
            let boundingBox = VectorPath(elements: [
                .move(to: VectorPoint(triangleRect.minX, triangleRect.minY)),
                .line(to: VectorPoint(triangleRect.maxX, triangleRect.minY)),
                .line(to: VectorPoint(triangleRect.maxX, triangleRect.maxY)),
                .line(to: VectorPoint(triangleRect.minX, triangleRect.maxY)),
                .close
            ], isClosed: false)
            
            // Store bounding box for visual verification (temporary debug feature)
            tempBoundingBoxPath = boundingBox
        case .rightTriangle:
            // Use rectangle pattern to avoid Y inversion issues
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            // Determine orientation based on BOTH X and Y directions
            let dragX = currentLocation.x >= startPoint.x ? "RIGHT" : "LEFT"
            let dragY = currentLocation.y >= startPoint.y ? "DOWN" : "UP"
            let dragDirection = "\(dragX)_\(dragY)"
            
            currentPath = createRightTrianglePath(rect: rect, dragDirection: dragDirection)
        case .acuteTriangle:
            // FIXED: Pin triangle from start point like rectangle tool
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            let rect = CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: dragDeltaX,
                height: dragDeltaY
            )
            currentPath = createAcuteTrianglePath(rect: rect)
        case .isoscelesTriangle:
            // FIXED: Pin triangle from start point like rectangle tool
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            let rect = CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: dragDeltaX,
                height: dragDeltaY
            )
            currentPath = createIsoscelesTrianglePath(rect: rect)
        case .cone:
            // Build cone using reference proportions from coneshape.inkpen.json
            let dx = currentLocation.x - startPoint.x
            let dy = currentLocation.y - startPoint.y
            let raw = CGRect(x: startPoint.x, y: startPoint.y, width: dx, height: dy)
            let r = CGRect(x: min(raw.minX, raw.maxX), y: min(raw.minY, raw.maxY), width: abs(raw.width), height: abs(raw.height))

            let apex = VectorPoint(r.midX, r.minY)
            let baseLeft = VectorPoint(r.minX, r.maxY)
            let baseRight = VectorPoint(r.maxX, r.maxY)

            let move = VectorPoint(baseRight.x - r.width * 0.007461, baseRight.y - r.height * 0.13586)
            let c1 = VectorPoint(baseRight.x - r.width * 0.002364, baseRight.y - r.height * 0.12957)
            let c2 = VectorPoint(baseRight.x, baseRight.y - r.height * 0.12317)
            let rightStart = VectorPoint(baseRight.x, baseRight.y - r.height * 0.11645)

            let c3 = VectorPoint(baseRight.x, baseRight.y - r.height * 0.05216)
            let c4 = VectorPoint(r.midX + r.width * 0.27608, r.maxY)
            let mid = VectorPoint(r.midX, r.maxY)

            let c5 = VectorPoint(r.midX - r.width * 0.27608, r.maxY)
            let c6 = VectorPoint(baseLeft.x, baseLeft.y - r.height * 0.05216)
            let leftEnd = VectorPoint(baseLeft.x, baseLeft.y - r.height * 0.11645)

            let c7 = VectorPoint(baseLeft.x, baseLeft.y - r.height * 0.12160)
            let c8 = VectorPoint(baseLeft.x + r.width * 0.00141, baseLeft.y - r.height * 0.12660)
            let leftExit = VectorPoint(baseLeft.x + r.width * 0.00463, baseLeft.y - r.height * 0.13147)

            currentPath = VectorPath(elements: [
                .move(to: move),
                .curve(to: rightStart, control1: c1, control2: c2),
                .curve(to: mid, control1: c3, control2: c4),
                .curve(to: leftEnd, control1: c5, control2: c6),
                .curve(to: leftExit, control1: c7, control2: c8),
                .line(to: apex),
                .close
            ], isClosed: true)
        case .star:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            // 🚀 PHASE 12: GPU-accelerated distance calculation for radius
            let outerRadius = calculateDistanceWithFallback(from: startPoint, to: currentLocation) / 2.0
            // Determine star points and inner radius ratio based on selected variant in tool group
            let selectedVariant = ToolGroupManager.shared.selectedVariant
            let points: Int
            let innerRatio: Double
            switch selectedVariant {
            case .threePoint:
                points = 3
                innerRatio = 0.22 // narrower inner points
            case .fourPoint:
                points = 4
                innerRatio = 0.28 // narrower inner points
            case .fivePoint:
                points = 5
                innerRatio = 0.40
            case .sixPoint:
                points = 6
                innerRatio = 0.40
            case .sevenPoint:
                points = 7
                innerRatio = 0.40
            }
            let innerRadius = Double(outerRadius) * innerRatio
            currentPath = createStarPath(center: center, outerRadius: Double(outerRadius), innerRadius: innerRadius, points: points)
		case .polygon:
			// Pin from start like rectangle/square and use a square bounds to keep the polygon regular
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let rect = CGRect(
				x: startPoint.x,
				y: startPoint.y,
				width: dragDeltaX >= 0 ? size : -size,
				height: dragDeltaY >= 0 ? size : -size
			)
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			currentPath = createPolygonPath(center: center, radius: radius, sides: 6) // Default hexagon
			let boundingBox = VectorPath(elements: [
				.move(to: VectorPoint(normalizedRect.minX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.maxY)),
				.line(to: VectorPoint(normalizedRect.minX, normalizedRect.maxY)),
				.close
			], isClosed: false)
			tempBoundingBoxPath = boundingBox
		case .pentagon:
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let rect = CGRect(
				x: startPoint.x,
				y: startPoint.y,
				width: dragDeltaX >= 0 ? size : -size,
				height: dragDeltaY >= 0 ? size : -size
			)
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			currentPath = createPolygonPath(center: center, radius: radius, sides: 5)
			let boundingBox = VectorPath(elements: [
				.move(to: VectorPoint(normalizedRect.minX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.maxY)),
				.line(to: VectorPoint(normalizedRect.minX, normalizedRect.maxY)),
				.close
			], isClosed: false)
			tempBoundingBoxPath = boundingBox
		case .hexagon:
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let rect = CGRect(
				x: startPoint.x,
				y: startPoint.y,
				width: dragDeltaX >= 0 ? size : -size,
				height: dragDeltaY >= 0 ? size : -size
			)
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			currentPath = createPolygonPath(center: center, radius: radius, sides: 6)
			let boundingBox = VectorPath(elements: [
				.move(to: VectorPoint(normalizedRect.minX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.maxY)),
				.line(to: VectorPoint(normalizedRect.minX, normalizedRect.maxY)),
				.close
			], isClosed: false)
			tempBoundingBoxPath = boundingBox
		case .heptagon:
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let rect = CGRect(
				x: startPoint.x,
				y: startPoint.y,
				width: dragDeltaX >= 0 ? size : -size,
				height: dragDeltaY >= 0 ? size : -size
			)
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			currentPath = createPolygonPath(center: center, radius: radius, sides: 7)
			let boundingBox = VectorPath(elements: [
				.move(to: VectorPoint(normalizedRect.minX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.maxY)),
				.line(to: VectorPoint(normalizedRect.minX, normalizedRect.maxY)),
				.close
			], isClosed: false)
			tempBoundingBoxPath = boundingBox
		case .octagon:
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let rect = CGRect(
				x: startPoint.x,
				y: startPoint.y,
				width: dragDeltaX >= 0 ? size : -size,
				height: dragDeltaY >= 0 ? size : -size
			)
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			currentPath = createPolygonPath(center: center, radius: radius, sides: 8)
			let boundingBox = VectorPath(elements: [
				.move(to: VectorPoint(normalizedRect.minX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.maxY)),
				.line(to: VectorPoint(normalizedRect.minX, normalizedRect.maxY)),
				.close
			], isClosed: false)
			tempBoundingBoxPath = boundingBox
		case .nonagon:
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let rect = CGRect(
				x: startPoint.x,
				y: startPoint.y,
				width: dragDeltaX >= 0 ? size : -size,
				height: dragDeltaY >= 0 ? size : -size
			)
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			currentPath = createPolygonPath(center: center, radius: radius, sides: 9)
			let boundingBox = VectorPath(elements: [
				.move(to: VectorPoint(normalizedRect.minX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.minY)),
				.line(to: VectorPoint(normalizedRect.maxX, normalizedRect.maxY)),
				.line(to: VectorPoint(normalizedRect.minX, normalizedRect.maxY)),
				.close
			], isClosed: false)
			tempBoundingBoxPath = boundingBox
        default:
            break
        }
    }
    
    internal func finishShapeDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let path = currentPath else { return }
        
        // FIXED: Use document's default colors instead of hardcoded values!
        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: document.defaultStrokeWidth, // Use user's default stroke width
            lineCap: document.defaultStrokeLineCap, // Use user's default line cap
            lineJoin: document.defaultStrokeLineJoin, // Use user's default line join
            miterLimit: document.defaultStrokeMiterLimit, // Use user's default miter limit
            opacity: document.defaultStrokeOpacity  // 100% opacity by default
        )
        let fillStyle = FillStyle(
            color: document.defaultFillColor,
            opacity: document.defaultFillOpacity  // 100% opacity by default
        )
        
        // CORNER RADIUS SUPPORT: Enable for all rectangle-based shapes
        if document.currentTool == .rectangle || document.currentTool == .square || 
           document.currentTool == .roundedRectangle || document.currentTool == .pill {
            
            // Calculate original bounds from drawing coordinates
            let startPoint = shapeStartPoint
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            
            // FIXED: For squares, use square bounds not rectangular drag bounds
            let originalBounds: CGRect
            if document.currentTool == .square {
                // For squares, calculate proper square bounds to match the actual path
                let dragDeltaX = currentLocation.x - startPoint.x
                let dragDeltaY = currentLocation.y - startPoint.y
                let size = max(abs(dragDeltaX), abs(dragDeltaY))
                
                originalBounds = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: dragDeltaX >= 0 ? size : -size,
                    height: dragDeltaY >= 0 ? size : -size
                )
                Log.info("🔍 SQUARE CREATION: Square originalBounds: \(originalBounds)", category: .general)
            } else {
                // For rectangles and other shapes, use rectangular drag bounds
                originalBounds = CGRect(
                    x: min(startPoint.x, currentLocation.x),
                    y: min(startPoint.y, currentLocation.y),
                    width: abs(currentLocation.x - startPoint.x),
                    height: abs(currentLocation.y - startPoint.y)
                )
            }
            
            // Set initial corner radius based on shape type
            let initialRadius: Double
            let cornerRadii: [Double]
            
            switch document.currentTool {
            case .rectangle, .square:
                // Regular rectangles start with 0 radius (sharp corners)
                initialRadius = 0.0
                cornerRadii = [0.0, 0.0, 0.0, 0.0]
            case .roundedRectangle:
                // Rounded rectangles start with 20pt radius
                initialRadius = 20.0
                cornerRadii = [initialRadius, initialRadius, initialRadius, initialRadius]
            case .pill:
                // Pills start with maximum radius (half of smallest dimension)
                let maxRadius = min(originalBounds.width, originalBounds.height) / 2
                initialRadius = maxRadius
                cornerRadii = [initialRadius, initialRadius, initialRadius, initialRadius]
            default:
                initialRadius = 0.0
                cornerRadii = [0.0, 0.0, 0.0, 0.0]
            }
            
            let shape = VectorShape(
                name: document.currentTool.rawValue,
                path: path,
                strokeStyle: strokeStyle,
                fillStyle: fillStyle,
                isRoundedRectangle: true, // Enable corner radius support for ALL rectangles
                originalBounds: originalBounds,
                cornerRadii: cornerRadii
            )
            
            document.addShape(shape)
            Log.info("✅ Created shape with corner radius support: \(document.currentTool.rawValue), bounds=\(originalBounds), radii=\(cornerRadii)pt", category: .fileOperations)
        } else {
            // Standard shape creation for non-rectangle shapes
            let shape = VectorShape(
                name: document.currentTool.rawValue,
                path: path,
                strokeStyle: strokeStyle,
                fillStyle: fillStyle
            )
            
            document.addShape(shape)
        Log.info("✅ Created standard shape: \(document.currentTool.rawValue)", category: .shapes)
        }
        Log.info("✅ Created shape with default colors: fill=\(document.defaultFillColor), stroke=\(document.defaultStrokeColor)", category: .shapes)
        
        // PROFESSIONAL SHAPE DRAWING: Clean state reset for next drawing operation
        // This ensures each new shape starts with fresh reference points
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
        drawingStartPoint = nil
        
        Log.info("🎨 SHAPE DRAWING: Completed successfully - state reset for next operation", category: .shapes)
    }
} 