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
        if let metalEngine = MetalComputeEngine.shared {
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
        } else {
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
        
        // EQUILATERAL TRIANGLE: Allow truly free drawing from 0,0 (no minimum threshold)
        // OTHER SHAPES: Must drag at least 12 pixels to start drawing shapes
        let minimumDragThreshold: Double = (document.currentTool == .equilateralTriangle) ? 0.0 : 12.0
        
        // Only proceed with shape creation if user has dragged significantly
        if Double(dragDistance) < minimumDragThreshold {
            print("🎨 SHAPE TOOL: Drag distance (\(String(format: "%.1f", dragDistance))px) below threshold - CLICK IGNORED (shapes are drag-only)")
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
            
            print("🎨 SHAPE DRAWING: Started at cursor position (\(String(format: "%.1f", shapeDragStart.x)), \(String(format: "%.1f", shapeDragStart.y)))")
            print("🎨 SHAPE TOOL: Drag distance (\(String(format: "%.1f", dragDistance))px) above threshold - starting shape creation")
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
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            currentPath = VectorPath(elements: [
                .move(to: VectorPoint(rect.minX, rect.minY)),
                .line(to: VectorPoint(rect.maxX, rect.minY)),
                .line(to: VectorPoint(rect.maxX, rect.maxY)),
                .line(to: VectorPoint(rect.minX, rect.maxY)),
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
            if let metalEngine = MetalComputeEngine.shared {
                let sqrtResult = metalEngine.calculateSquareRootGPU(3.0)
                switch sqrtResult {
                case .success(let value):
                    sqrt3 = value
                case .failure(_):
                    sqrt3 = Float(sqrt(3.0))
                }
            } else {
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
            // FIXED: Pin cone from start point like rectangle tool
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            let rect = CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: dragDeltaX,
                height: dragDeltaY
            )
            // Normalize rect for proper cone drawing
            let normalizedRect = CGRect(
                x: min(rect.minX, rect.maxX),
                y: min(rect.minY, rect.maxY),
                width: abs(rect.width),
                height: abs(rect.height)
            )
            let topPoint = VectorPoint(normalizedRect.midX, normalizedRect.minY)
            let bottomLeft = VectorPoint(normalizedRect.minX, normalizedRect.maxY)
            let bottomRight = VectorPoint(normalizedRect.maxX, normalizedRect.maxY)
            
            // Create control point for curved bottom - positioned below the base
            // This creates a natural arc that represents the circular base of a cone
            let curveDepth = normalizedRect.height * 0.3 // 30% of height for nice curve
            let controlPoint = VectorPoint(normalizedRect.midX, normalizedRect.maxY + curveDepth)
            
            currentPath = VectorPath(elements: [
                .move(to: topPoint),
                .line(to: bottomLeft),
                .quadCurve(to: bottomRight, control: controlPoint),
                .line(to: topPoint),
                .close
            ], isClosed: true)
        case .star:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            // 🚀 PHASE 12: GPU-accelerated distance calculation for radius
            let outerRadius = calculateDistanceWithFallback(from: startPoint, to: currentLocation) / 2.0
            let innerRadius = Double(outerRadius) * 0.4 // Inner radius is 40% of outer radius
            currentPath = createStarPath(center: center, outerRadius: Double(outerRadius), innerRadius: innerRadius, points: 5)
        case .polygon:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            // 🚀 PHASE 12: GPU-accelerated distance calculation for radius
            let radius = calculateDistanceWithFallback(from: startPoint, to: currentLocation) / 2.0
            currentPath = createPolygonPath(center: center, radius: Double(radius), sides: 6) // Default hexagon
        case .pentagon:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            // 🚀 PHASE 12: GPU-accelerated distance calculation for radius
            let radius = calculateDistanceWithFallback(from: startPoint, to: currentLocation) / 2.0
            currentPath = createPolygonPath(center: center, radius: Double(radius), sides: 5)
        case .hexagon:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            // 🚀 PHASE 12: GPU-accelerated distance calculation for radius
            let radius = calculateDistanceWithFallback(from: startPoint, to: currentLocation) / 2.0
            currentPath = createPolygonPath(center: center, radius: Double(radius), sides: 6)
        case .heptagon:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            // 🚀 PHASE 12: GPU-accelerated distance calculation for radius
            let radius = calculateDistanceWithFallback(from: startPoint, to: currentLocation) / 2.0
            currentPath = createPolygonPath(center: center, radius: Double(radius), sides: 7)
        case .octagon:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            // 🚀 PHASE 12: GPU-accelerated distance calculation for radius
            let radius = calculateDistanceWithFallback(from: startPoint, to: currentLocation) / 2.0
            currentPath = createPolygonPath(center: center, radius: Double(radius), sides: 8)
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
                print("🔍 SQUARE CREATION: Square originalBounds: \(originalBounds)")
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
            print("✅ Created shape with corner radius support: \(document.currentTool.rawValue), bounds=\(originalBounds), radii=\(cornerRadii)pt")
        } else {
            // Standard shape creation for non-rectangle shapes
            let shape = VectorShape(
                name: document.currentTool.rawValue,
                path: path,
                strokeStyle: strokeStyle,
                fillStyle: fillStyle
            )
            
            document.addShape(shape)
            print("✅ Created standard shape: \(document.currentTool.rawValue)")
        }
        print("✅ Created shape with default colors: fill=\(document.defaultFillColor), stroke=\(document.defaultStrokeColor)")
        
        // PROFESSIONAL SHAPE DRAWING: Clean state reset for next drawing operation
        // This ensures each new shape starts with fresh reference points
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
        drawingStartPoint = nil
        
        print("🎨 SHAPE DRAWING: Completed successfully - state reset for next operation")
    }
} 