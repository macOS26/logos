import SwiftUI
import CoreGraphics

struct PasteboardBackgroundView: View {
    let pasteboardSize: CGSize
    let pasteboardOrigin: CGPoint
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        Canvas { context, size in
            let scaledRect = CGRect(
                x: pasteboardOrigin.x * zoomLevel + canvasOffset.x,
                y: pasteboardOrigin.y * zoomLevel + canvasOffset.y,
                width: pasteboardSize.width * zoomLevel,
                height: pasteboardSize.height * zoomLevel
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
            let scaledRect = CGRect(
                x: canvasOffset.x,
                y: canvasOffset.y,
                width: canvasSize.width * zoomLevel,
                height: canvasSize.height * zoomLevel
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
    let objects: [VectorObject]
    let objectsDict: [UUID: VectorObject]  // For looking up mask shapes
    let documentURL: URL?  // For resolving relative image paths
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let liveScaleTransform: CGAffineTransform
    let objectUpdateTrigger: UInt
    let dragPreviewTrigger: Bool
    let livePointPositions: [PointID: CGPoint]
    let liveHandlePositions: [HandleID: CGPoint]
    let fillDeltaOpacity: Double?
    let strokeDeltaOpacity: Double?
    let strokeDeltaWidth: Double?
    @Binding var activeGradientDelta: VectorGradient?
    let activeColorTarget: ColorTarget
    let fontSizeDelta: Double?
    let lineSpacingDelta: Double?
    let lineHeightDelta: Double?
    let letterSpacingDelta: Double?
    let imagePreviewQuality: Double
    let imageTileSize: Int

    var appState = AppState.shared

    // Pre-filter visible objects OUTSIDE Canvas body (O(n) once per objects change)
    private var visibleObjects: [VectorObject] {
        objects.filter { object in
            guard object.isVisible else { return false }
            return true
        }
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

    var body: some View {
        let _ = Self._printChanges()
        // let _ = print("🔵 LayerCanvasView.body: activeColorTarget=\(activeColorTarget), activeGradientDelta=\(activeGradientDelta != nil)")
        Canvas { context, size in
//            _ = objectUpdateTrigger
//            _ = activeGradientDelta  // Force redraw when gradient changes
//            _ = fillDeltaOpacity     // Force redraw when fill opacity changes
//            _ = strokeDeltaOpacity   // Force redraw when stroke opacity changes
//            _ = strokeDeltaWidth     // Force redraw when stroke width changes
//            _ = fontSizeDelta        // Force redraw when font size changes
//            _ = imagePreviewQuality  // Force redraw when image quality changes
//            _ = imageTileSize        // Force redraw when tile size changes

            // Apply base canvas transform (no drag delta)
            let baseTransform = CGAffineTransform.identity
                .translatedBy(x: canvasOffset.x, y: canvasOffset.y)
                .scaledBy(x: zoomLevel, y: zoomLevel)

            // Render objects in original stacking order
            // Selected objects share the same drag delta transform
            for object in visibleObjects {
                let isSelected = selectedObjectIDs.contains(object.id)

                // Apply selection transform (with drag delta) for selected objects
                // For liveScaleTransform, we apply it to the path geometry directly (not context)
                // to keep stroke width constant while scaling the shape
                let isTextObject = if case .text = object.objectType { true } else { false }

                if isSelected && dragPreviewDelta != .zero {
                    print("🔴 CANVAS TRANSFORM: Applying dragPreviewDelta=\(dragPreviewDelta) to selected image")
                    context.transform = baseTransform
                        .translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
                } else {
                    context.transform = baseTransform
                }

                // Pass liveScaleTransform to renderShape so it can apply it to the path geometry
                // This keeps stroke width constant during scaling
                let shapeTransform = (isSelected && !isTextObject) ? liveScaleTransform : .identity

                switch object.objectType {
                case .clipGroup(let clipGroupShape):
                    // ClipGroup: first grouped shape is the mask, rest are clipped content
                    // print("🔵 RENDERING CLIPGROUP: parent selected=\(isSelected), groupedShapes.count=\(clipGroupShape.groupedShapes.count)")
                    // print("🔵 RENDERING CLIPGROUP: selectedObjectIDs=\(selectedObjectIDs)")
                    // print("🔵 RENDERING CLIPGROUP: dragPreviewDelta=\(dragPreviewDelta)")

                    guard !clipGroupShape.groupedShapes.isEmpty else { break }
                    let maskShape = clipGroupShape.groupedShapes[0]
                    let contentShapes = Array(clipGroupShape.groupedShapes.dropFirst())

                    // print("🔵 CLIPGROUP: maskShape.id=\(maskShape.id)")
                    // for (idx, child) in contentShapes.enumerated() {
                    //     print("🔵 CLIPGROUP: contentShapes[\(idx)].id=\(child.id)")
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
                                baseTransform.translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
                            } else {
                                parentTransform
                            }

                            // Render mask outline
                            context.transform = maskTransform
                            let maskScaleTransform = isMaskSelected ? liveScaleTransform : .identity
                            let liveMaskShape = applyLivePositions(to: maskShape)
                            renderShape(liveMaskShape, context: &context, isSelected: isMaskSelected, scaleTransform: maskScaleTransform)

                            // Then render content shapes clipped by the mask
                            for contentShape in contentShapes {
                                guard contentShape.isVisible else { continue }
                                let isChildSelected = selectedObjectIDs.contains(contentShape.id)
                                let isChildText = contentShape.typography != nil

                                // Determine content transform (independent of mask)
                                let contentTransform = if isChildSelected && dragPreviewDelta != .zero {
                                    baseTransform.translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
                                } else {
                                    parentTransform
                                }

                                let childScaleTransform = (isChildSelected && !isChildText) ? liveScaleTransform : .identity

                                let liveContentShape = applyLivePositions(to: contentShape)
                                let liveMaskForClip = applyLivePositions(to: maskShape)

                                // Render with separate mask and content transforms
                                context.drawLayer { layerContext in
                                    // Apply mask transform and create clipping region
                                    layerContext.transform = maskTransform
                                    let maskPath = liveMaskForClip.cachedCGPath
                                    layerContext.clip(to: Path(maskPath))

                                    // Apply content transform and render content
                                    layerContext.transform = contentTransform

                                    if VectorText.from(liveContentShape) != nil {
                                        renderText(liveContentShape, context: &layerContext, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, maskShape: nil)
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
                                    context.transform = baseTransform.translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
                                } else {
                                    context.transform = parentTransform  // Preserve parent's drag delta
                                }
                                let maskScaleTransform = isMaskSelected ? liveScaleTransform : .identity
                                let liveMaskShapeNoClip = applyLivePositions(to: maskShape)
                                renderShape(liveMaskShapeNoClip, context: &context, isSelected: isMaskSelected, scaleTransform: maskScaleTransform)
                            }
                            for contentShape in contentShapes {
                                guard contentShape.isVisible else { continue }
                                let isChildSelected = selectedObjectIDs.contains(contentShape.id)
                                let isChildText = contentShape.typography != nil

                                if isChildSelected && dragPreviewDelta != .zero {
                                    context.transform = baseTransform.translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
                                } else {
                                    context.transform = parentTransform  // Preserve parent's drag delta
                                }
                                let childScaleTransform = (isChildSelected && !isChildText) ? liveScaleTransform : .identity

                                let liveContentNoClip = applyLivePositions(to: contentShape)

                                if VectorText.from(liveContentNoClip) != nil {
                                    renderText(liveContentNoClip, context: &context, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity)
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
                            baseTransform.translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
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
                                baseTransform.translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
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
                                    renderText(liveContentColorMode, context: &layerContext, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, maskShape: nil)
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
                                .translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
                        } else {
                            context.transform = parentTransform  // Preserve parent's drag delta
                        }

                        // Use child-specific selection state for scale transform
                        let childScaleTransform = (isChildSelected && !isChildText) ? liveScaleTransform : .identity

                        // Check if child itself is clipped by another object
                        let maskShape: VectorShape? = {
                            guard let maskID = childShape.clippedByShapeID,
                                  let maskObject = objectsDict[maskID] else {
                                return nil
                            }
                            return maskObject.shape
                        }()

                        let liveChildShape = applyLivePositions(to: childShape)

                        if VectorText.from(liveChildShape) != nil {
                            renderText(liveChildShape, context: &context, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, maskShape: maskShape)
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
                              let maskObject = objectsDict[maskID] else {
                            return nil
                        }
                        return maskObject.shape
                    }()
                    let liveShape = applyLivePositions(to: shape)
                    renderShape(liveShape, context: &context, isSelected: isSelected, scaleTransform: shapeTransform, maskShape: maskShape)

                case .image(let shape):
                    let maskShape: VectorShape? = {
                        guard let maskID = shape.clippedByShapeID,
                              let maskObject = objectsDict[maskID] else {
                            return nil
                        }
                        return maskObject.shape
                    }()
                    let liveImageShape = applyLivePositions(to: shape)
                    renderImage(liveImageShape, context: &context, isSelected: isSelected, scaleTransform: shapeTransform, maskShape: maskShape, canvasSize: size)

                case .text(let shape):
                    let maskShape: VectorShape? = {
                        guard let maskID = shape.clippedByShapeID,
                              let maskObject = objectsDict[maskID] else {
                            return nil
                        }
                        return maskObject.shape
                    }()
                    let liveTextShape = applyLivePositions(to: shape)
                    // For text, pass liveScaleTransform so it can reflow (don't transform)
                    renderText(liveTextShape, context: &context, isSelected: isSelected, liveScaleTransform: isSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, maskShape: maskShape)
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

                    print("🔴 FILL RENDER: shape=\(shape.id), activeGradientDelta=\(activeGradientDelta != nil), isSelected=\(selectedObjectIDs.contains(shape.id)), activeColorTarget=\(activeColorTarget)")

                    // Check for activeGradientDelta FIRST (for live preview during drag)
                    // ONLY apply gradient delta if activeColorTarget is .fill
                    if activeGradientDelta != nil && selectedObjectIDs.contains(shape.id) && activeColorTarget == .fill {
                        print("🎨 FILL: Using activeGradientDelta for shape \(shape.id), activeColorTarget=\(activeColorTarget)")
                        print("🎨 FILL: Delta stops: \(activeGradientDelta!.stops.map { $0.color })")

                        // Create a fillStyle with activeGradientDelta and opacity
                        let effectiveFillStyle = FillStyle(gradient: activeGradientDelta!, opacity: effectiveFillOpacity)
                        renderGradientToContext(gradient: activeGradientDelta!, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &layerContext)
                    } else if let gradient = fillStyle.gradient {
                        // Use gradient from snapshot
                        print("🎨 FILL: Using SNAPSHOT gradient for shape \(shape.id)")
                        print("🎨 FILL: Snapshot gradient stops: \(gradient.stops.map { $0.color })")
                        let effectiveFillStyle = FillStyle(gradient: gradient, opacity: effectiveFillOpacity)
                        renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &layerContext)
                    } else if fillStyle.color != .clear {
                        // print("🎨 CANVAS RENDER: Using SOLID color for shape \(shape.id): \(fillStyle.color)")
                        layerContext.fill(Path(cgPath), with: .color(fillStyle.color.color.opacity(effectiveFillOpacity)))
                    } else {
                        // print("🎨 CANVAS RENDER: Using CLEAR (no fill) for shape \(shape.id)")
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
                        print("🟢 STROKE RENDER: shape=\(shape.id), activeGradientDelta=\(activeGradientDelta != nil), isSelected=\(isSelected), activeColorTarget=\(activeColorTarget)")

                        // Check for activeGradientDelta FIRST (for live preview during drag)
                        // ONLY apply gradient delta if activeColorTarget is .stroke
                        if activeGradientDelta != nil && isSelected && activeColorTarget == .stroke {
                            print("🎨 STROKE: Using activeGradientDelta for shape \(shape.id), activeColorTarget=\(activeColorTarget)")
                            print("🎨 STROKE: Delta stops: \(activeGradientDelta!.stops.map { $0.color })")
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
                            print("🎨 STROKE: Using SNAPSHOT gradient for shape \(shape.id)")
                            print("🎨 STROKE: Snapshot gradient stops: \(gradient.stops.map { $0.color })")
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
                            layerContext.stroke(
                                Path(cgPath),
                                with: .color(strokeStyle.color.color.opacity(effectiveStrokeOpacity)),
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
                    print("🎨 CANVAS RENDER (no mask): Using activeGradientDelta for FILL shape \(shape.id)")

                    // Create a fillStyle with activeGradientDelta and opacity
                    let effectiveFillStyle = FillStyle(gradient: activeGradientDelta!, opacity: effectiveFillOpacity)
                    renderGradientToContext(gradient: activeGradientDelta!, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &context)
                } else if let gradient = fillStyle.gradient {
                    // Use gradient from snapshot
                    let effectiveFillStyle = FillStyle(gradient: gradient, opacity: effectiveFillOpacity)
                    renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &context)
                } else if fillStyle.color != .clear {
                    context.fill(Path(cgPath), with: .color(fillStyle.color.color.opacity(effectiveFillOpacity)))
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
                        print("🎨 CANVAS RENDER (no mask): Using activeGradientDelta for STROKE shape \(shape.id)")
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
                        context.stroke(
                            Path(cgPath),
                            with: .color(strokeStyle.color.color.opacity(effectiveStrokeOpacity)),
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

            let dx = linear.endPoint.x - linear.startPoint.x
            let dy = linear.endPoint.y - linear.startPoint.y
            let length = sqrt(dx * dx + dy * dy) * scale * max(pathBounds.width, pathBounds.height)

            let halfLength = length / 2
            let cosAngle = cos(angle)
            let sinAngle = sin(angle)

            let start = CGPoint(
                x: centerX - cosAngle * halfLength,
                y: centerY - sinAngle * halfLength
            )
            let end = CGPoint(
                x: centerX + cosAngle * halfLength,
                y: centerY + sinAngle * halfLength
            )

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

    private func renderText(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, liveScaleTransform: CGAffineTransform = .identity, fontSizeDelta: Double? = nil, lineSpacingDelta: Double? = nil, lineHeightDelta: Double? = nil, letterSpacingDelta: Double? = nil, fillDeltaOpacity: Double? = nil, maskShape: VectorShape? = nil) {
        // Fast validation (O(1))
        guard let vectorText = VectorText.from(shape) else { return }
        guard !vectorText.content.isEmpty else { return }

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

            // Create NSFont with effective size
            let nsFont: NSFont = {
                if let variant = vectorText.typography.fontVariant {
                    let fontManager = NSFontManager.shared
                    let members = fontManager.availableMembers(ofFontFamily: vectorText.typography.fontFamily) ?? []

                    for member in members {
                        if let postScriptName = member[0] as? String,
                           let displayName = member[1] as? String,
                           displayName == variant {
                            if let font = NSFont(name: postScriptName, size: effectiveFontSize) {
                                return font
                            }
                        }
                    }
                }

                return NSFont(name: vectorText.typography.fontFamily, size: effectiveFontSize) ?? NSFont.systemFont(ofSize: effectiveFontSize)
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
            let attributedString = NSAttributedString(string: vectorText.content, attributes: commonAttributes)
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
            let textRange = NSRange(location: 0, length: vectorText.content.count)
            layoutManager.ensureGlyphs(forGlyphRange: textRange)
            layoutManager.ensureLayout(for: textContainer)

            // Rendering attributes with color (reuse common attributes)
            var renderAttributes = commonAttributes
            renderAttributes[.foregroundColor] = textColor

            let glyphRange = layoutManager.glyphRange(for: textContainer)
            let textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)

            // Enumerate and draw lines (O(k) where k = number of lines)
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, lineUsedRect, _, lineRange, _ in
                let lineString = (vectorText.content as NSString).substring(with: lineRange)
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
                CTLineDraw(line, cgContext)
                cgContext.restoreGState()
            }

            cgContext.restoreGState()
        }
    }

    // MARK: - Optimized Image Rendering

    private func hasImageData(_ shape: VectorShape) -> Bool {
        return shape.embeddedImageData != nil || shape.linkedImagePath != nil
    }

    private func resolveAndGetSourceImage(linkedPath: String, documentURL: URL?, bookmarkData: Data?, shapeID: UUID, quality: Double) -> CGImage? {
        // 1. Try bookmark data first
        if let bookmarkData = bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                let _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                if let image = ImageTileCache.shared.getSourceImage(from: url, quality: quality) {
                    return image
                }
            }
        }

        // 2. Try absolute path
        let absoluteURL = URL(fileURLWithPath: linkedPath)
        if let image = ImageTileCache.shared.getSourceImage(from: absoluteURL, quality: quality) {
            return image
        }

        // 3. Try relative to document
        if let docURL = documentURL {
            let docDir = docURL.deletingLastPathComponent()
            let relativeURL = docDir.appendingPathComponent(linkedPath)
            if let image = ImageTileCache.shared.getSourceImage(from: relativeURL, quality: quality) {
                return image
            }
        }

        // 4. Try next to document
        if let docURL = documentURL {
            let docDir = docURL.deletingLastPathComponent()
            let filename = URL(fileURLWithPath: linkedPath).lastPathComponent
            let sameDir = docDir.appendingPathComponent(filename)
            if let image = ImageTileCache.shared.getSourceImage(from: sameDir, quality: quality) {
                return image
            }
        }

        // 5. Image not found
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("MissingLinkedImage"),
                object: nil,
                userInfo: ["shapeID": shapeID, "path": linkedPath]
            )
        }

        return nil
    }


    private func resolveLinkedImage(linkedPath: String, documentURL: URL?, bookmarkData: Data?, shapeID: UUID) -> NSImage? {
        // 1. Try bookmark data first (security-scoped access)
        if let bookmarkData = bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                let _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                if let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }

        // 2. Try absolute path
        if let image = NSImage(contentsOfFile: linkedPath) {
            return image
        }

        // 3. Try relative to document
        if let docURL = documentURL {
            let docDir = docURL.deletingLastPathComponent()
            let relativeURL = docDir.appendingPathComponent(linkedPath)
            if let image = NSImage(contentsOf: relativeURL) {
                return image
            }
        }

        // 4. Try next to document (same directory, just filename)
        if let docURL = documentURL {
            let docDir = docURL.deletingLastPathComponent()
            let filename = URL(fileURLWithPath: linkedPath).lastPathComponent
            let sameDir = docDir.appendingPathComponent(filename)
            if let image = NSImage(contentsOf: sameDir) {
                return image
            }
        }

        // 5. Image not found - notify so user can be prompted
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("MissingLinkedImage"),
                object: nil,
                userInfo: ["shapeID": shapeID, "path": linkedPath]
            )
        }

        return nil
    }

    private func renderImage(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, scaleTransform: CGAffineTransform = .identity, maskShape: VectorShape? = nil, canvasSize: CGSize) {
        print("🖼️ renderImage START: shapeID=\(shape.id), isSelected=\(isSelected)")
        print("   dragPreviewDelta=\(dragPreviewDelta)")
        print("   shape.transform=\(shape.transform)")
        print("   scaleTransform=\(scaleTransform)")

        // Get image bounds to check viewport culling
        let pathBounds = shape.path.cgPath.boundingBoxOfPath
        print("   pathBounds=\(pathBounds)")

        var renderBounds = pathBounds
        if scaleTransform != .identity {
            renderBounds = pathBounds.applying(scaleTransform)
            print("   Applied scaleTransform: renderBounds=\(renderBounds)")
        }
        if !shape.transform.isIdentity {
            renderBounds = renderBounds.applying(shape.transform)
            print("   Applied shape.transform: renderBounds=\(renderBounds)")
        }

        // Scale bounds to screen coordinates
        // NOTE: Do NOT add dragPreviewDelta here - it's already applied via canvas transform (line 189-194)
        let screenBounds = CGRect(
            x: renderBounds.origin.x * zoomLevel + canvasOffset.x,
            y: renderBounds.origin.y * zoomLevel + canvasOffset.y,
            width: renderBounds.width * zoomLevel,
            height: renderBounds.height * zoomLevel
        )
        print("   screenBounds=\(screenBounds)")

        // Use actual canvas size for viewport (from Canvas context)
        let viewportMargin: CGFloat = 500  // Extra margin for smooth scrolling
        let viewportRect = CGRect(
            x: -viewportMargin,
            y: -viewportMargin,
            width: canvasSize.width + viewportMargin * 2,
            height: canvasSize.height + viewportMargin * 2
        )

        // Viewport culling: Skip if image is completely outside visible area
        guard screenBounds.intersects(viewportRect) else {
            return
        }

        // Use cached CGImage if available (loaded once at document open)
        let sourceImage: CGImage?

        if let cachedImage = shape.cachedCGImage {
            sourceImage = cachedImage
        } else {
            // Fallback: load on-demand if not cached (shouldn't happen normally)
            if let imageData = shape.embeddedImageData {
                sourceImage = ImageTileCache.shared.getSourceImage(from: imageData, quality: imagePreviewQuality)
            } else if let linkedPath = shape.linkedImagePath {
                sourceImage = resolveAndGetSourceImage(
                    linkedPath: linkedPath,
                    documentURL: documentURL,
                    bookmarkData: shape.linkedImageBookmarkData,
                    shapeID: shape.id,
                    quality: imagePreviewQuality
                )
            } else {
                return
            }
        }

        guard let image = sourceImage else { return }

        // Get actual image pixel dimensions
        let imagePixelSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))

        // Calculate visible tiles
        let tileSize = imageTileSize
        let visibleTiles = ImageTileCache.shared.visibleTiles(
            imageRect: screenBounds,
            viewportRect: viewportRect,
            imageSize: imagePixelSize,
            canvasSize: renderBounds.size,
            tileSize: tileSize
        )

        guard !visibleTiles.isEmpty else { return }

        // Draw using CGContext with tiling
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

            // NOTE: Do NOT apply shape.transform here - it's already baked into renderBounds at line 1148-1150
            // Applying it again would cause double transformation

            // Flip coordinate system for image rendering
            print("   🔵 Translating by renderBounds: minX=\(renderBounds.minX), maxY=\(renderBounds.maxY)")
            cgContext.translateBy(x: renderBounds.minX, y: renderBounds.maxY)
            cgContext.scaleBy(x: 1.0, y: -1.0)

            // Set rendering quality
            cgContext.interpolationQuality = .medium

            // Use Metal to composite tiles on GPU at FULL IMAGE RESOLUTION, then draw result
            if let compositedImage = MetalImageTileRenderer.shared?.compositeImageTiles(
                   image: image,
                   tiles: visibleTiles,
                   outputSize: imagePixelSize,
                   shapeID: shape.id
               ) {
                // Draw the Metal-composited result in one draw call
                cgContext.draw(compositedImage, in: CGRect(origin: .zero, size: renderBounds.size))
            } else {
                // Fallback: draw full image without tiling
                cgContext.draw(image, in: CGRect(origin: .zero, size: renderBounds.size))
            }

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
    let dragPreviewTrigger: Bool
    let objectUpdateTrigger: UInt
    let liveScaleTransform: CGAffineTransform
    let layerOpacity: Double
    let layerBlendMode: BlendMode
    let livePointPositions: [PointID: CGPoint]
    let liveHandlePositions: [HandleID: CGPoint]
    let fillDeltaOpacity: Double?
    let strokeDeltaOpacity: Double?
    let strokeDeltaWidth: Double?
    @Binding var activeGradientDelta: VectorGradient?
    let activeColorTarget: ColorTarget
    let fontSizeDelta: Double?
    let lineSpacingDelta: Double?
    let lineHeightDelta: Double?
    let letterSpacingDelta: Double?
    let imagePreviewQuality: Double
    let imageTileSize: Int

    // Compute objects fresh from snapshot on every render
    private var objects: [VectorObject] {
        objectIDs.compactMap { document.snapshot.objects[$0] }
    }

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

        // Fetch FRESH data from document.snapshot.objects, not stale objects parameter
        for objectID in objects.map({ $0.id }) {
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
                    // print("✅ Adding top-level editing text: \(shape.id)")
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
                        // print("✅ Adding grouped editing text: \(childShape.id)")
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
        // let _ = print("🎯 IsolatedLayerView.body: activeColorTarget=\(activeColorTarget), activeGradientDelta=\(activeGradientDelta != nil)")
        ZStack {
            // Render paths using Canvas (gradients and text still use SwiftUI)
            LayerCanvasView(
                objects: objects,
                objectsDict: document.snapshot.objects,
                documentURL: nil,  // TODO: Pass actual document URL from window?.representedURL
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                selectedObjectIDs: selectedObjectIDs,
                viewMode: viewMode,
                dragPreviewDelta: dragPreviewDelta,
                liveScaleTransform: liveScaleTransform,
                objectUpdateTrigger: objectUpdateTrigger,
                dragPreviewTrigger: dragPreviewTrigger,
                livePointPositions: livePointPositions,
                liveHandlePositions: liveHandlePositions,
                fillDeltaOpacity: fillDeltaOpacity,
                strokeDeltaOpacity: strokeDeltaOpacity,
                strokeDeltaWidth: strokeDeltaWidth,
                activeGradientDelta: $activeGradientDelta,
                activeColorTarget: activeColorTarget,
                fontSizeDelta: fontSizeDelta,
                lineSpacingDelta: lineSpacingDelta,
                lineHeightDelta: lineHeightDelta,
                letterSpacingDelta: letterSpacingDelta,
                imagePreviewQuality: imagePreviewQuality,
                imageTileSize: imageTileSize
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
                    lineSpacingDelta: lineSpacingDelta
                )
                .allowsHitTesting(document.viewState.currentTool == .font)
            }
        }
        .opacity(layerOpacity)
        .blendMode(layerBlendMode.swiftUIBlendMode)
    }
}

struct CGOpacityModifier: ViewModifier {
    let opacity: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { _ in
                Color.clear.preference(key: OpacityPreferenceKey.self, value: opacity)
            }
        )
        .transformEffect(.identity)
        .opacity(Double(opacity))
    }
}

struct OpacityPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 1.0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
