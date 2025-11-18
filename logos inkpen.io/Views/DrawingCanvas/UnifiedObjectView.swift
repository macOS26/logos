import SwiftUI
import CoreGraphics
import simd

struct PasteboardBackgroundView: View {
    let pasteboardSize: CGSize
    let pasteboardOrigin: CGPoint
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        //let _ = Self._printChanges()
        Canvas { context, size in
            // SIMD optimization for transform calculations
            let originVec = SIMD2<Float>(Float(pasteboardOrigin.x), Float(pasteboardOrigin.y))
            let sizeVec = SIMD2<Float>(Float(pasteboardSize.width), Float(pasteboardSize.height))
            let offsetVec = SIMD2<Float>(Float(canvasOffset.x), Float(canvasOffset.y))
            let zoom = Float(zoomLevel)

            let scaledOrigin = originVec * zoom + offsetVec
            let scaledSize = sizeVec * zoom

            let scaledRect = CGRect(
                x: CGFloat(scaledOrigin.x),
                y: CGFloat(scaledOrigin.y),
                width: CGFloat(scaledSize.x),
                height: CGFloat(scaledSize.y)
            )

            context.fill(
                Path(roundedRect: scaledRect, cornerRadius: 0),
                with: .color(.black.opacity(0.2))
            )
        }
        .drawingGroup()
    }
}

struct CanvasBackgroundView: View {
    let canvasSize: CGSize
    let backgroundColor: Color
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        Canvas { context, size in
            // SIMD optimization for transform calculations
            let offsetVec = SIMD2<Float>(Float(canvasOffset.x), Float(canvasOffset.y))
            let sizeVec = SIMD2<Float>(Float(canvasSize.width), Float(canvasSize.height))
            let zoom = Float(zoomLevel)

            let scaledSize = sizeVec * zoom

            let scaledRect = CGRect(
                x: CGFloat(offsetVec.x),
                y: CGFloat(offsetVec.y),
                width: CGFloat(scaledSize.x),
                height: CGFloat(scaledSize.y)
            )

            context.fill(
                Path(roundedRect: scaledRect, cornerRadius: 0),
                with: .color(backgroundColor)
            )
        }
        .drawingGroup()
    }
}

struct LayerCanvasView: View {
    let objectIDs: [UUID]
    let document: VectorDocument  // Need this for cgImageCache and mask lookups
    let documentURL: URL?  // For resolving relative image paths
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let liveNudgeOffset: CGVector
    let liveScaleTransform: CGAffineTransform
    let dragPreviewTrigger: Bool
    let livePointPositions: [PointID: CGPoint]
    let liveHandlePositions: [HandleID: CGPoint]
    let fillDeltaOpacity: Double?
    let strokeDeltaOpacity: Double?
    let strokeDeltaWidth: Double?
    let colorDeltaColor: VectorColor?
    let colorDeltaOpacity: Double?
    @Binding var activeGradientDelta: VectorGradient?
    let isPanning: Bool  // When true, expand viewport for smooth pan
    let activeColorTarget: ColorTarget
    @Binding var textContentDelta: (id: UUID, content: String)?
    let fontSizeDelta: Double?
    let lineSpacingDelta: Double?
    let lineHeightDelta: Double?
    let letterSpacingDelta: Double?
    let imagePreviewQuality: Double
    let imageTileSize: Int
    let imageInterpolationQuality: CGInterpolationQuality
    let liveCornerRadii: [Double]
    let selectedShapeIDForCornerRadius: UUID?
    let layerUpdateTrigger: UInt?

    var appState = AppState.shared

    // Calculate viewport rectangle in document coordinates for culling
    private func viewportRect(canvasSize: CGSize) -> CGRect {
        // SIMD optimization for viewport transform calculations
        let offsetVec = SIMD2<Float>(Float(canvasOffset.x), Float(canvasOffset.y))
        let sizeVec = SIMD2<Float>(Float(canvasSize.width), Float(canvasSize.height))
        let zoom = Float(zoomLevel)

        // Transform to document coords: (screenX - offset) / zoom
        let docOrigin = -offsetVec / zoom
        let docSize = sizeVec / zoom

        return CGRect(
            x: CGFloat(docOrigin.x),
            y: CGFloat(docOrigin.y),
            width: CGFloat(docSize.x),
            height: CGFloat(docSize.y)
        )
    }

    // Pre-filter visible objects with viewport culling (O(n) once per objects change)
    // Filters out objects that are:
    // 1. Hidden (isVisible == false)
    // 2. Outside the viewport bounds (performance optimization)
    private func culledObjects(canvasSize: CGSize) -> [VectorObject] {
        // During pan, skip culling to avoid filtering overhead every frame
        // Just return all visible objects
        if isPanning {
            return objectIDs.compactMap { id in
                guard let object = document.snapshot.objects[id],
                      object.isVisible else { return nil }
                return object
            }
        }

        let viewport = viewportRect(canvasSize: canvasSize)

        return objectIDs.compactMap { id in
            guard let object = document.snapshot.objects[id],
                  object.isVisible else { return nil }

            // Don't cull text objects - they need better bounds calculation
            if case .text = object.objectType {
                return object
            }

            // Get object bounds
            let objectBounds = object.shape.bounds

            // Use SIMD for fast intersection test
            return objectBounds.intersectsSIMD(viewport) ? object : nil
        }
    }

    // Get layer index for debug printing
    private var layerInfo: String {
        guard let firstID = objectIDs.first,
              let obj = document.snapshot.objects[firstID] else {
            return "Empty"
        }
        return "Layer[\(obj.layerIndex)]"
    }

    // Apply live point/handle positions to a shape for rendering preview
    private func applyLivePositions(to shape: VectorShape) -> VectorShape {
        // Check if this shape has any live positions
        let shapeID = shape.id
        var hasLivePositions = false

        for pointID in livePointPositions.keys {
            if pointID.shapeID == shapeID {
                hasLivePositions = true
                break
            }
        }
        if !hasLivePositions {
            for handleID in liveHandlePositions.keys {
                if handleID.shapeID == shapeID {
                    hasLivePositions = true
                    break
                }
            }
        }

        guard hasLivePositions else { return shape }

        // Create modified shape with live positions
        var modifiedShape = shape
        var modifiedElements = shape.path.elements

        for (pointID, livePosition) in livePointPositions where pointID.shapeID == shapeID {
            guard pointID.elementIndex < modifiedElements.count else { continue }

            let newPoint = VectorPoint(livePosition.x, livePosition.y)

            switch modifiedElements[pointID.elementIndex] {
            case .move(_):
                modifiedElements[pointID.elementIndex] = .move(to: newPoint)
            case .line(_):
                modifiedElements[pointID.elementIndex] = .line(to: newPoint)
            case .curve(_, let control1, let control2):
                modifiedElements[pointID.elementIndex] = .curve(to: newPoint, control1: control1, control2: control2)
            case .quadCurve(_, let control):
                modifiedElements[pointID.elementIndex] = .quadCurve(to: newPoint, control: control)
            case .close:
                break
            }
        }

        for (handleID, livePosition) in liveHandlePositions where handleID.shapeID == shapeID {
            guard handleID.elementIndex < modifiedElements.count else { continue }

            let newHandle = VectorPoint(livePosition.x, livePosition.y)

            switch modifiedElements[handleID.elementIndex] {
            case .curve(let to, let control1, let control2):
                if handleID.handleType == .control1 {
                    modifiedElements[handleID.elementIndex] = .curve(to: to, control1: newHandle, control2: control2)
                } else {
                    modifiedElements[handleID.elementIndex] = .curve(to: to, control1: control1, control2: newHandle)
                }
            case .quadCurve(let to, _):
                if handleID.handleType == .control1 {
                    modifiedElements[handleID.elementIndex] = .quadCurve(to: to, control: newHandle)
                }
            default:
                break
            }
        }

        modifiedShape.path = VectorPath(elements: modifiedElements)
        modifiedShape.updateBounds()

        return modifiedShape
    }

    // Apply live corner radii to a shape for rendering preview
    private func applyLiveCornerRadii(to shape: VectorShape) -> VectorShape {
        // Only apply if this is the selected shape and we have live radii
        guard !liveCornerRadii.isEmpty,
              selectedShapeIDForCornerRadius == shape.id else {
            return shape
        }

        var modifiedShape = shape
        modifiedShape.cornerRadii = liveCornerRadii

        // Rebuild the path with the new corner radii
        let currentBounds = shape.path.cgPath.boundingBox
        let newPath = createRoundedRectPathWithIndividualCorners(
            rect: currentBounds,
            cornerRadii: liveCornerRadii
        )
        modifiedShape.path = newPath
        modifiedShape.updateBounds()

        return modifiedShape
    }

    var body: some View {
        //let _ = Self._printChanges()
        Canvas { context, size in
            // SIMD optimization: Convert transform values once for entire render pass
            let offsetVec = SIMD2<Float>(Float(canvasOffset.x), Float(canvasOffset.y))
            let zoom = Float(zoomLevel)
            // Combine drag delta and nudge offset
            let dragDelta = SIMD2<Float>(
                Float(dragPreviewDelta.x + liveNudgeOffset.dx),
                Float(dragPreviewDelta.y + liveNudgeOffset.dy)
            )

            // Viewport culling: only render objects in visible area
            let visibleObjects = culledObjects(canvasSize: size)
            //let _ = print("📊 LayerCanvasView \(layerInfo): culled \(objectIDs.count) → \(visibleObjects.count) objects")

            // Cheap SwiftUI layer update
            _ = layerUpdateTrigger

            // Apply base canvas transform (no drag delta)
            let baseTransform = CGAffineTransform.identity
                .translatedBy(x: CGFloat(offsetVec.x), y: CGFloat(offsetVec.y))
                .scaledBy(x: CGFloat(zoom), y: CGFloat(zoom))

            // Render objects in original stacking order
            // Selected objects share the same drag delta transform
            for object in visibleObjects {
                let isSelected = selectedObjectIDs.contains(object.id)

                // Apply selection transform (with drag delta + nudge offset) for selected objects
                // For liveScaleTransform, we apply it to the path geometry directly (not context)
                // to keep stroke width constant while scaling the shape
                let isTextObject = if case .text = object.objectType { true } else { false }
                let hasLiveOffset = dragPreviewDelta != .zero || liveNudgeOffset != .zero

                if isSelected && hasLiveOffset {
                    context.transform = baseTransform
                        .translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                } else {
                    context.transform = baseTransform
                }

                // Pass liveScaleTransform to renderShape so it can apply it to the path geometry
                // This keeps stroke width constant during scaling
                let shapeTransform = (isSelected && !isTextObject) ? liveScaleTransform : .identity

                switch object.objectType {
                case .clipGroup(let clipGroupShape):
                    // ClipGroup: first grouped shape is the mask, rest are clipped content

                    guard !clipGroupShape.groupedShapes.isEmpty else { break }
                    let maskShape = clipGroupShape.groupedShapes[0]
                    let contentShapes = Array(clipGroupShape.groupedShapes.dropFirst())

                    // for (idx, child) in contentShapes.enumerated() {
                    // }

                    // Save parent's transform (includes drag delta if parent clipGroup is selected)
                    let parentTransform = context.transform

                    // In keyline mode, check preference for clipping
                    if viewMode == .keyline {
                        let showClipped = appState.showClippingInKeyline

                        if showClipped {
                            // Show mask outline + clipped content in keyline
                            guard maskShape.isVisible else { break }

                            // Check if mask is individually selected
                            let isMaskSelected = selectedObjectIDs.contains(maskShape.id)
                            let maskTransform = if isMaskSelected && dragPreviewDelta != .zero {
                                baseTransform.translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                            } else {
                                parentTransform
                            }

                            // Render mask outline
                            context.transform = maskTransform
                            let maskScaleTransform = isMaskSelected ? liveScaleTransform : .identity
                            let liveMaskShape = applyLiveCornerRadii(to: applyLivePositions(to: maskShape))
                            renderShape(liveMaskShape, context: &context, isSelected: isMaskSelected, scaleTransform: maskScaleTransform)

                            // Then render content shapes clipped by the mask
                            for contentShape in contentShapes {
                                guard contentShape.isVisible else { continue }
                                let isChildSelected = selectedObjectIDs.contains(contentShape.id)
                                let isChildText = contentShape.typography != nil

                                // Determine content transform (independent of mask)
                                let contentTransform = if isChildSelected && dragPreviewDelta != .zero {
                                    baseTransform.translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                                } else {
                                    parentTransform
                                }

                                let childScaleTransform = (isChildSelected && !isChildText) ? liveScaleTransform : .identity

                                let liveContentShape = applyLiveCornerRadii(to: applyLivePositions(to: contentShape))
                                let liveMaskForClip = applyLiveCornerRadii(to: applyLivePositions(to: maskShape))

                                // Render with separate mask and content transforms
                                context.drawLayer { layerContext in
                                    // Apply mask transform and create clipping region
                                    layerContext.transform = maskTransform
                                    let maskPath = liveMaskForClip.cachedCGPath
                                    layerContext.clip(to: Path(maskPath))

                                    // Apply content transform and render content
                                    layerContext.transform = contentTransform

                                    if VectorText.from(liveContentShape) != nil {
                                        renderText(liveContentShape, context: &layerContext, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, textContentDelta: textContentDelta, maskShape: nil)
                                    } else if hasImageData(liveContentShape) {
                                        renderImage(liveContentShape, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil, canvasSize: size)
                                    } else {
                                        renderShape(liveContentShape, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil)
                                    }
                                }
                            }
                        } else {
                            // Show full outlines (no clipping) in keyline
                            if maskShape.isVisible {
                                let isMaskSelected = selectedObjectIDs.contains(maskShape.id)
                                if isMaskSelected && dragPreviewDelta != .zero {
                                    context.transform = baseTransform.translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                                } else {
                                    context.transform = parentTransform  // Preserve parent's drag delta
                                }
                                let maskScaleTransform = isMaskSelected ? liveScaleTransform : .identity
                                let liveMaskShapeNoClip = applyLiveCornerRadii(to: applyLivePositions(to: maskShape))
                                renderShape(liveMaskShapeNoClip, context: &context, isSelected: isMaskSelected, scaleTransform: maskScaleTransform)
                            }
                            for contentShape in contentShapes {
                                guard contentShape.isVisible else { continue }
                                let isChildSelected = selectedObjectIDs.contains(contentShape.id)
                                let isChildText = contentShape.typography != nil

                                if isChildSelected && dragPreviewDelta != .zero {
                                    context.transform = baseTransform.translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                                } else {
                                    context.transform = parentTransform  // Preserve parent's drag delta
                                }
                                let childScaleTransform = (isChildSelected && !isChildText) ? liveScaleTransform : .identity

                                let liveContentNoClip = applyLivePositions(to: contentShape)

                                if VectorText.from(liveContentNoClip) != nil {
                                    renderText(liveContentNoClip, context: &context, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, textContentDelta: textContentDelta)
                                } else if hasImageData(liveContentNoClip) {
                                    renderImage(liveContentNoClip, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform, canvasSize: size)
                                } else {
                                    renderShape(liveContentNoClip, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform)
                                }
                            }
                        }
                    } else {
                        // Color mode: only render if mask is visible
                        guard maskShape.isVisible else { break }

                        // Determine mask transform (only moves if mask itself is selected)
                        let isMaskSelected = selectedObjectIDs.contains(maskShape.id)
                        let maskTransform = if isMaskSelected && dragPreviewDelta != .zero {
                            baseTransform.translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                        } else {
                            parentTransform
                        }

                        // Render each content shape with the mask (only if visible)
                        for contentShape in contentShapes {
                            guard contentShape.isVisible else { continue }

                            let isChildSelected = selectedObjectIDs.contains(contentShape.id)
                            let isChildText = contentShape.typography != nil

                            // Determine content transform (independent of mask)
                            let contentTransform = if isChildSelected && dragPreviewDelta != .zero {
                                baseTransform.translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                            } else {
                                parentTransform
                            }

                            let childScaleTransform = (isChildSelected && !isChildText) ? liveScaleTransform : .identity

                            let liveContentColorMode = applyLivePositions(to: contentShape)
                            let liveMaskColorMode = applyLivePositions(to: maskShape)

                            // Render with separate mask and content transforms
                            context.drawLayer { layerContext in
                                // Apply mask transform and create clipping region
                                layerContext.transform = maskTransform
                                let maskPath = liveMaskColorMode.cachedCGPath
                                layerContext.clip(to: Path(maskPath))

                                // Apply content transform and render content
                                layerContext.transform = contentTransform

                                if VectorText.from(liveContentColorMode) != nil {
                                    renderText(liveContentColorMode, context: &layerContext, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, textContentDelta: textContentDelta, maskShape: nil)
                                } else if hasImageData(liveContentColorMode) {
                                    renderImage(liveContentColorMode, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil, canvasSize: size)
                                } else {
                                    renderShape(liveContentColorMode, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil)
                                }
                            }
                        }
                    }

                case .group(let groupShape):
                    // Regular Group: render all child shapes (no clipping)
                    guard !groupShape.groupedShapes.isEmpty else { break }

                    // Save parent's transform (includes drag delta if parent group is selected)
                    let parentTransform = context.transform

                    // Render each child shape in the group
                    for childShape in groupShape.groupedShapes {
                        guard childShape.isVisible else { continue }

                        // Check if THIS CHILD is individually selected (not just the group)
                        let isChildSelected = selectedObjectIDs.contains(childShape.id)
                        let isChildText = childShape.typography != nil

                        // Apply drag preview to individual child if it's selected
                        if isChildSelected && dragPreviewDelta != .zero {
                            context.transform = baseTransform
                                .translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                        } else {
                            context.transform = parentTransform  // Preserve parent's drag delta
                        }

                        // Use child-specific selection state for scale transform
                        let childScaleTransform = (isChildSelected && !isChildText) ? liveScaleTransform : .identity

                        // Check if child itself is clipped by another object
                        let maskShape: VectorShape? = {
                            guard let maskID = childShape.clippedByShapeID,
                                  let maskObject = document.snapshot.objects[maskID] else {
                                return nil
                            }
                            return maskObject.shape
                        }()

                        let liveChildShape = applyLiveCornerRadii(to: applyLivePositions(to: childShape))

                        if VectorText.from(liveChildShape) != nil {
                            renderText(liveChildShape, context: &context, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, textContentDelta: textContentDelta, maskShape: maskShape)
                        } else if hasImageData(liveChildShape) {
                            renderImage(liveChildShape, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: maskShape, canvasSize: size)
                        } else {
                            renderShape(liveChildShape, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: maskShape)
                        }
                    }

                case .shape(let shape), .warp(let shape), .clipMask(let shape):
                    // Get mask shape if this object is clipped by another object
                    let maskShape: VectorShape? = {
                        guard let maskID = shape.clippedByShapeID,
                              let maskObject = document.snapshot.objects[maskID] else {
                            return nil
                        }
                        return maskObject.shape
                    }()
                    let liveShape = applyLiveCornerRadii(to: applyLivePositions(to: shape))
                    renderShape(liveShape, context: &context, isSelected: isSelected, scaleTransform: shapeTransform, maskShape: maskShape)

                case .image(let shape):
                    let maskShape: VectorShape? = {
                        guard let maskID = shape.clippedByShapeID,
                              let maskObject = document.snapshot.objects[maskID] else {
                            return nil
                        }
                        return maskObject.shape
                    }()
                    let liveImageShape = applyLiveCornerRadii(to: applyLivePositions(to: shape))
                    renderImage(liveImageShape, context: &context, isSelected: isSelected, scaleTransform: shapeTransform, maskShape: maskShape, canvasSize: size)

                case .text(let shape):
                    let maskShape: VectorShape? = {
                        guard let maskID = shape.clippedByShapeID,
                              let maskObject = document.snapshot.objects[maskID] else {
                            return nil
                        }
                        return maskObject.shape
                    }()
                    let liveTextShape = applyLiveCornerRadii(to: applyLivePositions(to: shape))
                    // For text, pass liveScaleTransform so it can reflow (don't transform)
                    renderText(liveTextShape, context: &context, isSelected: isSelected, liveScaleTransform: isSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, strokeDeltaOpacity: strokeDeltaOpacity, strokeDeltaWidth: strokeDeltaWidth, textContentDelta: textContentDelta, maskShape: maskShape)
                }
            }
        }
    }

    // MARK: - Viewport Culling (O(1) operations)

    private func calculateViewportBounds(size: CGSize) -> CGRect {
        // Convert viewport to document space with padding for smooth scrolling
        let padding: CGFloat = 200.0 // Extra padding to preload nearby objects
        let minX = (-canvasOffset.x - padding) / zoomLevel
        let minY = (-canvasOffset.y - padding) / zoomLevel
        let maxX = (size.width - canvasOffset.x + padding) / zoomLevel
        let maxY = (size.height - canvasOffset.y + padding) / zoomLevel

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func isObjectInViewport(_ bounds: CGRect, viewport: CGRect) -> Bool {
        // Fast AABB intersection test (O(1))
        return bounds.intersects(viewport)
    }

    private func isObjectInViewportSIMD(_ bounds: CGRect, viewport: CGRect) -> Bool {
        // SIMD-accelerated AABB intersection test (O(1), vectorized)
        // Pack bounds into SIMD vectors for parallel comparison
        let objMin = SIMD2<Double>(bounds.minX, bounds.minY)
        let objMax = SIMD2<Double>(bounds.maxX, bounds.maxY)
        let vpMin = SIMD2<Double>(viewport.minX, viewport.minY)
        let vpMax = SIMD2<Double>(viewport.maxX, viewport.maxY)

        // Vectorized intersection test (2 comparisons in parallel)
        // Check overlap: objMax >= vpMin AND objMin <= vpMax
        let overlapMin = objMax .>= vpMin
        let overlapMax = objMin .<= vpMax

        // Combine results: all components must overlap (reduce with AND)
        return all(overlapMin) && all(overlapMax)
    }

    // MARK: - Optimized Shape Rendering

    private func renderShape(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, scaleTransform: CGAffineTransform = .identity, maskShape: VectorShape? = nil) {
        // Fast path: skip invisible shapes (O(1))
        let hasVisibleFill = viewMode == .color && shape.fillStyle != nil && shape.fillStyle!.color != .clear
        let hasVisibleStroke = (viewMode == .keyline || shape.strokeStyle != nil) && (shape.strokeStyle == nil || shape.strokeStyle!.color != .clear)
        guard hasVisibleFill || hasVisibleStroke else { return }

        // Use cached CGPath (O(1) on cache hit)
        // If scaleTransform is active, apply it to the path geometry to scale the shape
        // while keeping stroke width constant
        let cgPath: CGPath
        if scaleTransform != .identity {
            let mutablePath = CGMutablePath()
            mutablePath.addPath(shape.cachedCGPath, transform: scaleTransform)
            cgPath = mutablePath
        } else {
            cgPath = shape.cachedCGPath
        }

        // Drag delta is now applied at canvas level, not per-object

        // If we have a mask, use drawLayer to isolate clipping
        if let maskShape = maskShape {
            context.drawLayer { layerContext in
                let maskPath = maskShape.cachedCGPath
                layerContext.clip(to: Path(maskPath))

                // Render fill (O(1) for solid, O(n) for gradient where n = stops)
                if viewMode == .color, let fillStyle = shape.fillStyle {
                    // Use delta opacity if available and shape is selected
                    let effectiveFillOpacity = (fillDeltaOpacity != nil && selectedObjectIDs.contains(shape.id))
                        ? fillDeltaOpacity!
                        : fillStyle.opacity


                    // Check for activeGradientDelta FIRST (for live preview during drag)
                    // ONLY apply gradient delta if activeColorTarget is .fill
                    if activeGradientDelta != nil && selectedObjectIDs.contains(shape.id) && activeColorTarget == .fill {
                        // Create a fillStyle with activeGradientDelta and opacity
                        let effectiveFillStyle = FillStyle(gradient: activeGradientDelta!, opacity: effectiveFillOpacity)
                        renderGradientToContext(gradient: activeGradientDelta!, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &layerContext)
                    } else if let gradient = fillStyle.gradient {
                        // Use gradient from snapshot
                        let effectiveFillStyle = FillStyle(gradient: gradient, opacity: effectiveFillOpacity)
                        renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &layerContext)
                    } else if fillStyle.color != .clear {
                        // Check for colorDeltaColor for live preview during drag
                        let effectiveFillColor = (colorDeltaColor != nil && selectedObjectIDs.contains(shape.id) && activeColorTarget == .fill)
                            ? colorDeltaColor!
                            : fillStyle.color
                        layerContext.fill(Path(cgPath), with: .color(effectiveFillColor.color.opacity(effectiveFillOpacity)))
                    }
                }

                // Render stroke (O(1) for solid, O(n) for gradient or placement strokes)
                if viewMode == .keyline {
                    layerContext.stroke(Path(cgPath), with: .color(.black), lineWidth: 1.0 / zoomLevel)
                } else if let strokeStyle = shape.strokeStyle {
                    // Use delta values if available and shape is selected
                    let isSelected = selectedObjectIDs.contains(shape.id)
                    let effectiveStrokeOpacity = (strokeDeltaOpacity != nil && isSelected)
                        ? strokeDeltaOpacity!
                        : strokeStyle.opacity
                    let effectiveStrokeWidth = (strokeDeltaWidth != nil && isSelected)
                        ? strokeDeltaWidth!
                        : strokeStyle.width

                    if strokeStyle.placement == .center {
                        // Check for activeGradientDelta FIRST (for live preview during drag)
                        // ONLY apply gradient delta if activeColorTarget is .stroke
                        if activeGradientDelta != nil && isSelected && activeColorTarget == .stroke {
                            let effectiveStrokeStyle = StrokeStyle(
                                gradient: activeGradientDelta!,
                                width: effectiveStrokeWidth,
                                placement: strokeStyle.placement,
                                lineCap: strokeStyle.lineCap.cgLineCap,
                                lineJoin: strokeStyle.lineJoin.cgLineJoin,
                                miterLimit: strokeStyle.miterLimit,
                                opacity: effectiveStrokeOpacity
                            )
                            renderGradientToContext(gradient: activeGradientDelta!, path: cgPath, isStroke: true, strokeStyle: effectiveStrokeStyle, in: &layerContext)
                        } else if let gradient = strokeStyle.gradient {
                            // Use gradient from snapshot
                            let effectiveStrokeStyle = StrokeStyle(
                                gradient: gradient,
                                width: effectiveStrokeWidth,
                                placement: strokeStyle.placement,
                                lineCap: strokeStyle.lineCap.cgLineCap,
                                lineJoin: strokeStyle.lineJoin.cgLineJoin,
                                miterLimit: strokeStyle.miterLimit,
                                opacity: effectiveStrokeOpacity
                            )
                            renderGradientToContext(gradient: gradient, path: cgPath, isStroke: true, strokeStyle: effectiveStrokeStyle, in: &layerContext)
                        } else if strokeStyle.color != .clear {
                            // Check for colorDeltaColor for live preview during drag
                            let effectiveStrokeColor = (colorDeltaColor != nil && isSelected && activeColorTarget == .stroke)
                                ? colorDeltaColor!
                                : strokeStyle.color
                            layerContext.stroke(
                                Path(cgPath),
                                with: .color(effectiveStrokeColor.color.opacity(effectiveStrokeOpacity)),
                                style: SwiftUI.StrokeStyle(
                                    lineWidth: effectiveStrokeWidth,
                                    lineCap: strokeStyle.lineCap.cgLineCap,
                                    lineJoin: strokeStyle.lineJoin.cgLineJoin,
                                    miterLimit: strokeStyle.miterLimit
                                )
                            )
                        }
                    } else {
                        // Create a strokeStyle with effective values for placement strokes
                        var effectiveStrokeStyle = strokeStyle
                        effectiveStrokeStyle.opacity = effectiveStrokeOpacity
                        effectiveStrokeStyle.width = effectiveStrokeWidth
                        renderStrokeWithPlacement(strokeStyle: effectiveStrokeStyle, path: cgPath, in: &layerContext)
                    }
                }
            }
        } else {
            // No mask, render directly
            // Render fill (O(1) for solid, O(n) for gradient where n = stops)
            if viewMode == .color, let fillStyle = shape.fillStyle {
                // Use delta opacity if available and shape is selected
                let effectiveFillOpacity = (fillDeltaOpacity != nil && selectedObjectIDs.contains(shape.id))
                    ? fillDeltaOpacity!
                    : fillStyle.opacity

                // Check for activeGradientDelta FIRST (for live preview during drag)
                if activeGradientDelta != nil && selectedObjectIDs.contains(shape.id) && activeColorTarget == .fill {
                    // Create a fillStyle with activeGradientDelta and opacity
                    let effectiveFillStyle = FillStyle(gradient: activeGradientDelta!, opacity: effectiveFillOpacity)
                    renderGradientToContext(gradient: activeGradientDelta!, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &context)
                } else if let gradient = fillStyle.gradient {
                    // Use gradient from snapshot
                    let effectiveFillStyle = FillStyle(gradient: gradient, opacity: effectiveFillOpacity)
                    renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &context)
                } else if fillStyle.color != .clear {
                    // Check for colorDeltaColor for live preview during drag
                    let effectiveFillColor = (colorDeltaColor != nil && selectedObjectIDs.contains(shape.id) && activeColorTarget == .fill)
                        ? colorDeltaColor!
                        : fillStyle.color
                    context.fill(Path(cgPath), with: .color(effectiveFillColor.color.opacity(effectiveFillOpacity)))
                }
            }

            // Render stroke (O(1) for solid, O(n) for gradient or placement strokes)
            // Stroke width stays constant regardless of scale transform
            if viewMode == .keyline {
                context.stroke(Path(cgPath), with: .color(.black), lineWidth: 1.0 / zoomLevel)
            } else if let strokeStyle = shape.strokeStyle {
                // Use delta values if available and shape is selected
                let isSelected = selectedObjectIDs.contains(shape.id)
                let effectiveStrokeOpacity = (strokeDeltaOpacity != nil && isSelected)
                    ? strokeDeltaOpacity!
                    : strokeStyle.opacity
                let effectiveStrokeWidth = (strokeDeltaWidth != nil && isSelected)
                    ? strokeDeltaWidth!
                    : strokeStyle.width

                if strokeStyle.placement == .center {
                    // Check for activeGradientDelta FIRST (for live preview during drag)
                    if activeGradientDelta != nil && isSelected && activeColorTarget == .stroke {
                        var effectiveStrokeStyle = strokeStyle
                        effectiveStrokeStyle.opacity = effectiveStrokeOpacity
                        effectiveStrokeStyle.width = effectiveStrokeWidth
                        renderGradientToContext(gradient: activeGradientDelta!, path: cgPath, isStroke: true, strokeStyle: effectiveStrokeStyle, in: &context)
                    } else if let gradient = strokeStyle.gradient {
                        // Create a strokeStyle with effective values for gradients
                        var effectiveStrokeStyle = strokeStyle
                        effectiveStrokeStyle.opacity = effectiveStrokeOpacity
                        effectiveStrokeStyle.width = effectiveStrokeWidth
                        renderGradientToContext(gradient: gradient, path: cgPath, isStroke: true, strokeStyle: effectiveStrokeStyle, in: &context)
                    } else if strokeStyle.color != .clear {
                        // Check for colorDeltaColor for live preview during drag
                        let effectiveStrokeColor = (colorDeltaColor != nil && isSelected && activeColorTarget == .stroke)
                            ? colorDeltaColor!
                            : strokeStyle.color
                        context.stroke(
                            Path(cgPath),
                            with: .color(effectiveStrokeColor.color.opacity(effectiveStrokeOpacity)),
                            style: SwiftUI.StrokeStyle(
                                lineWidth: effectiveStrokeWidth,
                                lineCap: strokeStyle.lineCap.cgLineCap,
                                lineJoin: strokeStyle.lineJoin.cgLineJoin,
                                miterLimit: strokeStyle.miterLimit
                            )
                        )
                    }
                } else {
                    // Create a strokeStyle with effective values for placement strokes
                    var effectiveStrokeStyle = strokeStyle
                    effectiveStrokeStyle.opacity = effectiveStrokeOpacity
                    effectiveStrokeStyle.width = effectiveStrokeWidth
                    renderStrokeWithPlacement(strokeStyle: effectiveStrokeStyle, path: cgPath, in: &context)
                }
            }
        }
    }

    private func renderStrokeWithPlacement(strokeStyle: StrokeStyle, path: CGPath, in context: inout GraphicsContext) {
        // Use PathOperations.outlineStroke for inside/outside strokes
        // Stroke width stays constant (no scaling compensation needed)

        // Get the outlined stroke path
        guard let outlinedPath = PathOperations.outlineStroke(path: path, strokeStyle: strokeStyle) else {
            return
        }

        // Render the outlined path as a filled shape
        if let gradient = strokeStyle.gradient {
            // For outlined strokes, we treat it as a fill but still need stroke opacity
            // Pass isStroke: false since path is already outlined, but pass strokeStyle for opacity
            renderGradientToContext(gradient: gradient, path: outlinedPath, isStroke: false, strokeStyle: strokeStyle, fillStyle: nil, in: &context)
        } else if strokeStyle.color != .clear {
            // Simple fill using SwiftUI's Path
            context.fill(
                Path(outlinedPath),
                with: .color(strokeStyle.color.color.opacity(strokeStyle.opacity))
            )
        }
    }

    private func renderGradientToContext(gradient: VectorGradient, path: CGPath, isStroke: Bool, strokeStyle: StrokeStyle?, fillStyle: FillStyle? = nil, in context: inout GraphicsContext) {
        // Paint gradient directly to CGContext (like we do for CoreText)
        context.withCGContext { cgContext in
            cgContext.saveGState()

            // Apply opacity based on whether we have fillStyle or strokeStyle
            // Note: For outlined strokes, isStroke is false but we still use strokeStyle
            if let fillStyle = fillStyle {
                cgContext.setAlpha(CGFloat(fillStyle.opacity))
            } else if let strokeStyle = strokeStyle {
                cgContext.setAlpha(CGFloat(strokeStyle.opacity))
            }

            // Create stroked path if needed
            let finalPath: CGPath
            if isStroke, let strokeStyle = strokeStyle {
                // Stroke width stays constant (no scaling compensation)
                cgContext.setLineWidth(strokeStyle.width)
                cgContext.setLineCap(strokeStyle.lineCap.cgLineCap)
                cgContext.setLineJoin(strokeStyle.lineJoin.cgLineJoin)
                cgContext.setMiterLimit(strokeStyle.miterLimit)
                cgContext.addPath(path)
                cgContext.replacePathWithStrokedPath()
                finalPath = cgContext.path ?? path
            } else {
                finalPath = path
            }

            // Render gradient directly
            renderCGGradientFill(gradient: gradient, path: finalPath, in: cgContext)

            cgContext.restoreGState()
        }
    }

    // MARK: - Optimized Gradient Rendering

    private func renderCGGradientFill(gradient: VectorGradient, path: CGPath, in cgContext: CGContext) {
        cgContext.saveGState()

        // Fast path bounds calculation (O(1))
        let pathBounds = path.boundingBoxOfPath

        // Optimize color conversion - avoid creating new color objects (O(n) where n = stops)
        let colors: [CGColor] = gradient.stops.map { stop in
            if case .clear = stop.color {
                return stop.color.cgColor
            }
            // Direct CGColor creation is faster than SwiftUI Color wrapper
            return stop.color.color.opacity(stop.opacity).cgColor ?? stop.color.cgColor
        }
        let locations: [CGFloat] = gradient.stops.map { CGFloat($0.position) }

        // Create gradient once (O(n) where n = stops)
        guard let cgGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: locations
        ) else {
            cgContext.restoreGState()
            return
        }

        // Clip once (O(1))
        cgContext.addPath(path)
        cgContext.clip()

        // Render gradient based on type
        switch gradient {
        case .linear(let linear):
            // Pre-calculate common values (O(1))
            let scale = CGFloat(linear.scaleX)
            let originX = linear.originPoint.x * scale
            let originY = linear.originPoint.y * scale
            let centerX = pathBounds.minX + pathBounds.width * originX
            let centerY = pathBounds.minY + pathBounds.height * originY
            let angle = CGFloat(linear.storedAngle * .pi / 180.0)

            // SIMD-optimized gradient calculations
            let startVec = SIMD2<Double>(Double(linear.startPoint.x), Double(linear.startPoint.y))
            let endVec = SIMD2<Double>(Double(linear.endPoint.x), Double(linear.endPoint.y))
            let delta = endVec - startVec
            let length = simd_length(delta) * scale * max(pathBounds.width, pathBounds.height)

            let halfLength = length / 2
            let angleVec = SIMD2<Double>(cos(Double(angle)), sin(Double(angle)))
            let centerVec = SIMD2<Double>(Double(centerX), Double(centerY))

            let startVec2 = centerVec - angleVec * halfLength
            let endVec2 = centerVec + angleVec * halfLength

            let start = CGPoint(x: startVec2.x, y: startVec2.y)
            let end = CGPoint(x: endVec2.x, y: endVec2.y)

            cgContext.drawLinearGradient(
                cgGradient,
                start: start,
                end: end,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )

        case .radial(let radial):
            let center = CGPoint(
                x: pathBounds.minX + pathBounds.width * radial.originPoint.x,
                y: pathBounds.minY + pathBounds.height * radial.originPoint.y
            )

            cgContext.saveGState()
            cgContext.translateBy(x: center.x, y: center.y)
            cgContext.rotate(by: CGFloat(radial.angle * .pi / 180.0))
            cgContext.scaleBy(x: CGFloat(radial.scaleX), y: CGFloat(radial.scaleY))

            let focalPoint = radial.focalPoint.map { CGPoint(x: $0.x, y: $0.y) } ?? .zero
            let radius = max(pathBounds.width, pathBounds.height) * CGFloat(radial.radius)

            cgContext.drawRadialGradient(
                cgGradient,
                startCenter: focalPoint,
                startRadius: 0,
                endCenter: .zero,
                endRadius: radius,
                options: [.drawsAfterEndLocation]
            )

            cgContext.restoreGState()
        }

        cgContext.restoreGState()
    }

    // MARK: - Optimized Text Rendering

    private func renderText(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, liveScaleTransform: CGAffineTransform = .identity, fontSizeDelta: Double? = nil, lineSpacingDelta: Double? = nil, lineHeightDelta: Double? = nil, letterSpacingDelta: Double? = nil, fillDeltaOpacity: Double? = nil, strokeDeltaOpacity: Double? = nil, strokeDeltaWidth: Double? = nil, textContentDelta: (id: UUID, content: String)? = nil, maskShape: VectorShape? = nil) {
        // Fast validation (O(1))
        guard let vectorText = VectorText.from(shape) else { return }

        // Use delta content if available and matching this shape
        let effectiveContent: String
        if let delta = textContentDelta, delta.id == shape.id && !delta.content.isEmpty {
            effectiveContent = delta.content
        } else if !vectorText.content.isEmpty {
            effectiveContent = vectorText.content
        } else {
            return
        }

        // Drag delta is now applied at canvas level, not per-object

        context.withCGContext { cgContext in
            cgContext.saveGState()

            // Apply clipping mask if provided
            if let maskShape = maskShape {
                let maskPath = maskShape.cachedCGPath
                cgContext.addPath(maskPath)
                cgContext.clip()
            }

            // Apply live fill opacity delta if dragging and selected
            let effectiveFillOpacity = (fillDeltaOpacity != nil && isSelected)
                ? fillDeltaOpacity!
                : vectorText.typography.fillOpacity

            cgContext.setAlpha(CGFloat(effectiveFillOpacity))

            // Apply live typography deltas if dragging and selected
            let effectiveFontSize: CGFloat
            let effectiveLineHeight: CGFloat
            let effectiveLineSpacing: CGFloat
            let effectiveLetterSpacing: CGFloat

            if isSelected {
                // Font size
                effectiveFontSize = if let delta = fontSizeDelta {
                    CGFloat(delta)
                } else {
                    vectorText.typography.fontSize
                }

                // Line height (explicit delta overrides proportional)
                if let delta = lineHeightDelta {
                    effectiveLineHeight = CGFloat(delta)
                } else if let fontDelta = fontSizeDelta {
                    // Proportional line height based on font size delta
                    let lineHeightRatio = vectorText.typography.lineHeight / vectorText.typography.fontSize
                    effectiveLineHeight = CGFloat(fontDelta) * lineHeightRatio
                } else {
                    effectiveLineHeight = vectorText.typography.lineHeight
                }

                // Line spacing delta
                effectiveLineSpacing = if let delta = lineSpacingDelta {
                    CGFloat(delta)
                } else {
                    vectorText.typography.lineSpacing
                }

                // Letter spacing delta
                effectiveLetterSpacing = if let delta = letterSpacingDelta {
                    CGFloat(delta)
                } else {
                    vectorText.typography.letterSpacing
                }
            } else {
                effectiveFontSize = vectorText.typography.fontSize
                effectiveLineHeight = vectorText.typography.lineHeight
                effectiveLineSpacing = vectorText.typography.lineSpacing
                effectiveLetterSpacing = vectorText.typography.letterSpacing
            }

            // Create PlatformFont with effective size
            let nsFont: PlatformFont = {
                if let variant = vectorText.typography.fontVariant {
                    let fontManager = NSFontManager.shared
                    let members = fontManager.availableMembers(ofFontFamily: vectorText.typography.fontFamily) ?? []

                    for member in members {
                        if let postScriptName = member[0] as? String,
                           let displayName = member[1] as? String,
                           displayName == variant {
                            if let font = PlatformFont(name: postScriptName, size: effectiveFontSize) {
                                return font
                            }
                        }
                    }
                }

                return PlatformFont(name: vectorText.typography.fontFamily, size: effectiveFontSize) ?? PlatformFont.systemFont(ofSize: effectiveFontSize)
            }()

            // Build paragraph style once (O(1))
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = vectorText.typography.alignment.nsTextAlignment
            paragraphStyle.lineSpacing = max(0, effectiveLineSpacing)
            paragraphStyle.minimumLineHeight = effectiveLineHeight
            paragraphStyle.maximumLineHeight = effectiveLineHeight

            let textColor = NSColor(cgColor: vectorText.typography.fillColor.cgColor) ?? .black

            // Shared attributes to avoid duplicate dictionary creation
            let commonAttributes: [NSAttributedString.Key: Any] = [
                .font: nsFont,
                .paragraphStyle: paragraphStyle,
                .kern: effectiveLetterSpacing
            ]

            // Create layout system once (O(n) where n = text length)
            let attributedString = NSAttributedString(string: effectiveContent, attributes: commonAttributes)
            let textStorage = NSTextStorage(attributedString: attributedString)
            let layoutManager = NSLayoutManager()
            textStorage.addLayoutManager(layoutManager)

            // Calculate text box width - use scaled width during live preview for reflow
            var textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
            var textPosition = vectorText.position

            if liveScaleTransform != .identity {
                // Apply live scale transform to get new dimensions and position
                let originalBounds = CGRect(
                    x: vectorText.position.x,
                    y: vectorText.position.y,
                    width: textBoxWidth,
                    height: vectorText.areaSize?.height ?? vectorText.bounds.height
                )
                let scaledBounds = originalBounds.applying(liveScaleTransform)
                textBoxWidth = scaledBounds.width
                textPosition = CGPoint(x: scaledBounds.minX, y: scaledBounds.minY)
            }

            let textContainer = NSTextContainer(size: CGSize(width: textBoxWidth, height: .greatestFiniteMagnitude))
            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = .byWordWrapping
            layoutManager.addTextContainer(textContainer)

            // Layout glyphs once (O(n))
            let textRange = NSRange(location: 0, length: effectiveContent.count)
            layoutManager.ensureGlyphs(forGlyphRange: textRange)
            layoutManager.ensureLayout(for: textContainer)

            // Rendering attributes with color (reuse common attributes)
            var renderAttributes = commonAttributes
            renderAttributes[.foregroundColor] = textColor

            let glyphRange = layoutManager.glyphRange(for: textContainer)
            let textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)

            // Enumerate and draw lines (O(k) where k = number of lines)
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, lineUsedRect, _, lineRange, _ in
                let lineString = (effectiveContent as NSString).substring(with: lineRange)
                let lineAttribString = NSAttributedString(string: lineString, attributes: renderAttributes)
                var line = CTLineCreateWithAttributedString(lineAttribString)

                // Apply justification if needed
                if vectorText.typography.alignment.nsTextAlignment == .justified,
                   let justifiedLine = CTLineCreateJustifiedLine(line, 1.0, lineUsedRect.width) {
                    line = justifiedLine
                }

                // Calculate line position using scaled position during live preview
                let glyphLocation = layoutManager.location(forGlyphAt: lineRange.location)
                let lineX: CGFloat
                switch vectorText.typography.alignment.nsTextAlignment {
                case .left, .justified:
                    lineX = textPosition.x + lineUsedRect.origin.x + glyphLocation.x
                case .center, .right:
                    lineX = textPosition.x + lineRect.origin.x + glyphLocation.x
                default:
                    lineX = textPosition.x + lineUsedRect.origin.x + glyphLocation.x
                }
                let lineY = textPosition.y + lineRect.origin.y + glyphLocation.y

                // Draw line
                cgContext.saveGState()
                cgContext.textMatrix = textMatrix
                cgContext.textPosition = CGPoint(x: lineX, y: lineY)

                // Check if text has stroke
                if vectorText.typography.hasStroke && vectorText.typography.strokeWidth > 0 {
                    // Get glyphs and positions from CTLine to build path
                    let glyphRuns = CTLineGetGlyphRuns(line) as! [CTRun]
                    let textPath = CGMutablePath()

                    for run in glyphRuns {
                        let glyphCount = CTRunGetGlyphCount(run)
                        let glyphs = UnsafeMutablePointer<CGGlyph>.allocate(capacity: glyphCount)
                        let positions = UnsafeMutablePointer<CGPoint>.allocate(capacity: glyphCount)

                        CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), glyphs)
                        CTRunGetPositions(run, CFRangeMake(0, glyphCount), positions)

                        let attributes = CTRunGetAttributes(run) as NSDictionary
                        if let font = attributes[kCTFontAttributeName] as! CTFont? {
                            for i in 0..<glyphCount {
                                if let glyphPath = CTFontCreatePathForGlyph(font, glyphs[i], nil) {
                                    let transform = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                                    textPath.addPath(glyphPath, transform: transform)
                                }
                            }
                        }

                        glyphs.deallocate()
                        positions.deallocate()
                    }

                    // Apply deltas if selected
                    let effectiveStrokeWidth = (strokeDeltaWidth != nil && isSelected)
                        ? strokeDeltaWidth!
                        : vectorText.typography.strokeWidth
                    let effectiveStrokeOpacity = (strokeDeltaOpacity != nil && isSelected)
                        ? strokeDeltaOpacity!
                        : vectorText.typography.strokeOpacity

                    // Draw the path with fill and stroke
                    cgContext.saveGState()
                    cgContext.translateBy(x: lineX, y: lineY)
                    cgContext.concatenate(textMatrix)

                    // Draw fill first
                    cgContext.addPath(textPath)
                    cgContext.setFillColor(textColor.cgColor)
                    cgContext.setAlpha(CGFloat(effectiveFillOpacity))
                    cgContext.fillPath()

                    // Draw stroke (always center for text)
                    cgContext.addPath(textPath)
                    let strokeColor = NSColor(cgColor: vectorText.typography.strokeColor.cgColor) ?? .black
                    cgContext.setStrokeColor(strokeColor.cgColor)
                    cgContext.setLineWidth(effectiveStrokeWidth)
                    cgContext.setLineJoin(vectorText.typography.strokeLineJoin.cgLineJoin)
                    cgContext.setLineCap(.butt)
                    cgContext.setAlpha(CGFloat(effectiveStrokeOpacity))
                    cgContext.strokePath()

                    cgContext.restoreGState()
                } else {
                    // No stroke - just draw normally
                    CTLineDraw(line, cgContext)
                }

                cgContext.restoreGState()
            }

            cgContext.restoreGState()
        }
    }

    // MARK: - Optimized Image Rendering

    private func hasImageData(_ shape: VectorShape) -> Bool {
        return shape.embeddedImageData != nil || shape.linkedImagePath != nil
    }

    private func resolveLinkedImage(linkedPath: String, documentURL: URL?, bookmarkData: Data?, shapeID: UUID) -> CGImage? {
        // ONLY use bookmark data (security-scoped access required)
        guard let bookmarkData = bookmarkData else {
            print("❌ No bookmark data for image: \(linkedPath)")
            return nil
        }

        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI, .withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            print("❌ Failed to resolve bookmark for: \(linkedPath)")
            return nil
        }

        if isStale {
            print("⚠️ Bookmark is stale for: \(url.path)")
        }

        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sourceCGImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            print("❌ Failed to load image from bookmark URL: \(url.path)")
            return nil
        }

        // Force image into memory to break file reference
        let width = sourceCGImage.width
        let height = sourceCGImage.height
        let colorSpace = sourceCGImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = sourceCGImage.bitmapInfo

        if let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) {
            context.draw(sourceCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            if let memoryCGImage = context.makeImage() {
                return memoryCGImage
            }
        }

        return sourceCGImage
    }

    private func renderImage(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, scaleTransform: CGAffineTransform = .identity, maskShape: VectorShape? = nil, canvasSize: CGSize) {
        // Get render bounds
        let pathBounds = shape.path.cgPath.boundingBoxOfPath
        var renderBounds = pathBounds
        if scaleTransform != .identity {
            renderBounds = pathBounds.applying(scaleTransform)
        }
        if !shape.transform.isIdentity {
            renderBounds = renderBounds.applying(shape.transform)
        }

        // Check cache FIRST - if CGImage is cached, use it (NO disk I/O!)
        let image: CGImage
        if let cachedImage = document.imageStorage[shape.id] {
            image = cachedImage
        } else {
            // CACHE MISS - load from disk ONCE and cache it
            let sourceCGImage: CGImage?
            if let imageData = shape.embeddedImageData,
               let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                sourceCGImage = cgImage
            } else if let linkedPath = shape.linkedImagePath,
                      let resolvedImage = resolveLinkedImage(
                          linkedPath: linkedPath,
                          documentURL: documentURL,
                          bookmarkData: shape.linkedImageBookmarkData,
                          shapeID: shape.id
                      ) {
                sourceCGImage = resolvedImage
            } else {
                return
            }

            guard let cgImage = sourceCGImage else {
                return
            }

            // Downsample if quality < 1.0
            let finalImage: CGImage
            if imagePreviewQuality < 1.0 {
                let maxDimension = max(cgImage.width, cgImage.height)
                let targetSize = Int(Double(maxDimension) * imagePreviewQuality)
                let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
                let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                let aspectRatio = Double(cgImage.width) / Double(cgImage.height)
                let targetWidth: Int
                let targetHeight: Int
                if cgImage.width >= cgImage.height {
                    targetWidth = targetSize
                    targetHeight = Int(Double(targetSize) / aspectRatio)
                } else {
                    targetHeight = targetSize
                    targetWidth = Int(Double(targetSize) * aspectRatio)
                }
                guard let downsampleContext = CGContext(
                    data: nil,
                    width: targetWidth,
                    height: targetHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: targetWidth * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                ) else {
                    finalImage = cgImage
                    image = finalImage
                    return
                }
                downsampleContext.interpolationQuality = imageInterpolationQuality
                downsampleContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
                finalImage = downsampleContext.makeImage() ?? cgImage
            } else {
                finalImage = cgImage
            }

            // Cache the image (with quality applied)
            document.imageStorage[shape.id] = finalImage
            image = finalImage
        }

        // Check hash for debugging, but ALWAYS draw (Canvas clears every frame)
        let imageHash = ObjectIdentifier(image).hashValue
        let lastHash = document.lastDrawnImageHash[shape.id]

        if lastHash == imageHash {
        } else {
            document.lastDrawnImageHash[shape.id] = imageHash
        }

        // ALWAYS draw - Canvas clears every frame, we MUST redraw

        // Draw using CGContext
        context.withCGContext { cgContext in
            cgContext.saveGState()

            // Apply clipping mask if provided
            if let maskShape = maskShape {
                let maskPath = maskShape.cachedCGPath
                cgContext.addPath(maskPath)
                cgContext.clip()
            }

            // Apply opacity
            cgContext.setAlpha(CGFloat(shape.opacity))

            // Flip coordinate system for image rendering
            cgContext.translateBy(x: renderBounds.minX, y: renderBounds.maxY)
            cgContext.scaleBy(x: 1.0, y: -1.0)

            // Set rendering quality
            cgContext.interpolationQuality = imageInterpolationQuality

            // Draw the image
            cgContext.draw(image, in: CGRect(origin: .zero, size: renderBounds.size))

            cgContext.restoreGState()
        }
    }

}

struct IsolatedLayerView: View {
    let objectIDs: [UUID]  // Changed from objects array
    let document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let liveNudgeOffset: CGVector
    let dragPreviewTrigger: Bool
    let liveScaleTransform: CGAffineTransform
    let layerOpacity: Double
    let layerBlendMode: BlendMode
    let livePointPositions: [PointID: CGPoint]
    let liveHandlePositions: [HandleID: CGPoint]
    let fillDeltaOpacity: Double?
    let strokeDeltaOpacity: Double?
    let strokeDeltaWidth: Double?
    let colorDeltaColor: VectorColor?
    let colorDeltaOpacity: Double?
    @Binding var activeGradientDelta: VectorGradient?
    let activeColorTarget: ColorTarget
    @Binding var textContentDelta: (id: UUID, content: String)?
    let fontSizeDelta: Double?
    let lineSpacingDelta: Double?
    let lineHeightDelta: Double?
    let letterSpacingDelta: Double?
    let imagePreviewQuality: Double
    let imageTileSize: Int
    let imageInterpolationQuality: CGInterpolationQuality
    let liveCornerRadii: [Double]
    let selectedShapeIDForCornerRadius: UUID?
    let layerUpdateTrigger: UInt
    let isPanning: Bool  // For expanded viewport during pan

    // Helper to collect all text shapes (both top-level and grouped)
    private var editingTextShapes: [(id: UUID, dragDelta: CGPoint)] {
        // EARLY RETURN: Skip expensive iteration if we're not in text mode
        // This prevents 60fps calls during shape manipulation
        // TODO: Replace with document.hasEditingText property
        guard document.viewState.currentTool == .font else {
            return []
        }

        var shapes: [(id: UUID, dragDelta: CGPoint)] = []

        // print("🔍 collectEditingTextShapes: checking snapshot directly")

        // Fetch FRESH data from document.snapshot.objects
        for objectID in objectIDs {
            guard let freshObject = document.snapshot.objects[objectID],
                  freshObject.isVisible else { continue }

            switch freshObject.objectType {
            case .text(let shape):
                // Top-level text object
                // print("🔍 Found top-level text: id=\(shape.id), isEditing=\(shape.isEditing ?? false)")
                if let vectorText = VectorText.from(shape),
                   vectorText.getState(in: document) == .editing {
                    let isSelected = selectedObjectIDs.contains(shape.id)
                    let delta = isSelected ? dragPreviewDelta : .zero
                    shapes.append((id: shape.id, dragDelta: delta))
                }

            case .group(let groupShape):
                // print("🔍 Found group: id=\(groupShape.id), groupedShapes.count=\(groupShape.groupedShapes.count)")
                // Text objects inside groups
                for childShape in groupShape.groupedShapes {
                    if childShape.typography != nil {
                        // print("🔍 Found text in group: id=\(childShape.id), isEditing=\(childShape.isEditing ?? false)")
                    }
                    guard childShape.isVisible else { continue }
                    if let vectorText = VectorText.from(childShape),
                       vectorText.getState(in: document) == .editing {
                        // Check if child is individually selected or parent group is selected
                        let isChildSelected = selectedObjectIDs.contains(childShape.id)
                        let isParentSelected = selectedObjectIDs.contains(freshObject.id)
                        let delta = (isChildSelected || isParentSelected) ? dragPreviewDelta : .zero
                        shapes.append((id: childShape.id, dragDelta: delta))
                    }
                }

            default:
                break
            }
        }

        // print("🔍 Total editing texts found: \(shapes.count)")
        return shapes
    }

    var body: some View {
        //let _ = print("🎯 IsolatedLayerView.body: activeColorTarget=\(activeColorTarget), activeGradientDelta=\(activeGradientDelta != nil)")
        ZStack {
            // Render paths using Canvas (gradients and text still use SwiftUI)
            LayerCanvasView(
                objectIDs: objectIDs,
                document: document,
                documentURL: nil,  // TODO: Pass actual document URL from window?.representedURL
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                selectedObjectIDs: selectedObjectIDs,
                viewMode: viewMode,
                dragPreviewDelta: dragPreviewDelta,
                liveNudgeOffset: liveNudgeOffset,
                liveScaleTransform: liveScaleTransform,
                dragPreviewTrigger: dragPreviewTrigger,
                livePointPositions: livePointPositions,
                liveHandlePositions: liveHandlePositions,
                fillDeltaOpacity: fillDeltaOpacity,
                strokeDeltaOpacity: strokeDeltaOpacity,
                strokeDeltaWidth: strokeDeltaWidth,
                colorDeltaColor: colorDeltaColor,
                colorDeltaOpacity: colorDeltaOpacity,
                activeGradientDelta: $activeGradientDelta,
                isPanning: isPanning,
                activeColorTarget: activeColorTarget,
                textContentDelta: $textContentDelta,
                fontSizeDelta: fontSizeDelta,
                lineSpacingDelta: lineSpacingDelta,
                lineHeightDelta: lineHeightDelta,
                letterSpacingDelta: letterSpacingDelta,
                imagePreviewQuality: imagePreviewQuality,
                imageTileSize: imageTileSize,
                imageInterpolationQuality: imageInterpolationQuality,
                liveCornerRadii: liveCornerRadii,
                selectedShapeIDForCornerRadius: selectedShapeIDForCornerRadius,
                layerUpdateTrigger: layerUpdateTrigger
            )

            // For text editor - show NSTextView for all editing text (top-level and grouped)
            ForEach(editingTextShapes, id: \.id) { textInfo in
                ProfessionalTextCanvas(
                    document: document,
                    textObjectID: textInfo.id,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    dragPreviewDelta: textInfo.dragDelta,
                    dragPreviewTrigger: dragPreviewTrigger,
                    viewMode: viewMode,
                    letterSpacingDelta: letterSpacingDelta,
                    lineHeightDelta: lineHeightDelta,
                    fontSizeDelta: fontSizeDelta,
                    lineSpacingDelta: lineSpacingDelta,
                    textContentDelta: $textContentDelta
                )
                .allowsHitTesting(document.viewState.currentTool == .font)
            }
        }
        .opacity(layerOpacity)
        .blendMode(layerBlendMode.swiftUIBlendMode)
    }
}
