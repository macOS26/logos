//
//  LayerView+TransformBoxHandles.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import SwiftUI
import Combine

// MARK: - Transform Box for Arrow Tool (Illustrator-style)
struct TransformBoxHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool
    let transformOrigin: TransformOrigin

    // State for interactive scaling
    @State private var isScaling: Bool = false
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity

    private let handleSize: CGFloat = 10
    private let handleHitAreaSize: CGFloat = 10  // EXACT same as visual handle size

    var body: some View {
        let transformedBounds: CGRect = computeTransformedBounds()

        ZStack {
            // Bounding rectangle (dashed)
            // CRITICAL FIX: Use Path with CGRect to match ShapeView rendering exactly
            // Path coordinates are in canvas space, just like shape.path
            Path(transformedBounds)
                .stroke(Color.black.opacity(0.5), style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .allowsHitTesting(false)

            // Red preview outline when scaling
            if isScaling && !previewTransform.isIdentity {
                // Check if this is a group - preview all grouped shapes
                if shape.isGroupContainer {
                    // Preview each grouped shape
                    ForEach(shape.groupedShapes.indices, id: \.self) { index in
                        let groupedShape = shape.groupedShapes[index]
                        Path { path in
                            for element in groupedShape.path.elements {
                                switch element {
                                case .move(let to):
                                    let p = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    path.move(to: p)
                                case .line(let to):
                                    let p = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    path.addLine(to: p)
                                case .curve(let to, let c1, let c2):
                                    let tp = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    let tc1 = CGPoint(x: c1.x, y: c1.y).applying(previewTransform)
                                    let tc2 = CGPoint(x: c2.x, y: c2.y).applying(previewTransform)
                                    path.addCurve(to: tp, control1: tc1, control2: tc2)
                                case .quadCurve(let to, let c):
                                    let tp = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    let tc = CGPoint(x: c.x, y: c.y).applying(previewTransform)
                                    path.addQuadCurve(to: tp, control: tc)
                                case .close:
                                    path.closeSubpath()
                                }
                            }
                        }
                        .stroke(Color.red, lineWidth: 1.0 / zoomLevel)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .allowsHitTesting(false)
                    }
                } else if shape.isTextObject {
                    // TEXT OBJECTS: Preview transformed text box rectangle
                    if let originalPosition = shape.textPosition, let originalAreaSize = shape.areaSize {
                        let originalBounds = CGRect(x: originalPosition.x, y: originalPosition.y, width: originalAreaSize.width, height: originalAreaSize.height)
                        let transformedBounds = originalBounds.applying(previewTransform)

                        Rectangle()
                            .stroke(Color.red, lineWidth: 1.0 / zoomLevel)
                            .frame(width: transformedBounds.width, height: transformedBounds.height)
                            .position(x: transformedBounds.midX, y: transformedBounds.midY)
                            .scaleEffect(zoomLevel, anchor: .topLeading)
                            .offset(x: canvasOffset.x, y: canvasOffset.y)
                            .allowsHitTesting(false)
                    }
                } else {
                    // Preview single shape path
                    Path { path in
                        for element in shape.path.elements {
                            switch element {
                            case .move(let to):
                                let p = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                path.move(to: p)
                            case .line(let to):
                                let p = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                path.addLine(to: p)
                            case .curve(let to, let c1, let c2):
                                let tp = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                let tc1 = CGPoint(x: c1.x, y: c1.y).applying(previewTransform)
                                let tc2 = CGPoint(x: c2.x, y: c2.y).applying(previewTransform)
                                path.addCurve(to: tp, control1: tc1, control2: tc2)
                            case .quadCurve(let to, let c):
                                let tp = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                let tc = CGPoint(x: c.x, y: c.y).applying(previewTransform)
                                path.addQuadCurve(to: tp, control: tc)
                            case .close:
                                path.closeSubpath()
                            }
                        }
                    }
                    .stroke(Color.red, lineWidth: 1.0 / zoomLevel)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .allowsHitTesting(false)
                }
            }

            // Handles: 4 corners + 4 mids + center
            ForEach(0..<9) { index in
                let pt = handlePosition(index: index, in: transformedBounds)
                let isAnchorPoint = isHandleTheAnchor(index: index)
                let isAdjacentToAnchor = isHandleAdjacentToAnchor(index: index)
                let isDisabled = isAnchorPoint || isAdjacentToAnchor

                ZStack {
                    // Invisible expanded hit area for easier selection
                    Circle()
                        .fill(Color.clear)
                        .frame(width: handleHitAreaSize, height: handleHitAreaSize)
                        .contentShape(Circle())
                        .allowsHitTesting(true)  // Allow clicking on all handles to set as anchor

                    // Visible handle - RED for anchor, ORANGE for disabled, BLUE for active
                    // FIXED: Constant SCREEN size (not canvas size) - always same pixel size
                    // All handles same size, same border width
                    Circle()
                        .fill(isAnchorPoint ? Color.red : (isDisabled ? Color.orange : Color.blue))
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.0))
                        .frame(width: handleSize, height: handleSize)
                        .allowsHitTesting(false)  // Hit testing handled by larger area
                }
                .position(CGPoint(x: pt.x * zoomLevel + canvasOffset.x,
                                  y: pt.y * zoomLevel + canvasOffset.y))
                .onTapGesture {
                    // Click to set this handle as the anchor point (red dot)
                    setAnchorPoint(forHandle: index)
                }
                .simultaneousGesture(
                    isDisabled ? nil : // Only allow dragging for non-disabled handles
                    DragGesture(minimumDistance: 0.5) // Small threshold
                        .onChanged { value in
                            if !isScaling {
                                beginScaling(startValue: value)
                            }
                            updateScaling(forHandle: index, dragValue: value, bounds: transformedBounds)
                        }
                        .onEnded { _ in
                            endScaling()
                        }
                )
            }
        }
        .onAppear {
        // Start with identity since we apply transforms to coordinates
        initialTransform = .identity
    }
    }

    // Compute transformed bounds in canvas coordinates (after shape.transform)
    private func computeTransformedBounds() -> CGRect {
        // CRITICAL FIX: For text objects, textPosition matches .position() CENTER coordinate
        let baseBounds: CGRect
        if shape.isTextObject, let areaSize = shape.areaSize, let textPosition = shape.textPosition {
            // TEXT OBJECTS: textPosition is stored as top-left (minX, minY)
            // Text canvas: .position(x: minX + width/2, y: minY + height/2)
            // Transform box should show bounds at (minX, minY, width, height)
            baseBounds = CGRect(x: textPosition.x, y: textPosition.y, width: areaSize.width, height: areaSize.height)
            Log.info("🔍 TRANSFORM BOX: textPos=(\(textPosition.x), \(textPosition.y)) areaSize=(\(areaSize.width)x\(areaSize.height)) -> bounds=\(baseBounds)", category: .general)
        } else {
            baseBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        }

        // CRITICAL FIX: For text objects, position is already in world coords, no transform needed
        if shape.isTextObject {
            return baseBounds  // Already has correct position from textPosition
        }

        // CRITICAL FIX: Account for stroke width in bounding box for stroke-only shapes
        var strokeExpandedBounds = baseBounds
        let isStrokeOnly = (shape.fillStyle?.color == .clear || shape.fillStyle == nil)
        if isStrokeOnly && shape.strokeStyle != nil {
            let strokeWidth = shape.strokeStyle?.width ?? 1.0
            let strokeExpansion = strokeWidth / 2.0 // Half stroke width on each side
            strokeExpandedBounds = baseBounds.insetBy(dx: -strokeExpansion, dy: -strokeExpansion)
        }

        // PRECISION FIX: For regular shapes (non-groups, non-images), transforms are baked into path coords
        // so shape.transform is ALWAYS identity. Return bounds directly for exact precision.
        // For groups and images, transform is stored in shape.transform property.
        let t = shape.transform

        // If transform is identity (regular shapes with baked transforms), return bounds directly
        if t.isIdentity {
            return strokeExpandedBounds
        }

        // For non-identity transforms (groups, images), apply transform precisely
        // Use CGRect.applying() for exact CoreGraphics precision
        return strokeExpandedBounds.applying(t)
    }

    private func handlePosition(index: Int, in rect: CGRect) -> CGPoint {
        // 0 TL, 1 Top, 2 TR, 3 Right, 4 BR, 5 Bottom, 6 BL, 7 Left, 8 Center
        switch index {
        case 0: return CGPoint(x: rect.minX, y: rect.minY)
        case 1: return CGPoint(x: rect.midX, y: rect.minY)
        case 2: return CGPoint(x: rect.maxX, y: rect.minY)
        case 3: return CGPoint(x: rect.maxX, y: rect.midY)
        case 4: return CGPoint(x: rect.maxX, y: rect.maxY)
        case 5: return CGPoint(x: rect.midX, y: rect.maxY)
        case 6: return CGPoint(x: rect.minX, y: rect.maxY)
        case 7: return CGPoint(x: rect.minX, y: rect.midY)
        default: return CGPoint(x: rect.midX, y: rect.midY)
        }
    }

    private func isHandleTheAnchor(index: Int) -> Bool {
        // Map handle indices to transform origin positions
        // 0=TL, 1=Top, 2=TR, 3=Right, 4=BR, 5=Bottom, 6=BL, 7=Left, 8=Center
        let handleToOrigin: [TransformOrigin] = [
            .topLeft, .topCenter, .topRight,
            .middleRight, .bottomRight, .bottomCenter,
            .bottomLeft, .middleLeft, .center
        ]
        return index < handleToOrigin.count && handleToOrigin[index] == transformOrigin
    }

    private func isHandleAdjacentToAnchor(index: Int) -> Bool {
        // For each anchor point, return the adjacent handles that cannot scale
        // Handle indices: 0=TL, 1=Top, 2=TR, 3=Right, 4=BR, 5=Bottom, 6=BL, 7=Left, 8=Center
        switch transformOrigin {
        // Corner anchors: disable adjacent side handles
        case .topLeft:      return index == 1 || index == 7  // Top and Left sides
        case .topRight:     return index == 1 || index == 3  // Top and Right sides
        case .bottomRight:  return index == 3 || index == 5  // Right and Bottom sides
        case .bottomLeft:   return index == 5 || index == 7  // Bottom and Left sides

        // Side anchors: disable adjacent corner handles
        case .topCenter:    return index == 0 || index == 2  // Top-left and Top-right corners
        case .middleRight:  return index == 2 || index == 4  // Top-right and Bottom-right corners
        case .bottomCenter: return index == 4 || index == 6  // Bottom-right and Bottom-left corners
        case .middleLeft:   return index == 0 || index == 6  // Top-left and Bottom-left corners

        // Center anchor: no restrictions
        case .center:       return false
        }
    }

    private func getTransformAnchor(in rect: CGRect) -> CGPoint {
        // Use the selected transform origin from the 9-point grid
        let origin = transformOrigin.point
        return CGPoint(
            x: rect.minX + rect.width * origin.x,
            y: rect.minY + rect.height * origin.y
        )
    }

    private func setAnchorPoint(forHandle index: Int) {
        // Map handle indices to transform origin positions
        // 0=TL, 1=Top, 2=TR, 3=Right, 4=BR, 5=Bottom, 6=BL, 7=Left, 8=Center
        let handleToOrigin: [TransformOrigin] = [
            .topLeft, .topCenter, .topRight,
            .middleRight, .bottomRight, .bottomCenter,
            .bottomLeft, .middleLeft, .center
        ]

        if index < handleToOrigin.count {
            // Update the document's transform origin
            document.transformOrigin = handleToOrigin[index]
            document.objectWillChange.send()
        }
    }

    private func beginScaling(startValue: DragGesture.Value) {
        isScaling = true
        startLocation = startValue.startLocation
        initialTransform = .identity  // Always use identity since we apply to coordinates
        document.isHandleScalingActive = true
        document.saveToUndoStack()
    }

    private func updateScaling(forHandle index: Int, dragValue: DragGesture.Value, bounds: CGRect) {
        // Handle 8 (center) uses a special, stable mapping from mouse delta to scale
        if index == 8 {
            let anchor = getTransformAnchor(in: bounds)
            // Convert mouse delta to canvas space
            let preciseZoom = CGFloat(zoomLevel)
            let dxCanvas = (dragValue.location.x - startLocation.x) / preciseZoom
            let dyCanvas = (dragValue.location.y - startLocation.y) / preciseZoom

            // Sensitivity: moving by full width/height -> ~2x
            let denomX = max(20.0, bounds.width)
            let denomY = max(20.0, bounds.height)

            var sx = 1.0 + (dxCanvas / denomX)
            var sy = 1.0 + (dyCanvas / denomY)

            // Uniform with shift: take dominant axis sign/magnitude
            if isShiftPressed {
                let ux = dxCanvas / denomX
                let uy = dyCanvas / denomY
                let useX = abs(ux) >= abs(uy)
                let u = useX ? ux : uy
                sx = 1.0 + u
                sy = 1.0 + u
            }

            let maxScale: CGFloat = 10.0
            let minScale: CGFloat = 0.1
            sx = min(max(sx, minScale), maxScale)
            sy = min(max(sy, minScale), maxScale)

            // Build scale transform about center
            let scaleTransform = CGAffineTransform.identity
                .translatedBy(x: anchor.x, y: anchor.y)
                .scaledBy(x: sx, y: sy)
                .translatedBy(x: -anchor.x, y: -anchor.y)

            previewTransform = scaleTransform  // Direct transform, no concatenation
            document.isHandleScalingActive = true
            document.objectWillChange.send()
            return
        }

        let anchor = getTransformAnchor(in: bounds) // Use selected transform origin

        // Convert anchor to screen coordinates
        let anchorScreenX = anchor.x * zoomLevel + canvasOffset.x
        let anchorScreenY = anchor.y * zoomLevel + canvasOffset.y

        let startDX = startLocation.x - anchorScreenX
        let startDY = startLocation.y - anchorScreenY
        let curDX = dragValue.location.x - anchorScreenX
        let curDY = dragValue.location.y - anchorScreenY

        // Avoid division by near-zero
        let minDist: CGFloat = 2.0
        let maxScale: CGFloat = 10.0
        let minScale: CGFloat = 0.1

        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0

        let isCorner = [0,2,4,6].contains(index)
        let isTopBottom = [1,5].contains(index)
        let isLeftRight = [3,7].contains(index)
        if isCorner {
            let sx = abs(startDX) > minDist ? abs(curDX) / abs(startDX) : 1.0
            let sy = abs(startDY) > minDist ? abs(curDY) / abs(startDY) : 1.0
            if isShiftPressed {
                let u = max(sx, sy)
                scaleX = u
                scaleY = u
            } else {
                scaleX = sx
                scaleY = sy
            }
        } else if isTopBottom {
            // Vertical only
            let sy = abs(startDY) > minDist ? abs(curDY) / abs(startDY) : 1.0
            scaleX = 1.0
            scaleY = sy
        } else if isLeftRight {
            // Horizontal only
            let sx = abs(startDX) > minDist ? abs(curDX) / abs(startDX) : 1.0
            scaleX = sx
            scaleY = 1.0
        }

        scaleX = min(max(scaleX, minScale), maxScale)
        scaleY = min(max(scaleY, minScale), maxScale)

        // Build scale transform about anchor (canvas space)
        let scaleTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -anchor.x, y: -anchor.y)

        previewTransform = scaleTransform  // Direct transform, no concatenation
        // Keep transform active so next small drags immediately continue
        document.isHandleScalingActive = true

        // LIVE UPDATE W/H: Calculate and update dimensions during drag (every frame)
        let currentBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        let newBounds = currentBounds.applying(scaleTransform)
        document.scalePreviewDimensions = CGSize(width: newBounds.width, height: newBounds.height)

        document.objectWillChange.send()
    }

    private func endScaling() {
        isScaling = false
        document.isHandleScalingActive = false
        document.scalePreviewDimensions = .zero // Reset preview dimensions
        
        // CRITICAL FIX: Find the unified object that contains this specific shape
        // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
        if let unifiedObject = document.findObject(by: shape.id),
        let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {
        
        let shapes = document.getShapesForLayer(layerIndex)
        if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }),
           let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
            
            var updatedShape = currentShape

            // TEXT OBJECTS: Update areaSize and bounds directly (like text tool resize)
            if currentShape.isTextObject {
                // Extract scale from transform
                let scaleX = sqrt(previewTransform.a * previewTransform.a + previewTransform.c * previewTransform.c)
                let scaleY = sqrt(previewTransform.b * previewTransform.b + previewTransform.d * previewTransform.d)

                // Calculate new dimensions from original areaSize
                if let originalAreaSize = currentShape.areaSize, let originalPosition = currentShape.textPosition {
                    let newWidth = originalAreaSize.width * scaleX
                    let newHeight = originalAreaSize.height * scaleY

                    // CRITICAL: Calculate new position based on anchor point and scale
                    // The anchor point (transform origin) stays fixed, position moves accordingly
                    let originalBounds = CGRect(x: originalPosition.x, y: originalPosition.y, width: originalAreaSize.width, height: originalAreaSize.height)
                    let transformedBounds = originalBounds.applying(previewTransform)

                    // New position is the top-left of the transformed bounds
                    let newPosition = CGPoint(x: transformedBounds.minX, y: transformedBounds.minY)

                    // Update areaSize (this is what text tool does)
                    updatedShape.areaSize = CGSize(width: newWidth, height: newHeight)
                    // Update bounds to match areaSize
                    updatedShape.bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
                    // Update position to account for anchor point
                    updatedShape.textPosition = newPosition
                    // Keep transform identity for text objects
                    updatedShape.transform = .identity

                    document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)

                    // Also update in unified system
                    document.updateTextAreaSizeInUnified(id: currentShape.id, areaSize: CGSize(width: newWidth, height: newHeight))
                    document.updateTextBoundsInUnified(id: currentShape.id, bounds: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                    document.updateTextPositionInUnified(id: currentShape.id, position: newPosition)
                }
            } else if ImageContentRegistry.containsImage(currentShape) {
                // RASTER IMAGES: Keep transforms on transform property instead of baking into path
                updatedShape.transform = previewTransform
                updatedShape.updateBounds()
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            } else {
                // Apply transform directly to path coordinates, no matrix transforms
                updatedShape.transform = .identity
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            }
            previewTransform = .identity

            // UPDATE X Y W H: Call the common update function after transform is applied
            document.updateTransformPanelValues()

            // Force UI refresh to reflect committed transform
            document.objectWillChange.send()
            
            // CRITICAL FIX: Sync unified objects after scaling to ensure UI updates
            document.updateUnifiedObjectsOptimized()
        }
        } else {
            Log.error("❌ SCALING FAILED: Could not find shape in unified objects system", category: .error)
        }
    }

    // Apply preview transform to actual coordinates then reset transform (local implementation)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform) {
        guard let targetShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let t = transform
        if t.isIdentity { return }

        // Check if this is a group - if so, we need to transform all grouped shapes
        if targetShape.isGroupContainer {
            // For groups, we need to update the entire shape with transformed grouped shapes
            document.updateEntireShapeInUnified(id: targetShape.id) { shape in
                // Transform each grouped shape's path
                var transformedGroupedShapes: [VectorShape] = []
                for var groupedShape in shape.groupedShapes {
                    // Transform the grouped shape's path elements
                    var transformedElements: [PathElement] = []
                    for element in groupedShape.path.elements {
                        switch element {
                        case .move(let to):
                            transformedElements.append(.move(to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t))))
                        case .line(let to):
                            transformedElements.append(.line(to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t))))
                        case .curve(let to, let c1, let c2):
                            transformedElements.append(.curve(
                                to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t)),
                                control1: VectorPoint(CGPoint(x: c1.x, y: c1.y).applying(t)),
                                control2: VectorPoint(CGPoint(x: c2.x, y: c2.y).applying(t))
                            ))
                        case .quadCurve(let to, let c):
                            transformedElements.append(.quadCurve(
                                to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t)),
                                control: VectorPoint(CGPoint(x: c.x, y: c.y).applying(t))
                            ))
                        case .close:
                            transformedElements.append(.close)
                        }
                    }
                    groupedShape.path = VectorPath(elements: transformedElements, isClosed: groupedShape.path.isClosed)
                    groupedShape.updateBounds()
                    transformedGroupedShapes.append(groupedShape)
                }
                shape.groupedShapes = transformedGroupedShapes
                shape.transform = .identity
            }
        } else {
            // For regular shapes, transform the path elements as before
            var transformedElements: [PathElement] = []
            for element in targetShape.path.elements {
                switch element {
                case .move(let to):
                    transformedElements.append(.move(to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t))))
                case .line(let to):
                    transformedElements.append(.line(to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t))))
                case .curve(let to, let c1, let c2):
                    transformedElements.append(.curve(
                        to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t)),
                        control1: VectorPoint(CGPoint(x: c1.x, y: c1.y).applying(t)),
                        control2: VectorPoint(CGPoint(x: c2.x, y: c2.y).applying(t))
                    ))
                case .quadCurve(let to, let c):
                    transformedElements.append(.quadCurve(
                        to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t)),
                        control: VectorPoint(CGPoint(x: c.x, y: c.y).applying(t))
                    ))
                case .close:
                    transformedElements.append(.close)
                }
            }

            let newPath = VectorPath(elements: transformedElements, isClosed: targetShape.path.isClosed)
            document.updateShapeTransformAndPathInUnified(id: targetShape.id, path: newPath, transform: .identity)
        }
    }
}
