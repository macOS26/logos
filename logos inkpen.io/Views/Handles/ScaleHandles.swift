//
//  ScaleHandles.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import SwiftUI
import Combine

// MARK: - Scale Tool Handles
struct ScaleHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool  // Passed from DrawingCanvas for transform tool constraints
    
    // Professional scaling state management - FIXED IMPLEMENTATION
    @State var isScaling = false
    @State var scalingStarted = false
    @State var initialBounds: CGRect = .zero
    @State var initialTransform: CGAffineTransform = .identity
    @State var startLocation: CGPoint = .zero
    @State var previewTransform: CGAffineTransform = .identity
    @State var scalingAnchorPoint: CGPoint = .zero  // This is the LOCKED/PIN point (RED)
    @State var finalMarqueeBounds: CGRect = .zero
    @State var isCapsLockPressed = false  // NEW: Track caps-lock for locking pin point

    // CORRECTED POINT SYSTEM: Lock point vs scale points
    @State var lockedPinPointIndex: Int? = nil // Which point is LOCKED (RED) - set by single click
    @State var pathPoints: [VectorPoint] = []  // All path points for display
    @State var centerPoint: VectorPoint = VectorPoint(CGPoint.zero) // Center point
    @State var pointsRefreshTrigger: Int = 0

    let handleSize: CGFloat = 10
    
    // CRITICAL FIX: Calculate bounds outside body property to avoid build errors
    private var calculatedBounds: CGRect {
        if ImageContentRegistry.containsImage(shape) {
            // For ALL images, calculate bounds the same way as ShapeView renders them
            // This matches the actual image positioning: pathBounds.applying(shape.transform)
            let pathBounds = shape.path.cgPath.boundingBoxOfPath
            return pathBounds.applying(shape.transform)
        } else {
            // For regular shapes, use existing logic
            return shape.isGroupContainer ? shape.groupBounds : shape.bounds
        }
    }
    
    private var calculatedCenter: CGPoint {
        // Use true geometric centroid from common helper
        return shape.calculateCentroid()
    }
    
    var body: some View {
        // SCALE TOOL: Show all path points + center point with correct colors
        // CRITICAL FIX: For images with transforms, use the same bounds calculation as transform box handles
        // This ensures the scale tool aligns properly with transformed images
        let bounds = calculatedBounds
        let center = calculatedCenter
        
        ZStack {
            // ACTUAL OBJECT OUTLINE: Show the real shape paths
            if shape.isGroup && !shape.groupedShapes.isEmpty {
                // GROUP/FLATTENED SHAPE: Show outline of each individual shape
                ForEach(shape.groupedShapes.indices, id: \.self) { index in
                    let groupedShape = shape.groupedShapes[index]
                    // PERFORMANCE OPTIMIZATION: Use cached path creation
                    let cachedPath = Path { path in
                        for element in groupedShape.path.elements {
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
                    }
                    ZStack {
                        cachedPath
                            .stroke(Color.white, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0], dashPhase: 2.0))
                            .scaleEffect(zoomLevel, anchor: .topLeading)
                            .offset(x: canvasOffset.x, y: canvasOffset.y)
                            .transformEffect(groupedShape.transform)
                        cachedPath
                            .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0]))
                            .scaleEffect(zoomLevel, anchor: .topLeading)
                            .offset(x: canvasOffset.x, y: canvasOffset.y)
                            .transformEffect(groupedShape.transform)
                    }
                }
            } else {
                // REGULAR SHAPE: Show single path outline with cached path
                // PERFORMANCE OPTIMIZATION: Use cached path creation
                let cachedPath = Path { path in
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
                }
                ZStack {
                    cachedPath
                        .stroke(Color.white, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0], dashPhase: 2.0))
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .transformEffect(shape.transform)
                    cachedPath
                        .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0]))
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .transformEffect(shape.transform)
                }
            }
            
            // SHOW ALL PATH POINTS + CENTER POINT with correct colors
            pathPointsView()
            
            // GROUP BOUNDS FEATURES: For groups/flattened objects, also show bounds points
            if shape.isGroup && !shape.groupedShapes.isEmpty {
                // GREEN BOUNDS MARQUEE: Show the overall bounding box
                Rectangle()
                    .stroke(Color.green, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [3.0 / zoomLevel, 3.0 / zoomLevel]))
                    .frame(width: bounds.width, height: bounds.height)
                    .position(center)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
                
                // BOUNDS CORNER POINTS: Show the 4 corner points of the bounding box
                ForEach(0..<4) { i in
                    let cornerPos = cornerPosition(for: i, in: bounds, center: center)
                    let cornerIndex = pathPoints.count + i // Offset to avoid conflicts with path points
                    let isLockedPin = lockedPinPointIndex == cornerIndex
                    
                    Circle()
                        .fill(isLockedPin ? Color.red : Color.green)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize, height: handleSize)
                        .offset(
                            x: cornerPos.x * zoomLevel + canvasOffset.x - (handleSize) / 2,
                            y: cornerPos.y * zoomLevel + canvasOffset.y - (handleSize) / 2
                        )
                        .onTapGesture {
                            if !isScaling {
                                // SINGLE CLICK: Set this as the locked pin point (RED)
                                setLockedPinPoint(cornerIndex)
                            }
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { value in
                                    // DRAG: Scale away from the locked pin point
                                    handleScalingFromPoint(draggedPointIndex: cornerIndex, dragValue: value, bounds: bounds, center: center)
                                }
                                .onEnded { _ in
                                    finishScaling()
                                }
                        )
                }
            }
            
            // CENTER POINT: Always available (GREEN if not locked, RED if locked)
            let isCenterLockedPin = (lockedPinPointIndex == nil) // nil represents center as locked pin
            Circle()
                .fill(isCenterLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = scalable
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize) // Fixed UI size - does not scale with artwork
                .position(CGPoint(
                    x: center.x * zoomLevel + canvasOffset.x,
                    y: center.y * zoomLevel + canvasOffset.y
                ))
                .zIndex(100) // Ensure center point is on top
                .onTapGesture {
                    if !isScaling {
                        // SINGLE CLICK: Set center as the locked pin point (RED)
                        setLockedPinPoint(nil) // nil = center
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            // When dragging center point, calculate scale based on drag distance
                            if !scalingStarted {
                                scalingStarted = true
                                isScaling = true
                                document.isHandleScalingActive = true
                                initialBounds = bounds
                                initialTransform = shape.transform
                                startLocation = value.startLocation
                                scalingAnchorPoint = center
                                document.saveToUndoStack()
                            }

                            let translation = CGSize(
                                width: value.location.x - value.startLocation.x,
                                height: value.location.y - value.startLocation.y
                            )

                            // Calculate scale based on drag distance
                            let sensitivity: CGFloat = 0.005 / zoomLevel
                            var scaleX = 1.0 + (translation.width * sensitivity)
                            var scaleY = 1.0 + (translation.height * sensitivity)

                            scaleX = min(max(scaleX, 0.1), 10.0)
                            scaleY = min(max(scaleY, 0.1), 10.0)

                            if isShiftPressed {
                                let avgScale = (scaleX + scaleY) / 2.0
                                scaleX = avgScale
                                scaleY = avgScale
                            }

                            calculatePreviewTransform(scaleX: scaleX, scaleY: scaleY, anchor: center)
                        }
                        .onEnded { _ in
                            finishScaling()
                        }
                )
            
            // MARQUEE PREVIEW: Show ACTUAL SCALED SHAPE OUTLINE (EXACTLY like the final object will be)
            if isScaling && !previewTransform.isIdentity {
                if shape.isGroup && !shape.groupedShapes.isEmpty {
                    // GROUP/FLATTENED SHAPE: Show marquee preview for each individual shape
                    ForEach(shape.groupedShapes.indices, id: \.self) { index in
                        let groupedShape = shape.groupedShapes[index]
                        Path { path in
                            for element in groupedShape.path.elements {
                                switch element {
                                case .move(let to):
                                    let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    path.move(to: transformedPoint)
                                case .line(let to):
                                    let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    path.addLine(to: transformedPoint)
                                case .curve(let to, let control1, let control2):
                                    let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(previewTransform)
                                    let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(previewTransform)
                                    path.addCurve(to: transformedTo, control1: transformedControl1, control2: transformedControl2)
                                case .quadCurve(let to, let control):
                                    let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    let transformedControl = CGPoint(x: control.x, y: control.y).applying(previewTransform)
                                    path.addQuadCurve(to: transformedTo, control: transformedControl)
                                case .close:
                                    path.closeSubpath()
                                }
                            }
                        }
                        .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        // NO .transformEffect! Coordinates already transformed above (same as actual object)
                        .opacity(0.8)
                    }
                } else {
                    // REGULAR SHAPE: Show single marquee preview
                    Path { path in
                        for element in shape.path.elements {
                            switch element {
                            case .move(let to):
                                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                path.move(to: transformedPoint)
                            case .line(let to):
                                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                path.addLine(to: transformedPoint)
                            case .curve(let to, let control1, let control2):
                                let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(previewTransform)
                                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(previewTransform)
                                path.addCurve(to: transformedTo, control1: transformedControl1, control2: transformedControl2)
                            case .quadCurve(let to, let control):
                                let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                let transformedControl = CGPoint(x: control.x, y: control.y).applying(previewTransform)
                                path.addQuadCurve(to: transformedTo, control: transformedControl)
                            case .close:
                                path.closeSubpath()
                            }
                        }
                    }
                    .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    // NO .transformEffect! Coordinates already transformed above (same as actual object)
                    .opacity(0.8)
                }
                
                // GREEN BOUNDS MARQUEE PREVIEW: Show live scaling bounds for groups/flattened objects
                if shape.isGroup && !shape.groupedShapes.isEmpty {
                    // Calculate transformed bounds for the green marquee preview
                    let transformedBounds = bounds.applying(previewTransform)
                    let transformedCenter = CGPoint(x: transformedBounds.midX, y: transformedBounds.midY)
                    
                    Rectangle()
                        .stroke(Color.green, style: SwiftUI.StrokeStyle(lineWidth: 1.5 / zoomLevel, dash: [3.0 / zoomLevel, 3.0 / zoomLevel]))
                        .frame(width: transformedBounds.width, height: transformedBounds.height)
                        .position(transformedCenter)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                    // NO .transformEffect! Bounds already transformed above
                        .opacity(0.6)
                }
                
                // Marquee shows scaling preview without additional handles (handled by point system below)
            }
        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
            extractPathPoints()
            
            // Set default locked pin point to center if none is set
            if lockedPinPointIndex == nil && scalingAnchorPoint == .zero {
                setLockedPinPoint(nil) // nil = center point
                // Log.info("🔴 SCALE TOOL: Default locked pin set to center", category: .general)
            }
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            // MOVEMENT FIX: When shape bounds change (e.g., after moving), refresh the scale points
            if !isScaling && oldBounds != newBounds {
                extractPathPoints()
                pointsRefreshTrigger += 1
                Log.fileOperation("🔄 SCALE TOOL: Shape bounds changed, refreshed points", level: .info)
            }
        }
        .id("scale-handles-\(pointsRefreshTrigger)") // Force view rebuild when points update
    }

    // MARK: - Key Event Monitoring
    // NOTE: Shift key monitoring is now handled by the centralized keyEventMonitor in DrawingCanvas
    // to avoid multiple NSEvent monitors and ensure consistent behavior across all transform tools

    @State var keyEventMonitor: Any?
}
