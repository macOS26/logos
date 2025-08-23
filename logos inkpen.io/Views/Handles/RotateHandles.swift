//
//  RotateHandles.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import CoreGraphics
import SwiftUI

// MARK: - Rotate Tool Handles
struct RotateHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool  // Passed from DrawingCanvas for 15-degree increment snapping
    
    // Professional rotation state management
    @State private var isRotating = false
    @State private var rotationStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var rotationAnchorPoint: CGPoint = .zero
    @State private var startAngle: CGFloat = 0.0
    @State private var finalMarqueeBounds: CGRect = .zero  // MARQUEE FIX: Track final destination bounds like scale tool
    
    // POINT-BASED SELECTION SYSTEM: Select actual path points + center for rotation anchor
    @State private var selectedAnchorPointIndex: Int? = nil // Which point is selected as anchor (nil = center)
    @State private var pathPoints: [VectorPoint] = []  // Extracted path points for display
    @State private var centerPoint: VectorPoint = VectorPoint(CGPoint.zero) // Always include center
    @State private var pointsRefreshTrigger: Int = 0 // Force view refresh after transformation
    
    private let handleSize: CGFloat = 8
    
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
            return shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        }
    }
    
    private var calculatedCenter: CGPoint {
        let bounds = calculatedBounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    var body: some View {
        // ROTATE TOOL: Show actual path points + center point for precise anchor selection
        // CRITICAL FIX: For images with transforms, use the same bounds calculation as transform box handles
        // This ensures the rotate tool aligns properly with transformed images
        let bounds = calculatedBounds
        let center = calculatedCenter
        
        ZStack {
            // ACTUAL OBJECT OUTLINE: Show the real shape path, not bounding box
            Path { path in
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
            .stroke(Color.orange, lineWidth: 2.0 / zoomLevel) // Orange outline for rotate tool selection
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(shape.transform)
            
            // MARQUEE PREVIEW: Show ACTUAL ROTATED SHAPE OUTLINE (EXACTLY like the final object will be)
            if isRotating && !previewTransform.isIdentity {
                // CRITICAL FIX: Apply the SAME transformation that will be applied to the actual object
                // Transform the path coordinates directly (same as finishRotation does)
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
                
                // Marquee shows rotation preview without additional handles (handled by point system below)
            }
            
            // SHOW ALL PATH POINTS + CENTER POINT for anchor selection
            pathPointsView()
            
            // CENTER POINT: Always available as rotation anchor
            let isCenterSelected = selectedAnchorPointIndex == nil
            Rectangle()
                .fill(isCenterSelected ? Color.green : Color.orange)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    if !isRotating {
                        selectedAnchorPointIndex = nil // Select center
                        Log.fileOperation("🎯 ANCHOR SELECTED: Center point", level: .info)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            handlePointRotation(anchorPointIndex: nil, dragValue: value, bounds: bounds, center: center)
                        }
                        .onEnded { _ in
                            finishRotation()
                        }
                )
        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
            setupRotationKeyEventMonitoring()
            extractPathPoints()
        }
        .onDisappear {
            teardownRotationKeyEventMonitoring()
        }
        .id("rotation-handles-\(pointsRefreshTrigger)") // Force view rebuild when points update
    }
    
    // MARK: - Point-Based Rotation System
    
    /// Extract all path points for selection display
    private func extractPathPoints() {
        pathPoints.removeAll()
        
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
        
        // Update center point based on current bounds
        // CRITICAL FIX: For images with transforms, use the same bounds calculation as transform box handles
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
            bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        }
        centerPoint = VectorPoint(CGPoint(x: bounds.midX, y: bounds.midY))
        
        Log.fileOperation("🎯 EXTRACTED \(pathPoints.count) path points + center for rotation anchor selection", level: .info)
    }
    
    /// Display all path points as selectable anchors
    @ViewBuilder
    private func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isSelected = selectedAnchorPointIndex == index
            
            Rectangle()
                .fill(isSelected ? Color.green : Color.orange)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(CGPoint(x: point.x, y: point.y))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    if !isRotating {
                        selectedAnchorPointIndex = index
                        print("🎯 ANCHOR SELECTED: Path point \(index) at (\(String(format: "%.1f", point.x)), \(String(format: "%.1f", point.y)))")
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            handlePointRotation(anchorPointIndex: index, dragValue: value, bounds: shape.bounds, center: CGPoint(x: centerPoint.x, y: centerPoint.y))
                        }
                        .onEnded { _ in
                            finishRotation()
                        }
                )
        }
    }
    
    // Handle rotation from selected point
    private func handlePointRotation(anchorPointIndex: Int?, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !rotationStarted {
            startPointRotation(anchorPointIndex: anchorPointIndex, bounds: bounds, dragValue: dragValue)
        }
        
        // ROTATION FIX: Convert anchor point to screen coordinates like scale tool
        let currentLocation = dragValue.location
        
        // Convert anchor point to screen coordinates using manual calculation (same as scale tool)
        let anchorScreenX = rotationAnchorPoint.x * zoomLevel + canvasOffset.x
        let anchorScreenY = rotationAnchorPoint.y * zoomLevel + canvasOffset.y
        let rotationCenter = CGPoint(x: anchorScreenX, y: anchorScreenY)
        
        // Calculate angle from anchor point to current position
        let currentVector = CGPoint(x: currentLocation.x - rotationCenter.x, y: currentLocation.y - rotationCenter.y)
        let startVector = CGPoint(x: startLocation.x - rotationCenter.x, y: startLocation.y - rotationCenter.y)
        
        let currentAngle = atan2(currentVector.y, currentVector.x)
        let initialAngle = atan2(startVector.y, startVector.x)
        var rotationAngle = currentAngle - initialAngle
        
        // Shift key for 15-degree increments
        if isShiftPressed {
            let increment: CGFloat = .pi / 12  // 15 degrees
            rotationAngle = round(rotationAngle / increment) * increment
        }
        
        print("🔄 ROTATING: angle=\(String(format: "%.1f", rotationAngle * 180 / .pi))°, shift=\(isShiftPressed)")
        print("   ⚓ Anchor screen: (\(String(format: "%.1f", anchorScreenX)), \(String(format: "%.1f", anchorScreenY)))")
        
        calculatePreviewRotation(angle: rotationAngle, anchor: rotationAnchorPoint)
    }
    
    private func startPointRotation(anchorPointIndex: Int?, bounds: CGRect, dragValue: DragGesture.Value) {
        rotationStarted = true
        document.isHandleScalingActive = true
        startLocation = dragValue.location
        initialBounds = bounds
        initialTransform = shape.transform
        document.saveToUndoStack()
        
        // AUTO-SELECT: Make the dragged point green (selected) automatically
        selectedAnchorPointIndex = anchorPointIndex
        
        // POINT-BASED ANCHOR: Use selected point or center
        if let pointIndex = anchorPointIndex {
            let point = pathPoints[pointIndex]
            rotationAnchorPoint = CGPoint(x: point.x, y: point.y)
            print("🔄 ROTATION START: Anchored to path point \(pointIndex) at (\(String(format: "%.1f", rotationAnchorPoint.x)), \(String(format: "%.1f", rotationAnchorPoint.y))) - AUTO-SELECTED GREEN")
        } else {
            rotationAnchorPoint = CGPoint(x: centerPoint.x, y: centerPoint.y)
            print("🔄 ROTATION START: Anchored to center point at (\(String(format: "%.1f", rotationAnchorPoint.x)), \(String(format: "%.1f", rotationAnchorPoint.y))) - AUTO-SELECTED GREEN")
        }
        
        print("   📐 Using ORIGINAL bounds: (\(String(format: "%.1f", bounds.minX)), \(String(format: "%.1f", bounds.minY))) → (\(String(format: "%.1f", bounds.maxX)), \(String(format: "%.1f", bounds.maxY)))")
    }
    
    private func updatePathPointsAfterRotation() {
        // FORCE REFRESH: Clear current points and re-extract from transformed object
        pathPoints.removeAll()
        
        // Re-extract all path points from the NOW-TRANSFORMED shape
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
        
        // Update center point based on NEW bounds after rotation
        let newBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        centerPoint = VectorPoint(CGPoint(x: newBounds.midX, y: newBounds.midY))
        
        // FORCE VIEW REFRESH: Trigger state change to rebuild UI with new points
        pointsRefreshTrigger += 1
        
        print("🔄 FORCE UPDATED rotation points - \(pathPoints.count) path points + center at (\(String(format: "%.1f", centerPoint.x)), \(String(format: "%.1f", centerPoint.y)))")
        print("   📐 New bounds: (\(String(format: "%.1f", newBounds.minX)), \(String(format: "%.1f", newBounds.minY))) → (\(String(format: "%.1f", newBounds.maxX)), \(String(format: "%.1f", newBounds.maxY)))")
        Log.info("   🔄 View refresh trigger: \(pointsRefreshTrigger)", category: .general)
    }
    
    // MARK: - Rotation Anchor Point Calculation (Rotation-specific versions)
    
    /// Get anchor point based on selected rotation mode
    private func getRotationAnchorPoint(for anchor: RotationAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
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
    
    /// Check if a corner is the pinned anchor point for rotation
    private func isRotationPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.rotationAnchor {
        case .center:
            return false // No corner is pinned when rotating from center
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
    
    /// Get rotation anchor for a corner index
    private func getRotationAnchorForCorner(index: Int) -> RotationAnchor {
        switch index {
        case 0: return .topLeft      // Top-left corner
        case 1: return .topRight     // Top-right corner
        case 2: return .bottomRight  // Bottom-right corner
        case 3: return .bottomLeft   // Bottom-left corner
        default: return .center      // Fallback
        }
    }
    
    private func rotationCornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
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
    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates (Rotation version)
    /// This ensures object origin moves with the object (Professional behavior)
    private func applyRotationTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
            return
        }
        
        Log.fileOperation("🔧 Applying rotation transform to shape coordinates: \(shape.name)", level: .info)
        
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
        document.layers[layerIndex].shapes[shapeIndex].path = transformedPath
        document.layers[layerIndex].shapes[shapeIndex].transform = .identity
        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
        
        // CORNER RADIUS SCALING: Apply transform to corner radii if this shape has them
        var updatedShape = document.layers[layerIndex].shapes[shapeIndex]
        if !updatedShape.cornerRadii.isEmpty && updatedShape.isRoundedRectangle {
            applyTransformToCornerRadiiLocal(shape: &updatedShape, transform: currentTransform)
            document.layers[layerIndex].shapes[shapeIndex] = updatedShape
        }
        
        Log.info("✅ Shape coordinates updated after rotation - object origin stays with object", category: .fileOperations)
    }
    
    // MARK: - Rotation Key Event Monitoring
    @State private var rotationKeyEventMonitor: Any?
    
    private func setupRotationKeyEventMonitoring() {
        // DISABLED: NSEvent monitoring to fix text input interference
        // rotationKeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
        //     DispatchQueue.main.async {
        //         self.isShiftPressed = event.modifierFlags.contains(.shift)
        //     }
        //     return event
        // }
    }
    
    private func teardownRotationKeyEventMonitoring() {
        if let monitor = rotationKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            rotationKeyEventMonitor = nil
        }
    }
    
    private func startRotation(cornerIndex: Int, bounds: CGRect, dragValue: DragGesture.Value) {
        rotationStarted = true
        document.isHandleScalingActive = true
        startLocation = dragValue.location
        initialBounds = bounds
        initialTransform = shape.transform
        document.saveToUndoStack()
        
        // CRITICAL FIX: Use ORIGINAL bounds (no transform applied) for anchor calculation
        // This prevents anchor drift after multiple transformations
        let originalBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        rotationAnchorPoint = getRotationAnchorPoint(for: document.rotationAnchor, in: originalBounds, cornerIndex: cornerIndex)
        print("🔄 ROTATION START: Corner \(cornerIndex) → Anchor mode: \(document.rotationAnchor.displayName) at (\(String(format: "%.1f", rotationAnchorPoint.x)), \(String(format: "%.1f", rotationAnchorPoint.y)))")
        print("   📐 Using ORIGINAL bounds: (\(String(format: "%.1f", originalBounds.minX)), \(String(format: "%.1f", originalBounds.minY))) → (\(String(format: "%.1f", originalBounds.maxX)), \(String(format: "%.1f", originalBounds.maxY)))")
    }
    
    private func calculatePreviewRotation(angle: CGFloat, anchor: CGPoint) {
        // Create rotation transform around the anchor point
        let rotationTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .rotated(by: angle)
            .translatedBy(x: -anchor.x, y: -anchor.y)
        
        // CRITICAL FIX: Always calculate from initial transform to prevent drift
        previewTransform = initialTransform.concatenating(rotationTransform)
        
        // MARQUEE PREVIEW: Ensure isRotating is true for marquee visibility
        isRotating = true
        
        // ROTATION LOGGING: Track rotation details
        Log.info("   🔄 ROTATION PREVIEW:", category: .general)
        print("      Anchor point: (\(String(format: "%.1f", anchor.x)), \(String(format: "%.1f", anchor.y))) - \(document.rotationAnchor.displayName)")
        print("      Rotation angle: \(String(format: "%.1f", angle * 180 / .pi))°")
        
        print("   📊 Rotation preview updated: angle=\(String(format: "%.1f", angle * 180 / .pi))° - showing ROTATED SHAPE outline")
        
        // Force UI update for preview rendering (without applying to shape)
        document.objectWillChange.send()
    }
    
    private func finishRotation() {
        rotationStarted = false
        isRotating = false
        document.isHandleScalingActive = false
        
        Log.info("🏁 ROTATION FINISH: Applying final transform to coordinates", category: .general)
        print("   📊 Preview transform: [\(String(format: "%.3f", previewTransform.a)), \(String(format: "%.3f", previewTransform.b)), \(String(format: "%.3f", previewTransform.c)), \(String(format: "%.3f", previewTransform.d)), \(String(format: "%.1f", previewTransform.tx)), \(String(format: "%.1f", previewTransform.ty))]")
        
        // CRITICAL FIX: Find the unified object that contains this specific shape
        if let unifiedObject = document.unifiedObjects.first(where: { unifiedObject in
            if case .shape(let targetShape) = unifiedObject.objectType {
                return targetShape.id == shape.id
            }
            return false
        }),
        let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil,
        let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            
            let oldBounds = document.layers[layerIndex].shapes[shapeIndex].bounds
            print("   📐 Old bounds: (\(String(format: "%.1f", oldBounds.minX)), \(String(format: "%.1f", oldBounds.minY))) → (\(String(format: "%.1f", oldBounds.maxX)), \(String(format: "%.1f", oldBounds.maxY)))")
            
            // CRITICAL FIX: Reset to initial transform first to prevent drift accumulation
            document.layers[layerIndex].shapes[shapeIndex].transform = initialTransform
            
            // Apply the final transform to coordinates and reset transform to identity
            applyRotationTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            
            let newBounds = document.layers[layerIndex].shapes[shapeIndex].bounds
            print("   📐 New bounds: (\(String(format: "%.1f", newBounds.minX)), \(String(format: "%.1f", newBounds.minY))) → (\(String(format: "%.1f", newBounds.maxX)), \(String(format: "%.1f", newBounds.maxY)))")
            
            // Reset preview transform
            previewTransform = .identity
            
            Log.info("✅ ROTATION FINISHED: Applied final transform to coordinates and reset transform to identity", category: .fileOperations)
            
            // CRITICAL FIX: Sync unified objects after rotation to ensure UI updates
            document.syncUnifiedObjectsAfterPropertyChange()
            
            // CRITICAL FIX: Force refresh of point selection system (same as switching tools)
            // This updates the points to match the rotated object positions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updatePathPointsAfterRotation()
            }
        } else {
            Log.error("❌ ROTATION FAILED: Could not find shape in unified objects system", category: .error)
        }
        
        previewTransform = .identity
    }
    
    // Helper functions (similar to ScaleHandles)
    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY)
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY)
        default: return center
        }
    }
    
    private func isPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.rotationAnchor {
        case .center: return false
        case .topLeft: return cornerIndex == 0
        case .topRight: return cornerIndex == 1
        case .bottomRight: return cornerIndex == 2
        case .bottomLeft: return cornerIndex == 3
        }
    }
    
    private func getAnchorForCorner(index: Int) -> RotationAnchor {
        switch index {
        case 0: return .topLeft
        case 1: return .topRight
        case 2: return .bottomRight
        case 3: return .bottomLeft
        default: return .center
        }
    }
    
    private func getAnchorPoint(for anchor: RotationAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
        switch anchor {
        case .center: return CGPoint(x: bounds.midX, y: bounds.midY)
        case .topLeft: return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft: return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }
    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates
    /// This ensures object origin moves with the object (Professional behavior)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
            return
        }
        
        Log.fileOperation("🔧 Applying rotation transform to shape coordinates: \(shape.name)", level: .info)
        
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
        document.layers[layerIndex].shapes[shapeIndex].path = transformedPath
        document.layers[layerIndex].shapes[shapeIndex].transform = .identity
        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
        
        Log.info("✅ Shape coordinates updated after rotation - object origin stays with object", category: .fileOperations)
    }
    
    // MARK: - Key Event Monitoring
    // NOTE: Shift key monitoring is now handled by the centralized keyEventMonitor in DrawingCanvas
    // to avoid multiple NSEvent monitors and ensure consistent behavior across all transform tools
    
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
