import SwiftUI
#if os(macOS)
import AppKit
#endif

// EyedropperCursor now defined in DrawingCanvas.swift for shared access
import MetalKit

/// Safe Metal integration extension for DrawingCanvas
/// This provides Metal acceleration without breaking existing functionality
extension DrawingCanvas {
    
    /// Optional Metal-accelerated overlay (always active when using the Metal layer)
    /// HUD visibility is controlled separately by `appState.showPerformanceHUD`.
    @ViewBuilder
    internal func optionalMetalAcceleratedOverlay(geometry: GeometryProxy) -> some View {
        SafeMetalView { cgContext, size in
            // Draw grid/selection via CG
            renderCanvasWithMetal(cgContext: cgContext, size: size, geometry: geometry)
            // Draw live brush preview path in overlay without touching document layers
            if let preview = brushPreviewPath {
                cgContext.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
                cgContext.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
                let cgPath = CGMutablePath()
                for e in preview.elements {
                    switch e {
                    case .move(let to):
                        cgPath.move(to: transformPointToView(to.cgPoint, geometry: geometry))
                    case .line(let to):
                        cgPath.addLine(to: transformPointToView(to.cgPoint, geometry: geometry))
                    case .curve(let to, let c1, let c2):
                        cgPath.addCurve(to: transformPointToView(to.cgPoint, geometry: geometry),
                                        control1: transformPointToView(c1.cgPoint, geometry: geometry),
                                        control2: transformPointToView(c2.cgPoint, geometry: geometry))
                    case .quadCurve(let to, let c):
                        cgPath.addQuadCurve(to: transformPointToView(to.cgPoint, geometry: geometry),
                                            control: transformPointToView(c.cgPoint, geometry: geometry))
                    case .close:
                        cgPath.closeSubpath()
                    }
                }
                cgContext.addPath(cgPath)
                cgContext.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.0))
                cgContext.fillPath()
            }
        }
        .allowsHitTesting(false)
    }
    
    /// Render selected canvas elements with Metal acceleration
    private func renderCanvasWithMetal(cgContext: CGContext, size: CGSize, geometry: GeometryProxy) {
        // Only render specific elements that benefit from Metal acceleration
        // Start with simple overlays that don't affect core functionality
        
        // 1. Render grid with Metal (if enabled)
        if document.snapToGrid {
            renderGridWithMetal(cgContext: cgContext, size: size, geometry: geometry)
        }
        
        // 2. Render real-time drawing preview with Metal (if drawing)
        if let currentPath = currentPath, isDrawing {
            renderCurrentPathWithMetal(cgContext: cgContext, path: currentPath, geometry: geometry)
        }
        
        // 3. Render selection overlays with Metal (non-critical UI elements)
        if !document.selectedShapeIDs.isEmpty {
            renderSelectionOverlaysWithMetal(cgContext: cgContext, geometry: geometry)
        }
    }
    
    /// Metal-accelerated grid rendering (safe non-breaking enhancement)
    private func renderGridWithMetal(cgContext: CGContext, size: CGSize, geometry: GeometryProxy) {
        let gridSpacing: CGFloat = 20 * document.zoomLevel
        let offset = document.canvasOffset
        
        cgContext.setStrokeColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.5))
        cgContext.setLineWidth(0.5)
        
        // Vertical lines
        var x: CGFloat = fmod(offset.x, gridSpacing)
        while x < size.width {
            cgContext.move(to: CGPoint(x: x, y: 0))
            cgContext.addLine(to: CGPoint(x: x, y: size.height))
            x += gridSpacing
        }
        
        // Horizontal lines
        var y: CGFloat = fmod(offset.y, gridSpacing)
        while y < size.height {
            cgContext.move(to: CGPoint(x: 0, y: y))
            cgContext.addLine(to: CGPoint(x: size.width, y: y))
            y += gridSpacing
        }
        
        cgContext.strokePath()
    }
    
    /// Metal-accelerated current path rendering (safe enhancement)
    private func renderCurrentPathWithMetal(cgContext: CGContext, path: VectorPath, geometry: GeometryProxy) {
        cgContext.setStrokeColor(CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.8))
        cgContext.setLineWidth(2.0)
        
        let cgPath = CGMutablePath()
        for element in path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = transformPointToView(to.cgPoint, geometry: geometry)
                cgPath.move(to: transformedPoint)
            case .line(let to):
                let transformedPoint = transformPointToView(to.cgPoint, geometry: geometry)
                cgPath.addLine(to: transformedPoint)
            case .curve(let to, let control1, let control2):
                let transformedCP1 = transformPointToView(control1.cgPoint, geometry: geometry)
                let transformedCP2 = transformPointToView(control2.cgPoint, geometry: geometry)
                let transformedPoint = transformPointToView(to.cgPoint, geometry: geometry)
                cgPath.addCurve(to: transformedPoint, control1: transformedCP1, control2: transformedCP2)
            case .quadCurve(let to, let control):
                let transformedControl = transformPointToView(control.cgPoint, geometry: geometry)
                let transformedPoint = transformPointToView(to.cgPoint, geometry: geometry)
                cgPath.addQuadCurve(to: transformedPoint, control: transformedControl)
            case .close:
                cgPath.closeSubpath()
            }
        }
        
        cgContext.addPath(cgPath)
        cgContext.strokePath()
    }
    
    /// Metal-accelerated selection overlays (safe non-critical enhancement)
    private func renderSelectionOverlaysWithMetal(cgContext: CGContext, geometry: GeometryProxy) {
        // Render subtle selection hints that don't interfere with existing UI
        cgContext.setFillColor(CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.1))
        
        for shapeID in document.selectedShapeIDs {
            if let shape = findShape(by: shapeID) {
                let bounds = shape.bounds // Use the existing bounds property
                let transformedBounds = transformRectToView(bounds, geometry: geometry)
                cgContext.fill(transformedBounds)
            }
        }
    }
    
    /// Helper: Transform point from canvas coordinates to view coordinates
    private func transformPointToView(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return CGPoint(
            x: point.x * document.zoomLevel + document.canvasOffset.x,
            y: point.y * document.zoomLevel + document.canvasOffset.y
        )
    }
    
    /// Helper: Transform rect from canvas coordinates to view coordinates
    private func transformRectToView(_ rect: CGRect, geometry: GeometryProxy) -> CGRect {
        return CGRect(
            x: rect.origin.x * document.zoomLevel + document.canvasOffset.x,
            y: rect.origin.y * document.zoomLevel + document.canvasOffset.y,
            width: rect.width * document.zoomLevel,
            height: rect.height * document.zoomLevel
        )
    }
    
    /// Helper: Find shape by ID in all layers
    private func findShape(by id: UUID) -> VectorShape? {
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == id }) {
                return shape
            }
        }
        return nil
    }
}

// TODO: Add this to AppState when ready to enable Metal acceleration
// extension AppState {
//     var useMetalAcceleration: Bool = false
// }

extension DrawingCanvas {
    /// Count active drawing elements for performance tracking
    private func countActiveDrawElements() -> Int {
        var count = 0
        
        // Count visible shapes in all layers
        for layer in document.layers where layer.isVisible {
            count += layer.shapes.count
        }
        
        // Count text objects
        count += document.allTextObjects.filter { $0.isVisible }.count
        
        // Count current drawing path if active
        if currentPath != nil && isDrawing {
            count += 1
        }
        
        // Count selection handles if any shapes are selected
        if !document.selectedShapeIDs.isEmpty {
            count += document.selectedShapeIDs.count * 8 // Each shape has ~8 selection handles
        }
        
        return count
    }
}

/// Safe integration helper for existing views
extension DrawingCanvas {
    
    /// Non-breaking way to add Metal acceleration to existing canvasMainContent
    @ViewBuilder
    internal func enhancedCanvasMainContent(geometry: GeometryProxy) -> some View {
        ZStack {
            // Your existing content (unchanged)
            canvasBaseContent(geometry: geometry)
            
            // Optional Metal acceleration layer (can be disabled)
            optionalMetalAcceleratedOverlay(geometry: geometry)
            
            // Your existing pressure-sensitive overlay (unchanged)
            pressureSensitiveOverlay(geometry: geometry)
            
            // Removed custom in-app Performance HUD overlay
            #if os(macOS)
            // AppKit-backed cursor overlay to eliminate flicker
            CanvasCursorOverlayView(
                isHovering: isCanvasHovering,
                currentTool: document.currentTool,
                isPanActive: isPanGestureActive,
                zoomLevel: document.zoomLevel,
                canvasOffset: document.canvasOffset
            )
            #endif
        }
        // All your existing modifiers (unchanged)
        .onAppear {
            setupCanvas(geometry: geometry)
            setupKeyEventMonitoring()
            setupToolKeyboardShortcuts()
            previousTool = document.currentTool
        }
        .onDisappear {
            teardownKeyEventMonitoring()
        }
        .onChange(of: document.currentTool) { oldTool, newTool in
            handleToolChange(oldTool: oldTool, newTool: newTool)
            #if os(macOS)
            if isCanvasHovering {
                if newTool == .hand {
                    HandOpenCursor.set()
                } else if newTool == .eyedropper {
                    EyedropperCursor.set()
                } else if newTool == .zoom {
                    MagnifyingGlassCursor.set()
                } else if newTool == .rectangle || newTool == .square || newTool == .circle || newTool == .equilateralTriangle || newTool == .isoscelesTriangle || newTool == .rightTriangle || newTool == .acuteTriangle || newTool == .cone || newTool == .polygon || newTool == .pentagon || newTool == .hexagon || newTool == .heptagon || newTool == .octagon || newTool == .nonagon {
                    CrosshairCursor.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            #endif
        }
        .onHover { isHovering in
            // Track enter/exit over the drawing area
            isCanvasHovering = isHovering
            if isHovering {
                #if os(macOS)
                if document.currentTool == .hand {
                    HandOpenCursor.set()
                } else if document.currentTool == .eyedropper {
                    EyedropperCursor.set()
                } else if document.currentTool == .zoom {
                    MagnifyingGlassCursor.set()
                } else if document.currentTool == .rectangle || document.currentTool == .square || document.currentTool == .circle || document.currentTool == .equilateralTriangle || document.currentTool == .isoscelesTriangle || document.currentTool == .rightTriangle || document.currentTool == .acuteTriangle || document.currentTool == .cone || document.currentTool == .polygon || document.currentTool == .pentagon || document.currentTool == .hexagon || document.currentTool == .heptagon || document.currentTool == .octagon || document.currentTool == .nonagon {
                    CrosshairCursor.set()
                }
                #endif
            } else {
                #if os(macOS)
                NSCursor.arrow.set()
                #endif
            }
        }
        .onContinuousHover { phase in
            handleHover(phase: phase, geometry: geometry)
            #if os(macOS)
            // During hover tracking, prevent system from flipping to arrow while zoom tool is active
            if isCanvasHovering && document.currentTool == .zoom {
                MagnifyingGlassCursor.set()
            }
            #endif
        }
        .onTapGesture { location in
            Log.fileOperation("🎯 SINGLE CLICK DETECTED at: \(location)", level: .info)
            handleUnifiedTap(at: location, geometry: geometry)
            #if os(macOS)
            // After tap, restore appropriate cursor immediately
            // Note: During mouseDown, SwiftUI may temporarily drop hover. Use hit test
            // to verify the location is inside the canvas bounds to decide cursor.
            let pointInView = location
            let insideCanvas = pointInView.x >= 0 && pointInView.y >= 0 &&
                pointInView.x <= geometry.size.width && pointInView.y <= geometry.size.height
            if insideCanvas || isCanvasHovering {
                switch document.currentTool {
                case .hand:
                    HandOpenCursor.set()
                case .eyedropper:
                    EyedropperCursor.set()
                case .zoom:
                    MagnifyingGlassCursor.set()
                case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                    CrosshairCursor.set()
                default:
                    NSCursor.arrow.set()
                }
                // Defensive: if system applies Arrow after layout updates, override on next runloop
                DispatchQueue.main.async {
                    if (insideCanvas || isCanvasHovering) {
                        switch document.currentTool {
                        case .hand:
                            HandOpenCursor.set()
                        case .eyedropper:
                            EyedropperCursor.set()
                        case .zoom:
                            MagnifyingGlassCursor.set()
                        case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                            CrosshairCursor.set()
                        default:
                            NSCursor.arrow.set()
                        }
                    }
                }
            }
            #endif
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    handleUnifiedDragChanged(value: value, geometry: geometry)
                }
                .onEnded { value in
                    handleUnifiedDragEnded(value: value, geometry: geometry)
                }
        )
        .simultaneousGesture(
            // PROFESSIONAL ZOOM GESTURE - Separate from drag to avoid conflicts
            MagnificationGesture()
                .onChanged { value in
                    handleZoomGestureChanged(value: value, geometry: geometry)
                }
                .onEnded { value in
                    handleZoomGestureEnded(value: value, geometry: geometry)
                }
        )
        .onChange(of: document.zoomRequest) {
            if let request = document.zoomRequest {
                handleZoomRequest(request, geometry: geometry)
            }
        }
        // Reassert correct tool cursor whenever zoom level changes (post-layout)
        .onChange(of: document.zoomLevel) { _, _ in
            #if os(macOS)
            if isCanvasHovering {
                switch document.currentTool {
                case .hand:
                    HandOpenCursor.set()
                case .eyedropper:
                    EyedropperCursor.set()
                case .zoom:
                    MagnifyingGlassCursor.set()
                case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                    CrosshairCursor.set()
                default:
                    break
                }
                // Also schedule on next runloop to win races with system arrow resets
                DispatchQueue.main.async {
                    if isCanvasHovering {
                        switch document.currentTool {
                        case .hand:
                            HandOpenCursor.set()
                        case .eyedropper:
                            EyedropperCursor.set()
                        case .zoom:
                            MagnifyingGlassCursor.set()
                        case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                            CrosshairCursor.set()
                        default:
                            break
                        }
                    }
                }
            }
            #endif
        }
        // Reassert during offset changes as well (some zoom flows adjust offset last)
        .onChange(of: document.canvasOffset) { _, _ in
            #if os(macOS)
            if isCanvasHovering {
                switch document.currentTool {
                case .hand:
                    HandOpenCursor.set()
                case .eyedropper:
                    EyedropperCursor.set()
                case .zoom:
                    MagnifyingGlassCursor.set()
                case .square, .circle, .equilateralTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                    NSCursor.crosshair.set()
                default:
                    break
                }
            }
            #endif
        }
        .contextMenu {
            directSelectionContextMenu
        }
    }
}

// Removed: CanvasPerformanceHUD wrapper and usage
