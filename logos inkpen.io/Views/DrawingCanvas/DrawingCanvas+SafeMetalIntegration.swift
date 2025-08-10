import SwiftUI
#if os(macOS)
import AppKit
#endif

// EyedropperCursor now defined in DrawingCanvas.swift for shared access
import MetalKit

/// Safe Metal integration extension for DrawingCanvas
/// This provides Metal acceleration without breaking existing functionality
extension DrawingCanvas {
    
    /// Optional Metal-accelerated overlay that can be toggled on/off
    @ViewBuilder
    internal func optionalMetalAcceleratedOverlay(geometry: GeometryProxy) -> some View {
        // Disabled by default - change to true when you want to test Metal acceleration
        if false { // TODO: Replace with appState.useMetalAcceleration when ready
            SafeMetalView { cgContext, size in
                renderCanvasWithMetal(cgContext: cgContext, size: size, geometry: geometry)
            }
            .opacity(0.99) // Slightly transparent to allow click-through if needed
            .allowsHitTesting(false) // Don't interfere with existing gestures
        }
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
        count += document.textObjects.filter { $0.isVisible }.count
        
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
            
            // Performance monitoring moved to toolbar
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
                    NSCursor.openHand.set()
                } else if newTool == .eyedropper {
                    EyedropperCursor.set()
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
                print("🖱️ Canvas hover: entered")
                #if os(macOS)
                if document.currentTool == .hand {
                    NSCursor.openHand.set()
                } else if document.currentTool == .eyedropper {
                    EyedropperCursor.set()
                }
                #endif
            } else {
                print("🖱️ Canvas hover: exited")
                #if os(macOS)
                NSCursor.arrow.set()
                #endif
            }
        }
        .onContinuousHover { phase in
            handleHover(phase: phase, geometry: geometry)
        }
        .onTapGesture { location in
            print("🎯 SINGLE CLICK DETECTED at: \(location)")
            handleUnifiedTap(at: location, geometry: geometry)
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
        .contextMenu {
            directSelectionContextMenu
        }
    }
}
