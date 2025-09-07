//
//  ScaleHandles.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import CoreGraphics
import SwiftUI

// MARK: - Scale Tool Handles
struct ScaleHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool  // Passed from DrawingCanvas for transform tool constraints
    
    // Professional scaling state management - FIXED IMPLEMENTATION
    @State private var isScaling = false
    @State private var scalingStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var scalingAnchorPoint: CGPoint = .zero  // This is the LOCKED/PIN point (RED)
    @State private var finalMarqueeBounds: CGRect = .zero
    @State private var isCapsLockPressed = false  // NEW: Track caps-lock for locking pin point
    
    // CORRECTED POINT SYSTEM: Lock point vs scale points
    @State private var lockedPinPointIndex: Int? = nil // Which point is LOCKED (RED) - set by single click
    @State private var pathPoints: [VectorPoint] = []  // All path points for display
    @State private var centerPoint: VectorPoint = VectorPoint(CGPoint.zero) // Center point
    @State private var pointsRefreshTrigger: Int = 0
    
    private let handleSize: CGFloat = 10
    
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
        let bounds = calculatedBounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
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
                    cachedPath
                        .stroke(Color.red, lineWidth: 2.0 / zoomLevel)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .transformEffect(groupedShape.transform)
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
                cachedPath
                    .stroke(Color.red, lineWidth: 2.0 / zoomLevel)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
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
            Rectangle()
                .fill(isCenterLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = scalable
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize) // Fixed UI size - does not scale with artwork
                .position(CGPoint(
                    x: center.x * zoomLevel + canvasOffset.x,
                    y: center.y * zoomLevel + canvasOffset.y
                ))
                .onTapGesture {
                    if !isScaling {
                        // SINGLE CLICK: Set center as the locked pin point (RED)
                        setLockedPinPoint(nil) // nil = center
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            // DRAG: Scale away from the locked pin point
                            handleScalingFromPoint(draggedPointIndex: nil, dragValue: value, bounds: bounds, center: center)
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
                Log.info("🔴 SCALE TOOL: Default locked pin set to center", category: .general)
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
    
    private func handleCornerScaling(index: Int, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !scalingStarted {
            scalingStarted = true
            isScaling = true
            document.isHandleScalingActive = true // CRITICAL: Prevent canvas drag conflicts
            initialBounds = bounds
            initialTransform = shape.transform
            startLocation = dragValue.startLocation
            document.saveToUndoStack()
            
            // NEW: Use selected scaling anchor mode from toolbar
            scalingAnchorPoint = getAnchorPoint(for: document.scalingAnchor, in: bounds, cornerIndex: index)
            print("🔄 SCALING START: Corner \(index) → Anchor mode: \(document.scalingAnchor.displayName) at (\(String(format: "%.1f", scalingAnchorPoint.x)), \(String(format: "%.1f", scalingAnchorPoint.y)))")
            print("   📐 Initial bounds: (\(String(format: "%.1f", bounds.minX)), \(String(format: "%.1f", bounds.minY))) → (\(String(format: "%.1f", bounds.maxX)), \(String(format: "%.1f", bounds.maxY)))")
            print("   🖱️ Start cursor: screen(\(String(format: "%.1f", startLocation.x)), \(String(format: "%.1f", startLocation.y)))")
        }
        
        // PROFESSIONAL SCALING: Calculate scale from anchor point to current cursor position
        // Use direct cursor tracking instead of DragGesture.translation for perfect accuracy
        let currentLocation = dragValue.location
        
        // Convert anchor point to screen coordinates using manual calculation
        let anchorScreenX = scalingAnchorPoint.x * zoomLevel + canvasOffset.x
        let anchorScreenY = scalingAnchorPoint.y * zoomLevel + canvasOffset.y
        
        // Calculate distances from anchor to start and current positions
        let startDistance = CGPoint(
            x: startLocation.x - anchorScreenX,
            y: startLocation.y - anchorScreenY
        )
        
        let currentDistance = CGPoint(
            x: currentLocation.x - anchorScreenX,
            y: currentLocation.y - anchorScreenY
        )
        
        // Calculate scale factors with reasonable bounds to prevent extreme values
        // ADAPTIVE MINIMUM DISTANCE: Base threshold on object size to handle thin/narrow objects
        let baseBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        let adaptiveMinDistanceX = min(20.0, max(2.0, abs(baseBounds.width) * 0.05))  // 5% of width, min 2pt, max 20pt
        let adaptiveMinDistanceY = min(20.0, max(2.0, abs(baseBounds.height) * 0.05)) // 5% of height, min 2pt, max 20pt
        let maxScale: CGFloat = 10.0    // Maximum scale factor to prevent extreme scaling
        let minScale: CGFloat = 0.1     // Minimum scale factor to prevent inversion
        
        var scaleX = abs(startDistance.x) > adaptiveMinDistanceX ? abs(currentDistance.x) / abs(startDistance.x) : 1.0
        var scaleY = abs(startDistance.y) > adaptiveMinDistanceY ? abs(currentDistance.y) / abs(startDistance.y) : 1.0
        
        // Clamp scale factors to reasonable bounds
        scaleX = min(max(scaleX, minScale), maxScale)
        scaleY = min(max(scaleY, minScale), maxScale)
        
        // PROPORTIONAL SCALING: When shift is held, use uniform scaling
        if isShiftPressed {
            let uniformScale = max(scaleX, scaleY) // Use the larger scale factor
            scaleX = uniformScale
            scaleY = uniformScale
            // Removed excessive logging during drag operations
        }
        
        // Removed excessive logging during drag operations
        
        // Apply preview scaling
        calculatePreviewTransform(scaleX: scaleX, scaleY: scaleY, anchor: scalingAnchorPoint)
    }
    
    
    
    private func finishScaling() {
        scalingStarted = false
        isScaling = false
        document.isHandleScalingActive = false // CRITICAL: Re-enable canvas drag gestures
        
        // Removed excessive logging during drag operations
        
        // PROFESSIONAL SCALING FIX: Apply the final preview transform to coordinates
        // This ensures object origin stays with object after scaling (Professional behavior)
        
        // CRITICAL FIX: Find the unified object that contains this specific shape
        if let unifiedObject = document.unifiedObjects.first(where: { unifiedObject in
            if case .shape(let targetShape) = unifiedObject.objectType {
                return targetShape.id == shape.id
            }
            return false
        }),
        let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {
        
        let shapes = document.getShapesForLayer(layerIndex)
        if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }),
           var updatedShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
            
            _ = updatedShape.bounds
            // Removed excessive logging during drag operations
            
            // CRITICAL FIX: Reset to initial transform first to prevent drift accumulation
            updatedShape.transform = initialTransform
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // Apply the final transform to coordinates and reset transform to identity
            applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            
            if let finalShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                _ = finalShape.bounds
            }
            // Removed excessive logging during drag operations
            
            // Reset preview transform and marquee bounds
            previewTransform = .identity
            finalMarqueeBounds = .zero // Hide marquee
            
            Log.info("✅ SCALING FINISHED: Applied final transform to coordinates and reset transform to identity", category: .fileOperations)
            
            // CRITICAL FIX: Sync unified objects after scaling to ensure UI updates
            document.updateUnifiedObjectsOptimized()
            
            // CRITICAL FIX: Force refresh of point selection system (same as rotate/shear tools)
            // This updates the points to match the scaled object positions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updatePathPointsAfterScaling()
            }
        }
        } else {
            Log.error("❌ SCALING FAILED: Could not find shape in unified objects system", category: .error)
        }
    }
    
    // MARK: - Point-Based Scale System (same as rotate/shear tools)
    
    /// Extract all path points for selection display
    private func extractPathPoints() {
        pathPoints.removeAll()
        
        // FLATTENED SHAPE FIX: Extract points from individual grouped shapes, not container
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            // For flattened shapes, extract points from all grouped shapes
            for groupedShape in shape.groupedShapes {
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to), .line(let to):
                        pathPoints.append(to)
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        pathPoints.append(to)
                    case .close:
                        continue // Skip close elements
                    }
                }
            }
        } else {
            // Regular shape: Extract from main path
            for element in shape.path.elements {
                switch element {
                case .move(let to), .line(let to):
                    pathPoints.append(to)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    pathPoints.append(to)
                case .close:
                    continue // Skip close elements
                }
            }
        }
        
        // Update center point based on current bounds
        // CRITICAL FIX: For ALL images, use the same bounds calculation as ShapeView rendering
        let bounds: CGRect
        if ImageContentRegistry.containsImage(shape) {
            // For ALL images, calculate bounds the same way as ShapeView renders them
            // This matches the actual image positioning: pathBounds.applying(shape.transform)
            let pathBounds = shape.path.cgPath.boundingBoxOfPath
            bounds = pathBounds.applying(shape.transform)
        } else {
            // For regular shapes, use existing logic
            bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        }
        centerPoint = VectorPoint(CGPoint(x: bounds.midX, y: bounds.midY))
        
        Log.fileOperation("🎯 EXTRACTED \(pathPoints.count) path points + center for scale anchor selection", level: .info)
    }
    
    /// Display all path points with correct colors: GREEN = scalable, RED = locked pin
    @ViewBuilder
    private func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isLockedPin = lockedPinPointIndex == index
            
            let transformedPoint = CGPoint(x: point.x, y: point.y).applying(shape.transform)
            Circle()
                .fill(isLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = scalable
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(CGPoint(
                    x: transformedPoint.x * zoomLevel + canvasOffset.x,
                    y: transformedPoint.y * zoomLevel + canvasOffset.y
                ))
                .onTapGesture {
                    if !isScaling {
                        // SINGLE CLICK: Set this as the locked pin point (RED)
                        setLockedPinPoint(index)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            // DRAG: Scale away from the locked pin point
                            handleScalingFromPoint(draggedPointIndex: index, dragValue: value, bounds: shape.bounds, center: CGPoint(x: centerPoint.x, y: centerPoint.y))
                        }
                        .onEnded { _ in
                            finishScaling()
                        }
                )
        }
    }
    
    // MARK: - Lock Pin Point Management
    
    /// Set which point is the locked pin point (RED) - stays stationary during scaling
    private func setLockedPinPoint(_ pointIndex: Int?) {
        lockedPinPointIndex = pointIndex
        
        // Update the scaling anchor point to the locked pin location
        if let index = pointIndex {
            if index < pathPoints.count {
                // Path point
                let point = pathPoints[index]
                scalingAnchorPoint = CGPoint(x: point.x, y: point.y)
                print("🔴 LOCKED PIN: Set to path point \(index) at (\(String(format: "%.1f", point.x)), \(String(format: "%.1f", point.y)))")
            } else {
                // Bounds corner point
                let cornerIndex = index - pathPoints.count
                // CRITICAL FIX: Use the same bounds calculation as ShapeView rendering
                let bounds: CGRect
                if ImageContentRegistry.containsImage(shape) {
                    // For ALL images, calculate bounds the same way as ShapeView renders them
                    let pathBounds = shape.path.cgPath.boundingBoxOfPath
                    bounds = pathBounds.applying(shape.transform)
                } else {
                    // For regular shapes, use existing logic
                    bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                }
                let center = CGPoint(x: bounds.midX, y: bounds.midY)
                scalingAnchorPoint = cornerPosition(for: cornerIndex, in: bounds, center: center)
                print("🔴 LOCKED PIN: Set to bounds corner \(cornerIndex) at (\(String(format: "%.1f", scalingAnchorPoint.x)), \(String(format: "%.1f", scalingAnchorPoint.y)))")
            }
        } else {
            // Center point
            scalingAnchorPoint = CGPoint(x: centerPoint.x, y: centerPoint.y)
            print("🔴 LOCKED PIN: Set to center point at (\(String(format: "%.1f", scalingAnchorPoint.x)), \(String(format: "%.1f", scalingAnchorPoint.y)))")
        }
    }
    
    // CORRECTED: Handle scaling away from the locked pin point
    private func handleScalingFromPoint(draggedPointIndex: Int?, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !scalingStarted {
            startScalingFromPoint(draggedPointIndex: draggedPointIndex, bounds: bounds, dragValue: dragValue)
        }
        
        // CRITICAL: Check if caps-lock is pressed to prevent changing the locked pin point
        if isCapsLockPressed && draggedPointIndex != lockedPinPointIndex {
            // Caps-lock is active: locked pin point cannot be changed, only scale away from it
            Log.info("🔒 CAPS-LOCK ACTIVE: Pin point locked, scaling away from locked point", category: .general)
        }
        
        // PROFESSIONAL SCALING: Scale away from the LOCKED PIN POINT (not the dragged point)
        // The locked pin point (RED) stays stationary, we scale away from it toward the drag location
        
        let currentLocation = dragValue.location
        let preciseZoom = Double(zoomLevel)
        
        // Convert locked pin point (anchor) to screen coordinates
        let anchorScreenX = scalingAnchorPoint.x * preciseZoom + canvasOffset.x
        let anchorScreenY = scalingAnchorPoint.y * preciseZoom + canvasOffset.y
        
        // Calculate distance from locked pin to start drag location
        let startDistance = CGPoint(
            x: startLocation.x - anchorScreenX,
            y: startLocation.y - anchorScreenY
        )
        
        // Calculate distance from locked pin to current drag location
        let currentDistance = CGPoint(
            x: currentLocation.x - anchorScreenX,
            y: currentLocation.y - anchorScreenY
        )
        
        // Calculate scale factors: how much bigger/smaller relative to the locked pin point
        let minDistance: CGFloat = 10.0 // Minimum distance to prevent extreme scaling
        let maxScale: CGFloat = 10.0
        let minScale: CGFloat = 0.1
        
        var scaleX = abs(startDistance.x) > minDistance ? abs(currentDistance.x) / abs(startDistance.x) : 1.0
        var scaleY = abs(startDistance.y) > minDistance ? abs(currentDistance.y) / abs(startDistance.y) : 1.0
        
        // Clamp scale factors
        scaleX = min(max(scaleX, minScale), maxScale)
        scaleY = min(max(scaleY, minScale), maxScale)
        
        // PROPORTIONAL SCALING: When shift is held, use uniform scaling
        if isShiftPressed {
            let uniformScale = max(scaleX, scaleY) // Use the larger scale factor
            scaleX = uniformScale
            scaleY = uniformScale
            // Removed excessive logging during drag operations
        } else {
            // Removed excessive logging during drag operations
        }
        
        // Apply preview scaling with the LOCKED PIN POINT as anchor (it stays stationary)
        calculatePreviewTransform(scaleX: scaleX, scaleY: scaleY, anchor: scalingAnchorPoint)
    }
    
    private func startScalingFromPoint(draggedPointIndex: Int?, bounds: CGRect, dragValue: DragGesture.Value) {
        scalingStarted = true
        isScaling = true
        document.isHandleScalingActive = true
        initialBounds = bounds
        initialTransform = shape.transform
        startLocation = dragValue.startLocation
        document.saveToUndoStack()
        
        // CORRECTED LOGIC: Don't change the locked pin point when starting to drag
        // The locked pin point should already be set by a previous single click
        // If no locked pin point is set, default to center
        if lockedPinPointIndex == nil && scalingAnchorPoint == .zero {
            // Default to center if no pin point was explicitly set
            setLockedPinPoint(nil) // nil = center
            Log.fileOperation("🔄 SCALING START: No pin point set, defaulting to center", level: .info)
        }
        
        // SCALING START: Minimal logging for performance
        
        _ = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        // Removed excessive logging during drag operations
    }
    
    private func updatePathPointsAfterScaling() {
        // FORCE REFRESH: Clear current points and re-extract from transformed object
        pathPoints.removeAll()
        
        // FLATTENED SHAPE FIX: Extract points from individual grouped shapes, not container
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            // For flattened shapes, extract points from all grouped shapes
            for groupedShape in shape.groupedShapes {
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to), .line(let to):
                        pathPoints.append(to)
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        pathPoints.append(to)
                    case .close:
                        continue
                    }
                }
            }
        } else {
            // Regular shape: Re-extract all path points from the NOW-TRANSFORMED shape
            for element in shape.path.elements {
                switch element {
                case .move(let to), .line(let to):
                    pathPoints.append(to)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    pathPoints.append(to)
                case .close:
                    continue
                }
            }
        }
        
        // Update center point based on NEW bounds after scaling
        // FLATTENED SHAPE FIX: Use actual path bounds for flattened shapes, not group bounds
        let newBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        centerPoint = VectorPoint(CGPoint(x: newBounds.midX, y: newBounds.midY))
        
        // FORCE VIEW REFRESH: Trigger state change to rebuild UI with new points
        pointsRefreshTrigger += 1
        
        // Removed excessive logging during drag operations
    }
    
    // MARK: - Key Event Monitoring
    // NOTE: Shift key monitoring is now handled by the centralized keyEventMonitor in DrawingCanvas
    // to avoid multiple NSEvent monitors and ensure consistent behavior across all transform tools
    
    // MARK: - Scaling Anchor Point Calculation
    
    /// Get anchor point based on selected scaling mode
    private func getAnchorPoint(for anchor: ScalingAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
        switch anchor {
        case .center:
            return CGPoint(x: bounds.midX, y: bounds.midY)
        case .topLeft:
            return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight:
            return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft:
            return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight:
            return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }
    
    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates
    /// This ensures object origin moves with the object (Professional behavior)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        guard var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
            return
        }
        
        Log.fileOperation("🔧 Applying scaling transform to shape coordinates: \(shape.name)", level: .info)
        
        // FLATTENED SHAPE FIX: Apply transform to individual grouped shapes, not container
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            // Transform each individual shape within the flattened group
            var transformedGroupedShapes: [VectorShape] = []
            
            for var groupedShape in shape.groupedShapes {
                // Transform all path elements of this grouped shape
                var transformedElements: [PathElement] = []
                
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to):
                        let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                        transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                        
                    case .line(let to):
                        let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                        transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                        
                    case .curve(let to, let control1, let control2):
                        let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                        let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(currentTransform)
                        let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(currentTransform)
                        transformedElements.append(.curve(
                            to: VectorPoint(transformedTo),
                            control1: VectorPoint(transformedControl1),
                            control2: VectorPoint(transformedControl2)
                        ))
                        
                    case .quadCurve(let to, let control):
                        let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                        let transformedControl = CGPoint(x: control.x, y: control.y).applying(currentTransform)
                        transformedElements.append(.quadCurve(
                            to: VectorPoint(transformedTo),
                            control: VectorPoint(transformedControl)
                        ))
                        
                    case .close:
                        transformedElements.append(.close)
                    }
                }
                
                // Update this grouped shape with transformed coordinates
                groupedShape.path = VectorPath(elements: transformedElements, isClosed: groupedShape.path.isClosed)
                groupedShape.transform = .identity
                groupedShape.updateBounds()
                
                transformedGroupedShapes.append(groupedShape)
            }
            
            // Update the flattened group with the transformed individual shapes
            shape.groupedShapes = transformedGroupedShapes
            shape.transform = .identity
            shape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
            
            Log.info("✅ Flattened group coordinates updated - transformed \(transformedGroupedShapes.count) individual shapes", category: .fileOperations)
            return
        }
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(currentTransform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(currentTransform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(currentTransform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
                
            case .close:
                transformedElements.append(.close)
            }
        }
        
        // Create new path with transformed coordinates
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        // Update the shape with transformed path and reset transform to identity
        // Get the current shape for corner radius check
        guard let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        
        // CORNER RADIUS SCALING: Apply transform to corner radii if this shape has them
        if !currentShape.cornerRadii.isEmpty && currentShape.isRoundedRectangle {
            var updatedShape = currentShape
            updatedShape.path = transformedPath
            updatedShape.transform = .identity
            applyTransformToCornerRadiiLocal(shape: &updatedShape, transform: currentTransform)
            
            // Use unified helper to update both path and corner radii
            document.updateShapeCornerRadiiInUnified(id: updatedShape.id, cornerRadii: updatedShape.cornerRadii, path: updatedShape.path)
        } else {
            // Use unified helper for regular shape update
            document.updateShapeTransformAndPathInUnified(id: currentShape.id, path: transformedPath, transform: .identity)
        }
        
        Log.info("✅ Shape coordinates updated after scaling - object origin stays with object", category: .fileOperations)
    }
    
    
    
    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        // PROFESSIONAL COORDINATE SYSTEM: Use logical coordinates, let SwiftUI handle screen positioning
        // This prevents off-screen handle positioning issues
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY) // Top-left
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY) // Top-right
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY) // Bottom-right
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY) // Bottom-left
        default: return center
        }
    }
    
    
    
    // FIXED: Calculate preview transform from anchor point (corner pinning)
    private func calculatePreviewTransform(scaleX: CGFloat, scaleY: CGFloat, anchor: CGPoint) {
        // Create scaling transform around the anchor point (opposite corner)
        let scaleTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -anchor.x, y: -anchor.y)
        
        // CRITICAL FIX: Always calculate from initial transform to prevent drift
        previewTransform = initialTransform.concatenating(scaleTransform)
        
        // MARQUEE FIX: Calculate exact final bounds position (PINNED CORRECTLY!)
        let currentBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        finalMarqueeBounds = currentBounds.applying(scaleTransform)
        
        // MARQUEE PREVIEW: Ensure isScaling is true for marquee visibility
        isScaling = true
        
        // Removed excessive logging during drag operations
        
        // CRITICAL FIX: DON'T apply preview to actual shape during dragging (like rectangle tool)
        // This prevents the transformation box from scaling and eliminates drift
        // The preview will be applied only at the end in finishScaling
        
        // Removed excessive logging during drag operations
        
        // Force UI update for preview rendering (without applying to shape)
        document.objectWillChange.send()
    }
    
    /// Check if a corner is the pinned anchor point
    private func isPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.scalingAnchor {
        case .center:
            return false // No corner is pinned when scaling from center
        case .topLeft:
            return cornerIndex == 0 // Top-left corner (index 0)
        case .topRight:
            return cornerIndex == 1 // Top-right corner (index 1)
        case .bottomRight:
            return cornerIndex == 2 // Bottom-right corner (index 2)
        case .bottomLeft:
            return cornerIndex == 3 // Bottom-left corner (index 3)
        }
    }
    
    /// Get scaling anchor for a corner index
    private func getAnchorForCorner(index: Int) -> ScalingAnchor {
        switch index {
        case 0: return .topLeft      // Top-left corner
        case 1: return .topRight     // Top-right corner
        case 2: return .bottomRight  // Bottom-right corner
        case 3: return .bottomLeft   // Bottom-left corner
        default: return .center      // Fallback
        }
    }
    
    // MARK: - Shift Key Monitoring for Proportional Scaling
    @State private var keyEventMonitor: Any?
    
    private func setupKeyEventMonitoring() {
        // DISABLED: NSEvent monitoring to fix text input interference
        // keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
        //     DispatchQueue.main.async {
        //         self.isShiftPressed = event.modifierFlags.contains(.shift)
        //     }
        //     return event
        // }
    }
    
    private func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    // MARK: - Helper Functions for Transform Operations
    
    /// Apply transform to corner radii (local implementation to avoid import issues)
    private func applyTransformToCornerRadiiLocal(shape: inout VectorShape, transform: CGAffineTransform) {
        guard !transform.isIdentity else { return }
        
        // Extract scale factors from transform
        let scaleX = sqrt(transform.a * transform.a + transform.c * transform.c)
        let scaleY = sqrt(transform.b * transform.b + transform.d * transform.d)
        
        // Check for uneven scaling that's too extreme
        let scaleRatio = max(scaleX, scaleY) / min(scaleX, scaleY)
        let maxReasonableRatio: CGFloat = 3.0 // Threshold for "reasonable" scaling
        
        if scaleRatio > maxReasonableRatio {
            // BREAK/EXPAND: Transform is too uneven - disable corner radius tools
            shape.isRoundedRectangle = false
            shape.cornerRadii = []
            shape.originalBounds = nil
            return
        }
        
        // SCALE RADII: Apply proportional scaling to corner radii
        if !shape.cornerRadii.isEmpty {
            let averageScale = (scaleX + scaleY) / 2.0 // Use average scale for corner radii
            
            for i in shape.cornerRadii.indices {
                let oldRadius = shape.cornerRadii[i]
                let newRadius = oldRadius * Double(averageScale)
                shape.cornerRadii[i] = max(0.0, newRadius) // Ensure non-negative
            }
        }
    }
}
