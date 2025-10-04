//
//  ShearHandles.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import SwiftUI
import SwiftUI

// MARK: - Shear Tool Handles
struct ShearHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool  // Passed from DrawingCanvas for constrained shearing
    
    // Professional shear state management - FIXED IMPLEMENTATION (same as scale tool)
    @State private var isShearing = false
    @State private var shearStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var shearAnchorPoint: CGPoint = .zero  // This is the LOCKED/PIN point (RED)
    @State private var isCapsLockPressed = false  // NEW: Track caps-lock for locking pin point
    
    // CORRECTED POINT SYSTEM: Lock point vs shear points (same as scale tool)
    @State private var lockedPinPointIndex: Int? = nil // Which point is LOCKED (RED) - set by single click
    @State private var pathPoints: [VectorPoint] = []  // All path points for display
    @State private var centerPoint: VectorPoint = VectorPoint(CGPoint.zero) // Center point
    @State private var pointsRefreshTrigger: Int = 0
    
    private let handleSize: CGFloat = 10
    
    // CRITICAL FIX: Calculate bounds outside body property to avoid build errors
    private var calculatedBounds: CGRect {
        if ImageContentRegistry.containsImage(shape) && !shape.transform.isIdentity {
            // For transformed images, calculate bounds the same way as transform box handles
            let baseBounds = shape.bounds
            let t = shape.transform
            let corners = [
                CGPoint(x: baseBounds.minX, y: baseBounds.minY).applying(t),
                CGPoint(x: baseBounds.maxX, y: baseBounds.minY).applying(t),
                CGPoint(x: baseBounds.maxX, y: baseBounds.maxY).applying(t),
                CGPoint(x: baseBounds.minX, y: baseBounds.maxY).applying(t)
            ]
            let minX = corners.map { $0.x }.min() ?? baseBounds.minX
            let minY = corners.map { $0.y }.min() ?? baseBounds.minY
            let maxX = corners.map { $0.x }.max() ?? baseBounds.maxX
            let maxY = corners.map { $0.y }.max() ?? baseBounds.maxY
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        } else {
            // For regular shapes and untransformed images, use existing logic
            return shape.isGroupContainer ? shape.groupBounds : shape.bounds
        }
    }
    
    private var calculatedCenter: CGPoint {
        // Calculate the TRUE geometric centroid of the shape using common helper
        return shape.calculateCentroid()
    }
    
    var body: some View {
        // SHEAR TOOL: Show all path points + center point with correct colors (same as scale tool)
        // CRITICAL FIX: For images with transforms, use the same bounds calculation as transform box handles
        // This ensures the shear tool aligns properly with transformed images
        
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
            
            // CENTER POINT: Always available (GREEN if not locked, RED if locked)
            let isCenterLockedPin = (lockedPinPointIndex == nil) // nil represents center as locked pin
            let shapeCenter = shape.calculateCentroid()  // Use true geometric centroid from common helper
            Circle()
                .fill(isCenterLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = shearable
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(CGPoint(
                    x: shapeCenter.x * zoomLevel + canvasOffset.x,
                    y: shapeCenter.y * zoomLevel + canvasOffset.y
                ))
                .onTapGesture {
                    if !isShearing {
                        // SINGLE CLICK: Set center as the locked pin point (RED)
                        setLockedPinPoint(nil) // nil = center
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            // DRAG: Shear away from the locked pin point
                            let actualBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                            let actualCenter = shape.calculateCentroid()  // Use true geometric centroid from common helper
                            handleShearingFromPoint(draggedPointIndex: nil, dragValue: value, bounds: actualBounds, center: actualCenter)
                        }
                        .onEnded { _ in
                            finishShear()
                        }
                )
            
            // MARQUEE PREVIEW: Show ACTUAL SHEARED SHAPE OUTLINE (EXACTLY like the final object will be)
            if isShearing && !previewTransform.isIdentity {
                // CRITICAL FIX: Apply the SAME transformation that will be applied to the actual object
                // Transform the path coordinates directly (same as finishShear does)
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
                
                // MARQUEE CENTER POINT: Show the shear anchor point (stays fixed during shearing)
                let anchorScreenX = shearAnchorPoint.x * zoomLevel + canvasOffset.x
                let anchorScreenY = shearAnchorPoint.y * zoomLevel + canvasOffset.y
                let isCenterPinned = document.shearAnchor == .center
                Circle()
                    .fill(isCenterPinned ? Color.red : Color.green)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize, height: handleSize)
                    .position(x: anchorScreenX, y: anchorScreenY)
            }
            
            
        }
        .onAppear {
            initialBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds  // Use shape bounds for geometric center
            initialTransform = shape.transform
            extractPathPoints()

            // Set default locked pin point to center if none is set
            if lockedPinPointIndex == nil && shearAnchorPoint == .zero {
                setLockedPinPoint(nil) // nil = center point
            }
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            // MOVEMENT FIX: When shape bounds change (e.g., after moving), refresh the shear points
            if !isShearing && oldBounds != newBounds {
                extractPathPoints()
                pointsRefreshTrigger += 1
            }
        }
        .id("shear-handles-\(pointsRefreshTrigger)") // Force view rebuild when points update
    }
    
    
    
    // FIXED: Calculate shear transform with TRUE pin point (different from scale tool approach)
    private func calculatePreviewShear(shearX: CGFloat, shearY: CGFloat, anchor: CGPoint) {
        // SHEAR-SPECIFIC PIN POINT CALCULATION:
        // Unlike scaling, shear transforms move ALL points including the intended anchor
        // We need to calculate the shear, then compensate to keep the pin point stationary
        
        // Step 1: Create the base shear transformation
        let baseShearTransform = CGAffineTransform(a: 1, b: shearY, c: shearX, d: 1, tx: 0, ty: 0)
        
        // Step 2: Calculate where the anchor point would move to with this shear
        let sheared_anchor = anchor.applying(baseShearTransform)
        
        // Step 3: Calculate the translation needed to move it back to original position
        let compensationTranslation = CGAffineTransform(translationX: anchor.x - sheared_anchor.x, y: anchor.y - sheared_anchor.y)
        
        // Step 4: Combine shear + compensation translation to pin the anchor point
        let pinPointShearTransform = baseShearTransform.concatenating(compensationTranslation)
        
        // Step 5: Apply to initial transform to prevent drift
        previewTransform = initialTransform.concatenating(pinPointShearTransform)
        
        // Ensure isShearing is true for preview visibility
        isShearing = true
        
        // Removed excessive logging during drag operations
    }
    
    private func finishShear() {
        shearStarted = false
        isShearing = false
        document.isHandleScalingActive = false
        
        
        // CRITICAL FIX: Find the unified object that contains this specific shape
        // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
        if let unifiedObject = document.findObject(by: shape.id),
        let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {
        let shapes = document.getShapesForLayer(layerIndex)
        if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {
            
            // CRITICAL FIX: Reset to initial transform first to prevent drift accumulation
            if let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                var updatedShape = currentShape
                updatedShape.transform = initialTransform
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            }
            
            // Apply the final transform to coordinates and reset transform to identity
            applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            
            
            // CRITICAL FIX: Sync unified objects after shear to ensure UI updates
            document.updateUnifiedObjectsOptimized()

            // UPDATE X Y W H: Call common update function after shear
            document.updateTransformPanelValues()

            // CRITICAL FIX: Force refresh of point selection system (same as rotation tool)
            // This updates the points to match the sheared object positions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updatePathPointsAfterShear()
            }
        }
        } else {
            // Log.error("❌ SHEAR FAILED: Could not find shape in unified objects system", category: .error)
        }
        
        previewTransform = .identity
    }
    
    // MARK: - Point-Based Shear System (same as rotate tool)
    
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
        
        // Update center point based on true geometric centroid
        let centroid = shape.calculateCentroid()
        centerPoint = VectorPoint(centroid)
        
    }
    
    /// Display all path points with correct colors: GREEN = shearable, RED = locked pin
    @ViewBuilder
    private func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isLockedPin = lockedPinPointIndex == index
            
            Circle()
                .fill(isLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = shearable
                .stroke(Color.white, lineWidth: 1.0 / zoomLevel)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(CGPoint(x: point.x, y: point.y))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    if !isShearing {
                        // SINGLE CLICK: Set this as the locked pin point (RED)
                        setLockedPinPoint(index)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            // DRAG: Shear away from the locked pin point
                            let actualBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                            let actualCenter = shape.calculateCentroid()  // Use true geometric centroid from common helper
                            handleShearingFromPoint(draggedPointIndex: index, dragValue: value, bounds: actualBounds, center: actualCenter)
                        }
                        .onEnded { _ in
                            finishShear()
                        }
                )
        }
    }
    
    // MARK: - Lock Pin Point Management (same as scale tool)
    
    /// Set which point is the locked pin point (RED) - stays stationary during shearing
    private func setLockedPinPoint(_ pointIndex: Int?) {
        lockedPinPointIndex = pointIndex
        
        // Update the shearing anchor point to the locked pin location
        if let index = pointIndex {
            if index < pathPoints.count {
                // Path point
                let point = pathPoints[index]
                shearAnchorPoint = CGPoint(x: point.x, y: point.y)
            } else {
                // Bounds corner point (if we add them later)
                // CRITICAL FIX: Use the same bounds calculation for consistency
                let bounds: CGRect
                if ImageContentRegistry.containsImage(shape) && !shape.transform.isIdentity {
                    // For transformed images, calculate bounds the same way as transform box handles
                    let baseBounds = shape.bounds
                    let t = shape.transform
                    let corners = [
                        CGPoint(x: baseBounds.minX, y: baseBounds.minY).applying(t),
                        CGPoint(x: baseBounds.maxX, y: baseBounds.minY).applying(t),
                        CGPoint(x: baseBounds.maxX, y: baseBounds.maxY).applying(t),
                        CGPoint(x: baseBounds.minX, y: baseBounds.maxY).applying(t)
                    ]
                    let minX = corners.map { $0.x }.min() ?? baseBounds.minX
                    let minY = corners.map { $0.y }.min() ?? baseBounds.minY
                    let maxX = corners.map { $0.x }.max() ?? baseBounds.maxX
                    let maxY = corners.map { $0.y }.max() ?? baseBounds.maxY
                    bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                } else {
                    // For regular shapes and untransformed images, use existing logic
                    bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                }
                let center = CGPoint(x: bounds.midX, y: bounds.midY)
                shearAnchorPoint = center // Fallback to center
            }
        } else {
            // Center point - FIX: Use calculated center that accounts for transforms
            shearAnchorPoint = calculatedCenter
            // Removed excessive logging during drag operations
        }
    }
    
    // CORRECTED: Handle shearing away from the locked pin point (same as scale tool)
    private func handleShearingFromPoint(draggedPointIndex: Int?, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !shearStarted {
            startShearingFromPoint(draggedPointIndex: draggedPointIndex, bounds: bounds, dragValue: dragValue)
        }
        
        // CRITICAL: Check if caps-lock is pressed to prevent changing the locked pin point
        if isCapsLockPressed && draggedPointIndex != lockedPinPointIndex {
            // Caps-lock is active: locked pin point cannot be changed, only shear away from it
        }
        
        // PROFESSIONAL SHEARING: Shear relative to the LOCKED PIN POINT (similar to scale tool)
        // The locked pin point (RED) stays stationary, we calculate shear based on movement relative to it
        
        let currentLocation = dragValue.location
        let preciseZoom = Double(zoomLevel)
        
        // Convert locked pin point (anchor) to screen coordinates
        let anchorScreenX = shearAnchorPoint.x * preciseZoom + canvasOffset.x
        let anchorScreenY = shearAnchorPoint.y * preciseZoom + canvasOffset.y
        
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
        
        // Calculate shear factors based on movement relative to pin point
        // Using the same sensitivity approach as the scale tool
        let sensitivity: CGFloat = 0.002 // Shear sensitivity factor
        
        let deltaX = currentDistance.x - startDistance.x
        let deltaY = currentDistance.y - startDistance.y
        
        // Calculate shear factors: how much to shear based on pin-relative movement
        let shearFactorX = deltaY * sensitivity  // Horizontal shear based on vertical movement
        let shearFactorY = deltaX * sensitivity  // Vertical shear based on horizontal movement
        
        var finalShearX = shearFactorX
        var finalShearY = shearFactorY
        
        // CONSTRAINED SHEARING: When shift is held, constrain to dominant direction
        if isShiftPressed {
            if abs(shearFactorX) > abs(shearFactorY) {
                finalShearY = 0
                // Removed excessive logging during drag operations
            } else {
                finalShearX = 0
                // Removed excessive logging during drag operations
            }
        } else {
            // Removed excessive logging during drag operations
        }
        
        // Apply preview shearing with the LOCKED PIN POINT as anchor (it stays stationary)
        calculatePreviewShear(shearX: finalShearX, shearY: finalShearY, anchor: shearAnchorPoint)
    }
    
    private func startShearingFromPoint(draggedPointIndex: Int?, bounds: CGRect, dragValue: DragGesture.Value) {
        shearStarted = true
        isShearing = true
        document.isHandleScalingActive = true
        initialBounds = bounds
        initialTransform = shape.transform
        startLocation = dragValue.location
        document.saveToUndoStack()
        
        // CORRECTED LOGIC: Don't change the locked pin point when starting to drag
        // The locked pin point should already be set by a previous single click
        // If no locked pin point is set, default to center
        if lockedPinPointIndex == nil && shearAnchorPoint == .zero {
            // Default to center if no pin point was explicitly set
            setLockedPinPoint(nil) // nil = center
        }
        
        // SHEAR START: Minimal logging for performance

        // Removed excessive logging during drag operations
    }
    
    private func updatePathPointsAfterShear() {
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
        
        // Update center point based on NEW bounds after shear
        let newBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        centerPoint = VectorPoint(CGPoint(x: newBounds.midX, y: newBounds.midY))
        
        // FORCE VIEW REFRESH: Trigger state change to rebuild UI with new points
        pointsRefreshTrigger += 1
        
        // Removed excessive logging during drag operations
    }
    
    // MARK: - Key Event Monitoring
    // NOTE: Shift key monitoring is now handled by the centralized keyEventMonitor in DrawingCanvas
    // to avoid multiple NSEvent monitors and ensure consistent behavior across all transform tools
    
    // Helper functions (similar to RotateHandles)
    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY)
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY)
        default: return center
        }
    }
    
    
    
    
    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates
    /// This ensures object origin moves with the object (Professional behavior)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
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
        var updatedShape = shape
        updatedShape.path = transformedPath
        updatedShape.transform = .identity
        updatedShape.updateBounds()
        document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
        
    }
}
