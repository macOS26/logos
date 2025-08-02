//
//  DrawingCanvas+ShapeDrawing.swift
//  logos inkpen.io
//
//  Shape drawing functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func handleShapeDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        // PROFESSIONAL SHAPE DRAWING: Perfect cursor-to-shape synchronization
        // Uses the same precision approach as hand tool and object dragging
        // This eliminates floating-point accumulation errors from DragGesture.translation
        
        // CRITICAL FIX: Shape tools should only work on DRAG, not click
        // Calculate actual drag distance to distinguish click vs drag
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        let minimumDragThreshold: Double = 12.0 // Must drag at least 12 pixels to start drawing shapes
        
        // Only proceed with shape creation if user has dragged significantly
        if dragDistance < minimumDragThreshold {
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
            // Create a square (equal width and height)
            let size = max(abs(currentLocation.x - startPoint.x), abs(currentLocation.y - startPoint.y))
            let rect = CGRect(
                x: min(startPoint.x, startPoint.x + (currentLocation.x > startPoint.x ? size : -size)),
                y: min(startPoint.y, startPoint.y + (currentLocation.y > startPoint.y ? size : -size)),
                width: size,
                height: size
            )
            currentPath = VectorPath(elements: [
                .move(to: VectorPoint(rect.minX, rect.minY)),
                .line(to: VectorPoint(rect.maxX, rect.minY)),
                .line(to: VectorPoint(rect.maxX, rect.maxY)),
                .line(to: VectorPoint(rect.minX, rect.maxY)),
                .close
            ], isClosed: true)
        case .roundedRectangle:
            // Create a rounded rectangle
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            let cornerRadius = min(rect.width, rect.height) * 0.15 // 15% of smallest dimension
            currentPath = createRoundedRectPath(rect: rect, cornerRadius: cornerRadius)
        case .pill:
            // Create a pill shape (capsule)
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            let cornerRadius = min(rect.width, rect.height) / 2 // Half of smallest dimension
            currentPath = createRoundedRectPath(rect: rect, cornerRadius: cornerRadius)
        case .circle:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            let radius = sqrt(pow(currentLocation.x - startPoint.x, 2) + pow(currentLocation.y - startPoint.y, 2)) / 2
            currentPath = createCirclePath(center: center, radius: radius)
        case .ellipse:
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            currentPath = createEllipsePath(rect: rect)
        case .oval:
            // Create an oval (less rounded than ellipse)
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            // Make it slightly less rounded by constraining the aspect ratio
            let adjustedRect = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: min(rect.height, rect.width * 0.75) // Constrain height to 75% of width max
            )
            currentPath = createEllipsePath(rect: adjustedRect)
        case .equilateralTriangle:
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            currentPath = createEquilateralTrianglePath(rect: rect)
        case .rightTriangle:
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            currentPath = createRightTrianglePath(rect: rect)
        case .acuteTriangle:
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            currentPath = createAcuteTrianglePath(rect: rect)
        case .isoscelesTriangle:
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            currentPath = createIsoscelesTrianglePath(rect: rect)
        case .cone:
            // Create a proper cone shape with curved bottom
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            let topPoint = VectorPoint(rect.midX, rect.minY)
            let bottomLeft = VectorPoint(rect.minX, rect.maxY)
            let bottomRight = VectorPoint(rect.maxX, rect.maxY)
            
            // Create control point for curved bottom - positioned below the base
            // This creates a natural arc that represents the circular base of a cone
            let curveDepth = rect.height * 0.3 // 30% of height for nice curve
            let controlPoint = VectorPoint(rect.midX, rect.maxY + curveDepth)
            
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
            let outerRadius = sqrt(pow(currentLocation.x - startPoint.x, 2) + pow(currentLocation.y - startPoint.y, 2)) / 2
            let innerRadius = outerRadius * 0.4 // Inner radius is 40% of outer radius
            currentPath = createStarPath(center: center, outerRadius: outerRadius, innerRadius: innerRadius, points: 5)
        case .polygon:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            let radius = sqrt(pow(currentLocation.x - startPoint.x, 2) + pow(currentLocation.y - startPoint.y, 2)) / 2
            currentPath = createPolygonPath(center: center, radius: radius, sides: 6) // Default hexagon
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
            opacity: document.defaultStrokeOpacity  // 100% opacity by default
        )
        let fillStyle = FillStyle(
            color: document.defaultFillColor,
            opacity: document.defaultFillOpacity  // 100% opacity by default
        )
        
        let shape = VectorShape(
            name: document.currentTool.rawValue,
            path: path,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        document.addShape(shape)
        print("✅ Created shape with default colors: fill=\(document.defaultFillColor), stroke=\(document.defaultStrokeColor)")
        
        // PROFESSIONAL SHAPE DRAWING: Clean state reset for next drawing operation
        // This ensures each new shape starts with fresh reference points
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
        drawingStartPoint = nil
        
        print("🎨 SHAPE DRAWING: Completed successfully - state reset for next operation")
    }
} 