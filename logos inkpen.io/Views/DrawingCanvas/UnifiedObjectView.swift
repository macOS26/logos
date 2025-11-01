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
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let liveScaleTransform: CGAffineTransform
    let objectUpdateTrigger: UInt
    let dragPreviewTrigger: Bool

    var appState = AppState.shared

    // Pre-filter visible objects OUTSIDE Canvas body (O(n) once per objects change)
    private var visibleObjects: [VectorObject] {
        objects.filter { object in
            guard object.isVisible else { return false }
            return true
        }
    }

    var body: some View {
        Canvas { context, size in
            _ = objectUpdateTrigger
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
                    print("🔵 RENDERING CLIPGROUP: parent selected=\(isSelected), groupedShapes.count=\(clipGroupShape.groupedShapes.count)")
                    print("🔵 RENDERING CLIPGROUP: selectedObjectIDs=\(selectedObjectIDs)")
                    print("🔵 RENDERING CLIPGROUP: dragPreviewDelta=\(dragPreviewDelta)")

                    guard !clipGroupShape.groupedShapes.isEmpty else { break }
                    let maskShape = clipGroupShape.groupedShapes[0]
                    let contentShapes = Array(clipGroupShape.groupedShapes.dropFirst())

                    print("🔵 CLIPGROUP: maskShape.id=\(maskShape.id)")
                    for (idx, child) in contentShapes.enumerated() {
                        print("🔵 CLIPGROUP: contentShapes[\(idx)].id=\(child.id)")
                    }

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
                            renderShape(maskShape, context: &context, isSelected: isMaskSelected, scaleTransform: maskScaleTransform)

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

                                // Render with separate mask and content transforms
                                context.drawLayer { layerContext in
                                    // Apply mask transform and create clipping region
                                    layerContext.transform = maskTransform
                                    let maskPath = maskShape.cachedCGPath
                                    layerContext.clip(to: Path(maskPath))

                                    // Apply content transform and render content
                                    layerContext.transform = contentTransform

                                    if VectorText.from(contentShape) != nil {
                                        renderText(contentShape, context: &layerContext, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, maskShape: nil)
                                    } else if contentShape.embeddedImageData != nil {
                                        renderImage(contentShape, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil)
                                    } else {
                                        renderShape(contentShape, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil)
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
                                renderShape(maskShape, context: &context, isSelected: isMaskSelected, scaleTransform: maskScaleTransform)
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

                                if VectorText.from(contentShape) != nil {
                                    renderText(contentShape, context: &context, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity)
                                } else if contentShape.embeddedImageData != nil {
                                    renderImage(contentShape, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform)
                                } else {
                                    renderShape(contentShape, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform)
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

                            // Render with separate mask and content transforms
                            context.drawLayer { layerContext in
                                // Apply mask transform and create clipping region
                                layerContext.transform = maskTransform
                                let maskPath = maskShape.cachedCGPath
                                layerContext.clip(to: Path(maskPath))

                                // Apply content transform and render content
                                layerContext.transform = contentTransform

                                if VectorText.from(contentShape) != nil {
                                    renderText(contentShape, context: &layerContext, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, maskShape: nil)
                                } else if contentShape.embeddedImageData != nil {
                                    renderImage(contentShape, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil)
                                } else {
                                    renderShape(contentShape, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil)
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

                        if VectorText.from(childShape) != nil {
                            renderText(childShape, context: &context, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, maskShape: maskShape)
                        } else if childShape.embeddedImageData != nil {
                            renderImage(childShape, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: maskShape)
                        } else {
                            renderShape(childShape, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: maskShape)
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
                    renderShape(shape, context: &context, isSelected: isSelected, scaleTransform: shapeTransform, maskShape: maskShape)

                case .image(let shape):
                    let maskShape: VectorShape? = {
                        guard let maskID = shape.clippedByShapeID,
                              let maskObject = objectsDict[maskID] else {
                            return nil
                        }
                        return maskObject.shape
                    }()
                    renderImage(shape, context: &context, isSelected: isSelected, scaleTransform: shapeTransform, maskShape: maskShape)

                case .text(let shape):
                    let maskShape: VectorShape? = {
                        guard let maskID = shape.clippedByShapeID,
                              let maskObject = objectsDict[maskID] else {
                            return nil
                        }
                        return maskObject.shape
                    }()
                    // For text, pass liveScaleTransform so it can reflow (don't transform)
                    renderText(shape, context: &context, isSelected: isSelected, liveScaleTransform: isSelected ? liveScaleTransform : .identity, maskShape: maskShape)
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
                    if let gradient = fillStyle.gradient {
                        renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: fillStyle, in: &layerContext)
                    } else if fillStyle.color != .clear {
                        layerContext.fill(Path(cgPath), with: .color(fillStyle.color.color.opacity(fillStyle.opacity)))
                    }
                }

                // Render stroke (O(1) for solid, O(n) for gradient or placement strokes)
                if viewMode == .keyline {
                    layerContext.stroke(Path(cgPath), with: .color(.black), lineWidth: 1.0)
                } else if let strokeStyle = shape.strokeStyle {
                    if strokeStyle.placement == .center {
                        if let gradient = strokeStyle.gradient {
                            renderGradientToContext(gradient: gradient, path: cgPath, isStroke: true, strokeStyle: strokeStyle, in: &layerContext)
                        } else if strokeStyle.color != .clear {
                            layerContext.stroke(
                                Path(cgPath),
                                with: .color(strokeStyle.color.color.opacity(strokeStyle.opacity)),
                                style: SwiftUI.StrokeStyle(
                                    lineWidth: strokeStyle.width,
                                    lineCap: strokeStyle.lineCap.cgLineCap,
                                    lineJoin: strokeStyle.lineJoin.cgLineJoin,
                                    miterLimit: strokeStyle.miterLimit
                                )
                            )
                        }
                    } else {
                        renderStrokeWithPlacement(strokeStyle: strokeStyle, path: cgPath, in: &layerContext)
                    }
                }
            }
        } else {
            // No mask, render directly
            // Render fill (O(1) for solid, O(n) for gradient where n = stops)
            if viewMode == .color, let fillStyle = shape.fillStyle {
                if let gradient = fillStyle.gradient {
                    renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: fillStyle, in: &context)
                } else if fillStyle.color != .clear {
                    context.fill(Path(cgPath), with: .color(fillStyle.color.color.opacity(fillStyle.opacity)))
                }
            }

            // Render stroke (O(1) for solid, O(n) for gradient or placement strokes)
            // Stroke width stays constant regardless of scale transform
            if viewMode == .keyline {
                context.stroke(Path(cgPath), with: .color(.black), lineWidth: 1.0)
            } else if let strokeStyle = shape.strokeStyle {
                if strokeStyle.placement == .center {
                    if let gradient = strokeStyle.gradient {
                        renderGradientToContext(gradient: gradient, path: cgPath, isStroke: true, strokeStyle: strokeStyle, in: &context)
                    } else if strokeStyle.color != .clear {
                        context.stroke(
                            Path(cgPath),
                            with: .color(strokeStyle.color.color.opacity(strokeStyle.opacity)),
                            style: SwiftUI.StrokeStyle(
                                lineWidth: strokeStyle.width,
                                lineCap: strokeStyle.lineCap.cgLineCap,
                                lineJoin: strokeStyle.lineJoin.cgLineJoin,
                                miterLimit: strokeStyle.miterLimit
                            )
                        )
                    }
                } else {
                    renderStrokeWithPlacement(strokeStyle: strokeStyle, path: cgPath, in: &context)
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

    private func renderText(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, liveScaleTransform: CGAffineTransform = .identity, maskShape: VectorShape? = nil) {
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

            cgContext.setAlpha(CGFloat(vectorText.typography.fillOpacity))

            // Build paragraph style once (O(1))
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = vectorText.typography.alignment.nsTextAlignment
            paragraphStyle.lineSpacing = max(0, vectorText.typography.lineSpacing)
            paragraphStyle.minimumLineHeight = vectorText.typography.lineHeight
            paragraphStyle.maximumLineHeight = vectorText.typography.lineHeight

            let nsFont = vectorText.typography.nsFont
            let textColor = NSColor(cgColor: vectorText.typography.fillColor.cgColor) ?? .black

            // Shared attributes to avoid duplicate dictionary creation
            let commonAttributes: [NSAttributedString.Key: Any] = [
                .font: nsFont,
                .paragraphStyle: paragraphStyle,
                .kern: vectorText.typography.letterSpacing
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

    private func renderImage(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, scaleTransform: CGAffineTransform = .identity, maskShape: VectorShape? = nil) {
        // Fast validation (O(1))
        guard let imageData = shape.embeddedImageData else { return }
        guard let nsImage = NSImage(data: imageData) else { return }
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        // Drag delta is now applied at canvas level, not per-object

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

            // Get image bounds from path
            let pathBounds = shape.path.cgPath.boundingBoxOfPath

            // Apply scale transform if active
            var renderBounds = pathBounds
            if scaleTransform != .identity {
                renderBounds = pathBounds.applying(scaleTransform)
            }

            // Apply the shape's transform
            if !shape.transform.isIdentity {
                cgContext.concatenate(shape.transform)
            }

            // Flip coordinate system for image rendering
            cgContext.translateBy(x: renderBounds.minX, y: renderBounds.maxY)
            cgContext.scaleBy(x: 1.0, y: -1.0)

            // Set high-quality rendering
            cgContext.setAllowsAntialiasing(true)
            cgContext.setShouldAntialias(true)
            cgContext.interpolationQuality = .high

            // Draw the image
            cgContext.draw(cgImage, in: CGRect(origin: .zero, size: renderBounds.size))

            cgContext.restoreGState()
        }
    }

}

struct IsolatedLayerView: View {
    let objects: [VectorObject]
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

    var body: some View {
        ZStack {
            // Render paths using Canvas (gradients and text still use SwiftUI)
            LayerCanvasView(
                objects: objects,
                objectsDict: document.snapshot.objects,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                selectedObjectIDs: selectedObjectIDs,
                viewMode: viewMode,
                dragPreviewDelta: dragPreviewDelta,
                liveScaleTransform: liveScaleTransform,
                objectUpdateTrigger: objectUpdateTrigger,
                dragPreviewTrigger: dragPreviewTrigger
            )

            // For text editor only - filter .text objects first
            ForEach(objects.filter { object in
                guard object.isVisible else { return false }
                if case .text = object.objectType { return true }
                return false
            }, id: \.id) { object in
                if case .text(let shape) = object.objectType {
                    ProfessionalTextCanvas(
                        document: document,
                        textObjectID: shape.id,
                        dragPreviewDelta: dragPreviewDelta,
                        dragPreviewTrigger: dragPreviewTrigger,
                        viewMode: viewMode
                    )
                    .allowsHitTesting(document.viewState.currentTool == .font)
                }
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
