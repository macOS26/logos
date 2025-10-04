//
//  LayerView+ShapeView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import SwiftUI

struct ShapeView: View {
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isSelected: Bool
    let viewMode: ViewMode
    let isCanvasLayer: Bool  // NEW: Canvas layer protection
    let isPasteboardLayer: Bool  // NEW: Pasteboard layer recognition
    let dragPreviewDelta: CGPoint  // NEW: 60fps drag preview offset
    let dragPreviewTrigger: Bool  // NEW: Trigger for efficient preview updates
    
    // CANVAS AND PASTEBOARD LAYER PROTECTION: Canvas and Pasteboard objects never go to keyline view
    private var effectiveViewMode: ViewMode {
        return (isCanvasLayer || isPasteboardLayer) ? .color : viewMode
    }
    
    var body: some View {
        ZStack {
            // GROUPED SHAPES RENDERING: If this is a group container, render all grouped shapes
            if shape.isGroupContainer {
                // CRITICAL FIX: Render grouped shapes WITHOUT zoom/offset (prevent double application)
                ZStack {
                    ForEach(shape.groupedShapes, id: \.id) { groupedShape in
                        // PERFORMANCE OPTIMIZATION: Create path only once per shape
                        let cachedPath = Path { path in
                            addPathElements(groupedShape.path.elements, to: &path)
                        }
                        
                        // Render shapes directly - NO coordinate system nesting
                        ZStack {
                            // Fill - only show in color view mode (or always for Canvas)
                            if effectiveViewMode == .color,
                               let fillStyle = groupedShape.fillStyle,
                                fillStyle.color != .clear {
                                renderFill(fillStyle: fillStyle, path: cachedPath, shape: groupedShape)
                            }
                            
                            // Stroke rendering - reuse the same cached path
                            if effectiveViewMode == .keyline {
                                cachedPath.stroke(Color.black, lineWidth: 1.0 / zoomLevel)
                            } else if let strokeStyle = groupedShape.strokeStyle, strokeStyle.color != .clear {
                                renderStrokeWithPlacement(shape: groupedShape, strokeStyle: strokeStyle, viewMode: effectiveViewMode, path: cachedPath)
                                    .opacity(strokeStyle.placement == .outside ? 1.0 : strokeStyle.opacity)
                                    .blendMode(strokeStyle.blendMode.swiftUIBlendMode)
                            }
                        }
                        // CRITICAL: Only apply individual shape transform - NO zoom/offset here
                        .transformEffect(groupedShape.transform)
                        .opacity(groupedShape.opacity)
                    }
                }
                // CRITICAL FIX: Let ShapeView handle zoom/offset - only apply group transform here
                .transformEffect(shape.transform) // PREVIEW SCALING: Use preview transform during scaling
                .onAppear {
                    
                    for (_, _) in shape.groupedShapes.enumerated() {
                    }
                }
            } else {
                // CHECK FOR SVG CONTENT FIRST
                if SVGToInkPenImporter.containsSVGContent(shape),
                   let svgData = SVGToInkPenImporter.getSVGData(for: shape) {
                    // RENDER SVG CONTENT using CoreSVG
                    SVGShapeRenderer(
                        svgDocument: svgData.document,
                        bounds: shape.bounds,
                        transform: shape.transform,
                        opacity: shape.opacity
                    )
                } else if ImageContentRegistry.containsImage(shape),
                          let image = ImageContentRegistry.image(for: shape.id) {
                    // RENDER RASTER IMAGE USING NSVIEW - FIXED POSITIONING
                    // FIXED: Match GradientNSView approach - use pre-transformed bounds
                    let pathBounds = shape.path.cgPath.boundingBoxOfPath
                    let transformedBounds = pathBounds.applying(shape.transform)
                    
                    ImageNSView(
                        image: image,
                        bounds: transformedBounds,
                        opacity: shape.opacity,
                        fillStyle: shape.fillStyle, // Pass fillStyle for image tinting
                        viewMode: effectiveViewMode // Pass view mode for keyline rendering
                    )
                    // CRITICAL FIX: For images with transforms, apply preview offset in canvas space
                    // This prevents the jumping effect when moving scaled/rotated images
                    .offset(x: isSelected ? dragPreviewDelta.x : 0,
                            y: isSelected ? dragPreviewDelta.y : 0)
                } else if shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                    // Attempt late hydration if not yet in registry
                    if let hydrated = ImageContentRegistry.hydrateImageIfAvailable(for: shape) {
                        // RENDER HYDRATED IMAGE USING NSVIEW - FIXED POSITIONING
                        // FIXED: Match GradientNSView approach - use pre-transformed bounds
                        let pathBounds = shape.path.cgPath.boundingBoxOfPath
                        let transformedBounds = pathBounds.applying(shape.transform)
                        
                        
                        
                        ImageNSView(
                            image: hydrated,
                            bounds: transformedBounds,
                            opacity: shape.opacity,
                            fillStyle: shape.fillStyle, // Pass fillStyle for image tinting
                            viewMode: effectiveViewMode // Pass view mode for keyline rendering
                        )
                        // CRITICAL FIX: For images with transforms, apply preview offset in canvas space
                        // This prevents the jumping effect when moving scaled/rotated images
                        .offset(x: isSelected ? dragPreviewDelta.x : 0,
                                y: isSelected ? dragPreviewDelta.y : 0)
                    } else {
                        // Optional visual placeholder (dashed rect) when link missing
                        let placeholder = Path(CGRect(origin: .zero, size: shape.bounds.size))
                        placeholder
                            .stroke(Color.gray.opacity(0.5), style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .transformEffect(shape.transform)
                    }
                } else {
                    // REGULAR SHAPE RENDERING: Pre-transform the path with caching
                    // PERFORMANCE OPTIMIZATION: Create path only once per shape
                    let originalPath = Path { path in
                        addPathElements(shape.path.elements, to: &path)
                    }
                    
                    // BAKE IN THE TRANSFORMATION for individual shapes (cached)
                    let finalPath = originalPath.applying(shape.transform)
                    
                    // Fill - use the cached pre-transformed path
                    if effectiveViewMode == .color,
                       let fillStyle = shape.fillStyle,
                       fillStyle.color != .clear {
                        renderFill(fillStyle: fillStyle, path: finalPath, shape: shape)
                    }
                    
                    // Stroke rendering - reuse the same cached pre-transformed path
                    if effectiveViewMode == .keyline {
                        finalPath.stroke(Color.black, lineWidth: 1.0 / zoomLevel)
                    } else if let strokeStyle = shape.strokeStyle, strokeStyle.color != .clear {
                        renderStrokeWithPlacement(shape: shape, strokeStyle: strokeStyle, viewMode: effectiveViewMode, path: finalPath)
                            .opacity(strokeStyle.placement == .outside ? 1.0 : strokeStyle.opacity)
                            .blendMode(strokeStyle.blendMode.swiftUIBlendMode)
                    }
                }
            }
            
            // INLINE SELECTION OUTLINE DISABLED: Selection outlines are handled by SelectionOutline below
            // This prevents duplicate outlines at high zoom.
        }
        // CRITICAL FIX: Apply transforms in CORRECT order - zoom and offset first
        .scaleEffect(zoomLevel, anchor: .topLeading)
        .offset(x: canvasOffset.x, y: canvasOffset.y)
        // CRITICAL FIX: Apply shape transform for groups only
        // Groups: transform is handled inside the group rendering block
        // Images: transform is handled by ImageNSView itself
        // Regular shapes: transform is BAKED INTO the path
        .transformEffect(shape.isGroupContainer ? shape.transform : .identity)
        // ULTRA FAST 60FPS: Apply drag preview offset - trigger ensures efficient updates
        // CRITICAL FIX: For images, the preview offset is applied at the ImageNSView level in canvas space
        // For other shapes, apply the offset at the view level in screen space
        .offset(x: isSelected && !ImageContentRegistry.containsImage(shape) ? dragPreviewDelta.x * zoomLevel : 0,
                y: isSelected && !ImageContentRegistry.containsImage(shape) ? dragPreviewDelta.y * zoomLevel : 0)
        .id(dragPreviewTrigger) // Force efficient re-render when trigger changes
        .opacity(shape.opacity)
    }
    
    @ViewBuilder
    private func renderStrokeWithPlacement(shape: VectorShape, strokeStyle: StrokeStyle, viewMode: ViewMode, path: Path) -> some View {
        let swiftUIStrokeStyle = SwiftUI.StrokeStyle(
            lineWidth: strokeStyle.width,
            lineCap: strokeStyle.lineCap.cgLineCap.swiftUILineCap,
            lineJoin: strokeStyle.lineJoin.cgLineJoin.swiftUILineJoin,
            miterLimit: strokeStyle.miterLimit,
            dash: strokeStyle.dashPattern.map { CGFloat($0) }
        )
        
        switch strokeStyle.placement {
        case .center:
            // Default behavior - stroke is centered on the path
            renderStrokeColor(strokeStyle: strokeStyle, path: path, swiftUIStyle: swiftUIStrokeStyle, shape: shape)
            
        case .inside:
            // PROFESSIONAL INSIDE STROKE (Professional Standard)
            if strokeStyle.isGradient {
                // For gradient strokes, use a different approach that preserves gradient quality
                // Create a stroke style with the original width but adjust the gradient coordinates
                let adjustedStrokeStyle = StrokeStyle(
                    color: strokeStyle.color,
                    width: strokeStyle.width * 2, // Double width for inside placement
                    placement: .center, // Use center placement for the gradient calculation
                    dashPattern: strokeStyle.dashPattern.map { $0 * 2 }, // Scale dash pattern
                    lineCap: strokeStyle.lineCap.cgLineCap,
                    lineJoin: strokeStyle.lineJoin.cgLineJoin,
                    miterLimit: strokeStyle.miterLimit,
                    opacity: strokeStyle.opacity,
                    blendMode: strokeStyle.blendMode
                )
                let doubleWidthStyle = SwiftUI.StrokeStyle(
                    lineWidth: strokeStyle.width * 2,
                    lineCap: swiftUIStrokeStyle.lineCap,
                    lineJoin: swiftUIStrokeStyle.lineJoin,
                    miterLimit: swiftUIStrokeStyle.miterLimit,
                    dash: swiftUIStrokeStyle.dash.map { $0 * 2 }
                )
                renderStrokeColor(strokeStyle: adjustedStrokeStyle, path: path, swiftUIStyle: doubleWidthStyle, shape: shape)
                    .mask(
                        // Mask to shape interior only
                        path.fill(Color.black) // Black reveals, transparent hides
                    )
            } else {
                // For solid color strokes, use the original approach
                let doubleWidthStyle = SwiftUI.StrokeStyle(
                    lineWidth: strokeStyle.width * 2, // Double width since we're masking to inside
                    lineCap: swiftUIStrokeStyle.lineCap,
                    lineJoin: swiftUIStrokeStyle.lineJoin,
                    miterLimit: swiftUIStrokeStyle.miterLimit,
                    dash: swiftUIStrokeStyle.dash.map { $0 * 2 } // Scale dash pattern accordingly
                )
                renderStrokeColor(strokeStyle: strokeStyle, path: path, swiftUIStyle: doubleWidthStyle, shape: shape)
                    .mask(
                        // Mask to shape interior only
                        path.fill(Color.black) // Black reveals, transparent hides
                    )
            }
            
        case .outside:
            // OUTSIDE STROKE - render a doubled centered stroke and mask it to only the exterior region
            // IMPORTANT: Don't render fill separately - it's handled in the main body where fill is rendered first

            // Compute a large rect around the path to build an even-odd outside mask
            let boundingBox = path.cgPath.boundingBoxOfPath
            let expansion = max(strokeStyle.width * 4, 1000)
            let largeRect = boundingBox.insetBy(dx: -expansion, dy: -expansion)

            // Build a mask that reveals only the area outside the shape path
            let outsideMask = Path { maskPath in
                maskPath.addRect(largeRect)
                maskPath.addPath(path)
            }
                .fill(Color.black, style: SwiftUI.FillStyle(eoFill: true))

            if strokeStyle.isGradient {
                // For gradient strokes, keep gradient coordinates stable via a centered style, then mask to outside
                let adjustedStrokeStyle = StrokeStyle(
                    color: strokeStyle.color,
                    width: strokeStyle.width * 2,
                    placement: .center,
                    dashPattern: strokeStyle.dashPattern.map { $0 * 2 },
                    lineCap: strokeStyle.lineCap.cgLineCap,
                    lineJoin: strokeStyle.lineJoin.cgLineJoin,
                    miterLimit: strokeStyle.miterLimit,
                    opacity: strokeStyle.opacity,
                    blendMode: strokeStyle.blendMode
                )
                let doubleWidthStrokeStyle = SwiftUI.StrokeStyle(
                    lineWidth: strokeStyle.width * 2,
                    lineCap: swiftUIStrokeStyle.lineCap,
                    lineJoin: swiftUIStrokeStyle.lineJoin,
                    miterLimit: swiftUIStrokeStyle.miterLimit,
                    dash: swiftUIStrokeStyle.dash.map { $0 * 2 }
                )

                renderStrokeColor(strokeStyle: adjustedStrokeStyle, path: path, swiftUIStyle: doubleWidthStrokeStyle, shape: shape)
                    .mask(outsideMask)
                    .opacity(strokeStyle.opacity)
            } else {
                // Solid color stroke: double width, masked to outside only
                let doubleWidthStrokeStyle = SwiftUI.StrokeStyle(
                    lineWidth: strokeStyle.width * 2,
                    lineCap: swiftUIStrokeStyle.lineCap,
                    lineJoin: swiftUIStrokeStyle.lineJoin,
                    miterLimit: swiftUIStrokeStyle.miterLimit,
                    dash: swiftUIStrokeStyle.dash.map { $0 * 2 }
                )

                renderStrokeColor(strokeStyle: strokeStyle, path: path, swiftUIStyle: doubleWidthStrokeStyle, shape: shape)
                    .mask(outsideMask)
                    .opacity(strokeStyle.opacity)
            }
        }
    }

    /// Creates appropriate fill rendering based on VectorColor type
    @ViewBuilder
    private func renderFill(fillStyle: FillStyle, path: Path, shape: VectorShape) -> some View {
        switch fillStyle.color {
        case .gradient(let vectorGradient):
            // Use the new NSViewRepresentable view for correct gradient rendering
            GradientFillView(gradient: vectorGradient, path: path.cgPath)
                .opacity(fillStyle.opacity)
                .blendMode(fillStyle.blendMode.swiftUIBlendMode)
            
        default:
            path.fill(fillStyle.color.color, style: SwiftUI.FillStyle(eoFill: shape.path.fillRule.cgPathFillRule == .evenOdd))
                .opacity(fillStyle.opacity)
                .blendMode(fillStyle.blendMode.swiftUIBlendMode)
        }
    }
    
    /// Creates appropriate stroke rendering based on VectorColor type
    @ViewBuilder
    private func renderStrokeColor(strokeStyle: StrokeStyle, path: Path, swiftUIStyle: SwiftUI.StrokeStyle, shape: VectorShape) -> some View {
        switch strokeStyle.color {
        case .gradient(let vectorGradient):
            // Use NSView-based gradient stroke rendering
            GradientStrokeView(gradient: vectorGradient, path: path.cgPath, strokeStyle: strokeStyle)
            
        default:
            path.stroke(strokeStyle.color.color, style: swiftUIStyle)
        }
    }
    
    // Helper function to create pre-transformed paths for clipping masks
    private func createPreTransformedPath(for shape: VectorShape) -> CGPath {
    let path = CGMutablePath()
        
        // Add path elements
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                path.move(to: to.cgPoint)
            case .line(let to):
                path.addLine(to: to.cgPoint)
            case .curve(let to, let control1, let control2):
                path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
            case .quadCurve(let to, let control):
                path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
            case .close:
                path.closeSubpath()
            }
        }
        
        // RESTORE: Apply shape transform for proper positioning
        // The paths need to include transforms to align with the image
        if !shape.transform.isIdentity {
            let transformedPath = CGMutablePath()
            transformedPath.addPath(path, transform: shape.transform)
            return transformedPath
        }
        
        return path
    }
}
