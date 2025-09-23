//
//  EnvelopeHandles.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import SwiftUI
import SwiftUI
import Combine

// MARK: - Envelope Warping Tool Handles
struct EnvelopeHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    // Professional envelope warping state management
    @State private var isWarping = false
    @State private var warpingStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewPath: VectorPath? = nil
    @State private var isShiftPressed = false  // For proportional warping
    
    // ENVELOPE BOUNDING BOX SYSTEM: 4 corner points that define the warp envelope
    @State private var originalCorners: [CGPoint] = []  // Original bounding box corners
    @State private var warpedCorners: [CGPoint] = []    // Current warped positions
    @State private var draggingCornerIndex: Int? = nil  // Which corner is being dragged
    
    private let handleSize: CGFloat = 10
    private let handleHitAreaSize: CGFloat = 15  // Larger hit area for easier selection
    
    var body: some View {
        // ENVELOPE TOOL: Show bounding box corners with correct colors
        let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        
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
                        .stroke(Color.purple, lineWidth: 2.0 / zoomLevel)
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
                    .stroke(Color.purple, lineWidth: 2.0 / zoomLevel)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }
            
            // ENVELOPE BOUNDING BOX: Show the 4 corner handles
            envelopeCornerHandles()
            
            // ENVELOPE GRID: Show the warp grid when envelope tool is active
            if document.currentTool == .warp && warpedCorners.count == 4 {
                envelopeGridPreview()
            }
            
            // WARPED PREVIEW: Show the warped shape when there's a preview (continuous editing)
            if let _ = previewPath {
                warpedShapePreview()
            }
        }
        .onAppear {
            initialBounds = bounds
            initialTransform = shape.transform
            setupEnvelopeKeyEventMonitoring()
            initializeEnvelopeCorners()
        }
        .onDisappear {
            teardownEnvelopeKeyEventMonitoring()
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            // MOVEMENT FIX: When shape bounds change, refresh the envelope corners
            // CRITICAL FIX: Don't recalculate axis during active warping or when warp handles are already established
            if !isWarping && !warpingStarted && warpedCorners.isEmpty && oldBounds != newBounds {
                initializeEnvelopeCorners()
                Log.fileOperation("🔄 ENVELOPE TOOL: Shape bounds changed, refreshed corners", level: .info)
            }
        }
        .onChange(of: document.currentTool) { oldTool, newTool in
            // ENVELOPE COMMIT: When switching away from envelope tool, commit any pending warp
            if oldTool == .warp && newTool != .warp {
                // First commit any pending warp transformation
                if previewPath != nil {
                    commitEnvelopeWarp()
                }
                
                // CRITICAL FIX: DON'T clear envelope state - preserve warp memory
                // This allows continuous editing when switching back to envelope tool
                Log.fileOperation("🔄 ENVELOPE TOOL: Switched away - committed warp and PRESERVED state", level: .info)
            }
            
            // ENVELOPE REACTIVATION: When switching back to envelope tool, reinitialize for current shape
            if oldTool != .warp && newTool == .warp {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.initializeEnvelopeCorners()
                }
                Log.fileOperation("🔄 ENVELOPE TOOL: Reactivated - initializing for current shape", level: .info)
            }
        }
        .onChange(of: document.selectedShapeIDs) { oldSelection, newSelection in
            // ENVELOPE COMMIT: When shape selection changes, commit current warp and reset for new shape
            if document.currentTool == .warp && oldSelection != newSelection {
                // First commit any pending warp transformation on the old shape
                if previewPath != nil {
                    commitEnvelopeWarp()
                }
                
                // CLEAR PREVIEW: When switching to different shape, clear old preview
                previewPath = nil
                
                // Then reset the envelope state for the new shape
                originalCorners.removeAll()
                warpedCorners.removeAll()
                
                // Initialize envelope for the new shape
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.initializeEnvelopeCorners()
                }
                
                Log.fileOperation("🔄 ENVELOPE TOOL: Shape selection changed - committed warp and reset for new shape", level: .info)
            }
        }
    }
    
    // MARK: - Envelope Corner Handles
    
    @ViewBuilder
    private func envelopeCornerHandles() -> some View {
        // Only show handles if corners are properly initialized
        if warpedCorners.count == 4 {
            ForEach(0..<4) { cornerIndex in
                let cornerPos = warpedCorners[cornerIndex]

                ZStack {
                    // White outline for better visibility against any background
                    Circle()
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize + 2, height: handleSize + 2)

                    // Visible handle - blue like TransformBox handles
                    Circle()
                        .fill(Color.blue)
                        .frame(width: handleSize, height: handleSize)

                    // Invisible expanded hit area for easier selection (on top)
                    Circle()
                        .fill(Color.clear)
                        .frame(width: handleHitAreaSize, height: handleHitAreaSize)
                        .contentShape(Circle())
                }
            .position(CGPoint(x: cornerPos.x * zoomLevel + canvasOffset.x,
                              y: cornerPos.y * zoomLevel + canvasOffset.y))
            // ACTUAL PATH CORNERS FIX: Never apply transform since we use actual path points
            // (Path points already contain the object's geometry and rotation)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0.5) // Small threshold like TransformBox
                    .onChanged { value in
                        // DRAG: Warp envelope from this corner
                        handleEnvelopeWarp(cornerIndex: cornerIndex, dragValue: value)
                    }
                    .onEnded { _ in
                        finishEnvelopeWarp()
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private func envelopeGridPreview() -> some View {
        // Show a 3x3 or 4x4 grid overlay showing the warp distortion
        let gridLines = 4
        
        // Horizontal grid lines
        ForEach(0..<4) { row in
            let t = CGFloat(row) / CGFloat(gridLines - 1)
            Path { path in
                let startPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: 0.0, v: t
                )
                let endPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: 1.0, v: t
                )
                path.move(to: startPoint)
                path.addLine(to: endPoint)
            }
            .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            // ACTUAL PATH CORNERS FIX: Never apply transform since we use actual path points
            .opacity(0.6)
        }
        
        // Vertical grid lines
        ForEach(0..<4) { col in
            let u = CGFloat(col) / CGFloat(gridLines - 1)
            Path { path in
                let startPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: u, v: 0.0
                )
                let endPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: u, v: 1.0
                )
                path.move(to: startPoint)
                path.addLine(to: endPoint)
            }
            .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            // ACTUAL PATH CORNERS FIX: Never apply transform since we use actual path points
            .opacity(0.6)
        }
    }
    
    @ViewBuilder
    private func warpedShapePreview() -> some View {
        if let warpedPath = previewPath {
            Path { path in
                for element in warpedPath.elements {
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
            .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .opacity(0.8)
        }
    }
    
    // MARK: - Envelope Warping Logic
    
    private func initializeEnvelopeCorners() {
        // WARP OBJECT HANDLING: Check if shape is already a warp object FIRST
        // Warp objects have originalPath and warpEnvelope
        if shape.isWarpObject && !shape.warpEnvelope.isEmpty, let originalPath = shape.originalPath {
            // Calculate original envelope from the original path bounds
            let originalBounds = originalPath.cgPath.boundingBoxOfPath
            originalCorners = [
                CGPoint(x: originalBounds.minX, y: originalBounds.minY),
                CGPoint(x: originalBounds.maxX, y: originalBounds.minY),
                CGPoint(x: originalBounds.maxX, y: originalBounds.maxY),
                CGPoint(x: originalBounds.minX, y: originalBounds.maxY)
            ]
            warpedCorners = shape.warpEnvelope  // Current warp envelope

            Log.fileOperation("🔧 WARP OBJECT: Using saved warp envelope", level: .info)
            print("   Current Warp Envelope: [\(shape.warpEnvelope.map { "(\(String(format: "%.1f", $0.x)),\(String(format: "%.1f", $0.y)))" }.joined(separator: ", "))]")

            Log.info("   🎯 Continuous warping enabled - can warp from current state", category: .general)

            // REACTIVATION: Set preview to current warped shape for immediate visual feedback
            previewPath = shape.path  // Show current warped state immediately
            Log.info("   🔄 REACTIVATION: Set preview to current warped shape (\(shape.path.elements.count) elements)", category: .general)

            return
        }

        // CHECK FOR STORED WARP BOUNDS (only for non-warp objects that were previously warped in this session)
        if let storedBounds = document.warpBounds[shape.id],
           let storedCorners = document.warpEnvelopeCorners[shape.id], storedCorners.count == 4 {
            // Use the stored warp envelope for regular shapes that were warped in this session
            originalCorners = storedCorners
            warpedCorners = storedCorners
            Log.fileOperation("🔧 SESSION WARP RESTORED: Using stored envelope from current session", level: .info)
            print("📍 USING SESSION WARP BOUNDS: \(storedBounds)")
            return
        }
        
        // Use axis plane dtection for four pounted shapes or four ointed gorups and flattened objects
        // otherwise use the bounding box
        if shape.path.elements.count <= 4 || shape.isGroup {
            let newOriginalCorners = calculateOrientedBoundingBox(for: shape)
            originalCorners = newOriginalCorners
            warpedCorners = newOriginalCorners

            // ONLY initialize warp bounds if they don't exist yet - NEVER overwrite!
            if document.warpBounds[shape.id] == nil {
                let minX = newOriginalCorners.map { $0.x }.min() ?? 0
                let maxX = newOriginalCorners.map { $0.x }.max() ?? 0
                let minY = newOriginalCorners.map { $0.y }.min() ?? 0
                let maxY = newOriginalCorners.map { $0.y }.max() ?? 0
                let newBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                print("⚠️ INITIALIZING NEW WARP BOUNDS (4-point shape): \(newBounds)")
                document.warpBounds[shape.id] = newBounds
                document.warpEnvelopeCorners[shape.id] = newOriginalCorners
            } else {
                print("✅ KEEPING EXISTING WARP BOUNDS (4-point shape): \(document.warpBounds[shape.id]!)")
            }
        } else {
            let bounds = shape.bounds
            let newOriginalCorners = [
                CGPoint(x: bounds.minX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.maxY),
                CGPoint(x: bounds.minX, y: bounds.maxY)
            ]
            originalCorners = newOriginalCorners
            warpedCorners = newOriginalCorners

            // ONLY initialize warp bounds if they don't exist yet - NEVER overwrite!
            if document.warpBounds[shape.id] == nil {
                print("⚠️ INITIALIZING NEW WARP BOUNDS (regular shape): \(bounds)")
                document.warpBounds[shape.id] = bounds
                document.warpEnvelopeCorners[shape.id] = newOriginalCorners
            } else {
                print("✅ KEEPING EXISTING WARP BOUNDS (regular shape): \(document.warpBounds[shape.id]!)")
            }
        }
        
        Log.fileOperation("🔧 ENVELOPE INITIALIZED: Using \(originalCorners.count) corners", level: .info)
    }
    
    private func cornersHaveChangedSignificantly(from oldCorners: [CGPoint], to newCorners: [CGPoint]) -> Bool {
        guard oldCorners.count == 4 && newCorners.count == 4 else { return true }
        
        let threshold: CGFloat = 1.0 // 1 pixel tolerance
        for i in 0..<4 {
            let oldCorner = oldCorners[i]
            let newCorner = newCorners[i]
            if abs(oldCorner.x - newCorner.x) > threshold || abs(oldCorner.y - newCorner.y) > threshold {
                return true
            }
        }
        return false
    }
    
    
    
    private func handleEnvelopeWarp(cornerIndex: Int, dragValue: DragGesture.Value) {
        if !warpingStarted {
            startEnvelopeWarp(cornerIndex: cornerIndex, dragValue: dragValue)
        }
        
        // Convert drag location to canvas coordinates
        let currentLocation = dragValue.location
        let preciseZoom = Double(zoomLevel)
        let canvasLocation = CGPoint(
            x: (currentLocation.x - canvasOffset.x) / preciseZoom,
            y: (currentLocation.y - canvasOffset.y) / preciseZoom
        )
        
        // Update the warped corner position
        warpedCorners[cornerIndex] = canvasLocation

        // STORE WARP ENVELOPE: Save corners to document for persistence
        document.warpEnvelopeCorners[shape.id] = warpedCorners

        // STORE WARP BOUNDS: Calculate and store the bounds rectangle
        let minX = warpedCorners.map { $0.x }.min() ?? 0
        let maxX = warpedCorners.map { $0.x }.max() ?? 0
        let minY = warpedCorners.map { $0.y }.min() ?? 0
        let maxY = warpedCorners.map { $0.y }.max() ?? 0
        document.warpBounds[shape.id] = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // Calculate the warped shape preview
        calculateEnvelopeWarpPreview()
    }
    
    private func startEnvelopeWarp(cornerIndex: Int, dragValue: DragGesture.Value) {
        warpingStarted = true
        isWarping = true
        document.isHandleScalingActive = true // Prevent canvas dragging
        
        // CRITICAL FIX: Use correct reference bounds for warp objects
        if shape.isWarpObject && originalCorners.count == 4 {
            // For warp objects, use the original corners to calculate reference bounds
            let minX = min(originalCorners[0].x, originalCorners[1].x, originalCorners[2].x, originalCorners[3].x)
            let maxX = max(originalCorners[0].x, originalCorners[1].x, originalCorners[2].x, originalCorners[3].x)
            let minY = min(originalCorners[0].y, originalCorners[1].y, originalCorners[2].y, originalCorners[3].y)
            let maxY = max(originalCorners[0].y, originalCorners[1].y, originalCorners[2].y, originalCorners[3].y)
            initialBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            print("🔧 WARP OBJECT: Using original bounds for reference: (\(String(format: "%.1f", minX)), \(String(format: "%.1f", minY))) → (\(String(format: "%.1f", maxX)), \(String(format: "%.1f", maxY)))")
        } else if shape.isWarpObject, let originalPath = shape.originalPath {
            // Fallback: Use original path bounds if corners aren't available
            initialBounds = originalPath.cgPath.boundingBoxOfPath
            Log.fileOperation("🔧 WARP OBJECT: Using original path bounds for reference", level: .info)
        } else {
            // For regular shapes, use current bounds
            initialBounds = shape.bounds
            Log.fileOperation("🔧 REGULAR SHAPE: Using current bounds for reference", level: .info)
        }
        
        initialTransform = shape.transform
        startLocation = dragValue.startLocation
        draggingCornerIndex = cornerIndex
        document.saveToUndoStack()
        
        Log.fileOperation("🔧 ENVELOPE WARP STARTED: Corner \(cornerIndex)", level: .info)
    }
    
    private func calculateEnvelopeWarpPreview() {
        // Apply bilinear transformation to create warped shape
        guard originalCorners.count == 4 && warpedCorners.count == 4 else { return }
        
        // CRITICAL FIX: Handle different object types properly
        if shape.isWarpObject, let originalPath = shape.originalPath {
            // WARP OBJECT: Use the original unwrapped path for clean transformations
            let warpedElements = warpPathElements(originalPath.elements)
            previewPath = VectorPath(elements: warpedElements, isClosed: originalPath.isClosed)
            // Using original path for warp object transformation
        } else if shape.isGroup && !shape.groupedShapes.isEmpty {
            // GROUP/FLATTENED OBJECT: Warp all individual shapes within the group
            var allWarpedElements: [PathElement] = []
            
            for groupedShape in shape.groupedShapes {
                let warpedElements = warpPathElements(groupedShape.path.elements)
                allWarpedElements.append(contentsOf: warpedElements)
                
                // Add a move to separate shapes if needed
                if !allWarpedElements.isEmpty && groupedShape != shape.groupedShapes.last {
                    // Separation is handled naturally by individual shape paths
                }
            }
            
            previewPath = VectorPath(elements: allWarpedElements, isClosed: false)
            Log.info("   🔧 Warping \(shape.groupedShapes.count) grouped shapes (flattened/group object)", category: .general)
        } else {
            // REGULAR SHAPE: Use current path
            let warpedElements = warpPathElements(shape.path.elements)
            previewPath = VectorPath(elements: warpedElements, isClosed: shape.path.isClosed)
            // Using current path for regular shape transformation
        }
        
        // Envelope warp preview updated
    }
    
    private func warpPathElements(_ elements: [PathElement]) -> [PathElement] {
        var warpedElements: [PathElement] = []
        
        for element in elements {
            switch element {
            case .move(let to):
                let warpedPoint = warpPoint(CGPoint(x: to.x, y: to.y))
                warpedElements.append(.move(to: VectorPoint(warpedPoint)))
                
            case .line(let to):
                let warpedPoint = warpPoint(CGPoint(x: to.x, y: to.y))
                warpedElements.append(.line(to: VectorPoint(warpedPoint)))
                
            case .curve(let to, let control1, let control2):
                let warpedTo = warpPoint(CGPoint(x: to.x, y: to.y))
                let warpedControl1 = warpPoint(CGPoint(x: control1.x, y: control1.y))
                let warpedControl2 = warpPoint(CGPoint(x: control2.x, y: control2.y))
                warpedElements.append(.curve(
                    to: VectorPoint(warpedTo),
                    control1: VectorPoint(warpedControl1),
                    control2: VectorPoint(warpedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let warpedTo = warpPoint(CGPoint(x: to.x, y: to.y))
                let warpedControl = warpPoint(CGPoint(x: control.x, y: control.y))
                warpedElements.append(.quadCurve(
                    to: VectorPoint(warpedTo),
                    control: VectorPoint(warpedControl)
                ))
                
            case .close:
                warpedElements.append(.close)
            }
        }
        
        return warpedElements
    }
    
    private func warpPoint(_ point: CGPoint) -> CGPoint {
        // ORIENTED BOUNDING BOX FIX: Use actual original corners for coordinate transformation
        guard originalCorners.count == 4 else {
            // Fallback to axis-aligned approach
            let bounds = initialBounds
            let u = (point.x - bounds.minX) / bounds.width
            let v = (point.y - bounds.minY) / bounds.height
            
            return bilinearInterpolation(
                topLeft: warpedCorners[0],
                topRight: warpedCorners[1],
                bottomLeft: warpedCorners[3],
                bottomRight: warpedCorners[2],
                u: u, v: v
            )
        }
        
        // Convert point from oriented bounding box to normalized coordinates (0-1)
        // Use inverse bilinear interpolation to find (u,v) coordinates in the original oriented quad
        let (u, v) = inverseBilinearInterpolation(
            point: point,
            topLeft: originalCorners[0],     // Top-left
            topRight: originalCorners[1],    // Top-right
            bottomLeft: originalCorners[3],  // Bottom-left
            bottomRight: originalCorners[2]  // Bottom-right
        )
        
        // Use bilinear interpolation to map to warped quadrilateral
        return bilinearInterpolation(
            topLeft: warpedCorners[0],     // Top-left
            topRight: warpedCorners[1],    // Top-right
            bottomLeft: warpedCorners[3],  // Bottom-left
            bottomRight: warpedCorners[2], // Bottom-right
            u: u, v: v
        )
    }
    
    // MARK: - Bilinear Interpolation Math
    
    private func bilinearInterpolation(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, u: CGFloat, v: CGFloat) -> CGPoint {
        // Standard bilinear interpolation formula
        let top = CGPoint(
            x: topLeft.x * (1 - u) + topRight.x * u,
            y: topLeft.y * (1 - u) + topRight.y * u
        )
        let bottom = CGPoint(
            x: bottomLeft.x * (1 - u) + bottomRight.x * u,
            y: bottomLeft.y * (1 - u) + bottomRight.y * u
        )
        
        return CGPoint(
            x: top.x * (1 - v) + bottom.x * v,
            y: top.y * (1 - v) + bottom.y * v
        )
    }
    
    private func inverseBilinearInterpolation(point: CGPoint, topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) -> (u: CGFloat, v: CGFloat) {
        // Find (u,v) coordinates where point lies within the quadrilateral
        // This is more complex for arbitrary quadrilaterals, so we'll use an iterative approach
        
        // For simple axis-aligned rectangles, this would be:
        // u = (point.x - topLeft.x) / (topRight.x - topLeft.x)
        // v = (point.y - topLeft.y) / (bottomLeft.y - topLeft.y)
        
        // For oriented rectangles, we need to solve the bilinear system
        // We'll use Newton's method or a simplified approach for rectangular shapes
        
        // Calculate vectors for the oriented rectangle
        let rightVector = CGPoint(x: topRight.x - topLeft.x, y: topRight.y - topLeft.y)
        let downVector = CGPoint(x: bottomLeft.x - topLeft.x, y: bottomLeft.y - topLeft.y)
        let pointVector = CGPoint(x: point.x - topLeft.x, y: point.y - topLeft.y)
        
        // For rectangles, we can solve this as a 2x2 linear system
        // pointVector = u * rightVector + v * downVector
        
        let det = rightVector.x * downVector.y - rightVector.y * downVector.x
        
        if abs(det) < 1e-10 {
            // Degenerate case - fallback to simple projection
            let rightLength = sqrt(rightVector.x * rightVector.x + rightVector.y * rightVector.y)
            let downLength = sqrt(downVector.x * downVector.x + downVector.y * downVector.y)
            
            let u: CGFloat = rightLength > 0 ?
            (pointVector.x * rightVector.x + pointVector.y * rightVector.y) / (rightLength * rightLength) : 0
            let v: CGFloat = downLength > 0 ?
            (pointVector.x * downVector.x + pointVector.y * downVector.y) / (downLength * downLength) : 0
            
            return (u: max(0, min(1, u)), v: max(0, min(1, v)))
        }
        
        // Solve the 2x2 system using Cramer's rule
        let u = (pointVector.x * downVector.y - pointVector.y * downVector.x) / det
        let v = (rightVector.x * pointVector.y - rightVector.y * pointVector.x) / det
        
        // Clamp to [0,1] range
        return (u: max(0, min(1, u)), v: max(0, min(1, v)))
    }
    
    private func finishEnvelopeWarp() {
        // CONTINUOUS EDITING: Update the shape coordinates but keep envelope active
        warpingStarted = false
        isWarping = false
        document.isHandleScalingActive = false
        draggingCornerIndex = nil

        // CRITICAL: Update stored warp bounds when finishing warp
        if warpedCorners.count == 4 {
            let minX = warpedCorners.map { $0.x }.min() ?? 0
            let maxX = warpedCorners.map { $0.x }.max() ?? 0
            let minY = warpedCorners.map { $0.y }.min() ?? 0
            let maxY = warpedCorners.map { $0.y }.max() ?? 0
            document.warpBounds[shape.id] = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            document.warpEnvelopeCorners[shape.id] = warpedCorners
            print("📍 WARP FINISH: Stored final bounds: \(document.warpBounds[shape.id]!)")
        }
        
        // ENVELOPE DRAG FINISHED: Minimal logging for performance
        
        // REAL-TIME UPDATE: Apply the current warp to the shape immediately
        updateShapeWithCurrentWarp()
        
        // Note: Bounds update happens automatically when the warp object is created and stored
        
        print("   Current envelope: TL(\(String(format: "%.1f", warpedCorners[0].x)), \(String(format: "%.1f", warpedCorners[0].y))), TR(\(String(format: "%.1f", warpedCorners[1].x)), \(String(format: "%.1f", warpedCorners[1].y))), BR(\(String(format: "%.1f", warpedCorners[2].x)), \(String(format: "%.1f", warpedCorners[2].y))), BL(\(String(format: "%.1f", warpedCorners[3].x)), \(String(format: "%.1f", warpedCorners[3].y)))")
        
        // Keep preview for visual feedback but refresh it for next transformation
        calculateEnvelopeWarpPreview()
        
        // CRITICAL FIX: Sync unified objects after warping to ensure UI updates
        document.updateUnifiedObjectsOptimized()
    }
    
    private func updateShapeWithCurrentWarp() {
        // CRITICAL FIX: Find the unified object that contains this specific shape
        guard let unifiedObject = document.unifiedObjects.first(where: { unifiedObject in
            if case .shape(let targetShape) = unifiedObject.objectType {
                return targetShape.id == shape.id
            }
            return false
        }),
        let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil else { return }
        let shapes = document.getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) else { return }
        
        guard let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        
        if currentShape.isWarpObject {
            // Update existing warp object with new warped coordinates
            var updatedWarpObject = currentShape
            
            if currentShape.isGroup && !currentShape.groupedShapes.isEmpty {
                // WARP OBJECT + GROUP: Warp each individual shape in the group
                var warpedGroupedShapes: [VectorShape] = []
                
                for groupedShape in currentShape.groupedShapes {
                    let warpedElements = warpPathElements(groupedShape.path.elements)
                    let warpedPath = VectorPath(elements: warpedElements, isClosed: groupedShape.path.isClosed)
                    
                    var warpedGrouped = groupedShape
                    warpedGrouped.path = warpedPath
                    // Update bounds for grouped shapes
                    warpedGrouped.updateBounds()
                    warpedGroupedShapes.append(warpedGrouped)
                }
                
                updatedWarpObject.groupedShapes = warpedGroupedShapes
                Log.info("   🔄 Updated warp object with \(warpedGroupedShapes.count) warped grouped shapes", category: .general)
            } else if let finalWarpedPath = previewPath {
                // WARP OBJECT + SINGLE SHAPE: Update the main path
                updatedWarpObject.path = finalWarpedPath
                Log.info("   🔄 Updated warp object with single warped path", category: .general)
            }
            
            updatedWarpObject.warpEnvelope = warpedCorners
            // Update bounds after warping changes
            updatedWarpObject.updateBounds()
            
            // Update the entire warp object in unified system, not just the path
            if let objectIndex = document.unifiedObjects.firstIndex(where: { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.id == updatedWarpObject.id
                }
                return false
            }) {
                document.unifiedObjects[objectIndex] = VectorObject(
                    shape: updatedWarpObject,
                    layerIndex: document.unifiedObjects[objectIndex].layerIndex,
                    orderID: document.unifiedObjects[objectIndex].orderID
                )
                // Sync to layers
                document.syncShapeToLayer(updatedWarpObject, at: document.unifiedObjects[objectIndex].layerIndex)
            }
            Log.info("   ✅ Updated existing warp object coordinates in real-time", category: .general)
        } else {
            // First-time warp: create warp object
            var warpObject = currentShape
            warpObject.id = UUID() // New ID for the warp object
            warpObject.name = "Warped " + currentShape.name
            warpObject.isWarpObject = true
            warpObject.warpEnvelope = warpedCorners
            warpObject.transform = .identity
            
            if currentShape.isGroup && !currentShape.groupedShapes.isEmpty {
                // GROUP/FLATTENED OBJECT: Store original grouped shapes and create warped versions
                warpObject.originalPath = nil // Groups don't have a single original path
                
                // Warp each individual shape in the group
                var warpedGroupedShapes: [VectorShape] = []
                
                for groupedShape in currentShape.groupedShapes {
                    let warpedElements = warpPathElements(groupedShape.path.elements)
                    let warpedPath = VectorPath(elements: warpedElements, isClosed: groupedShape.path.isClosed)
                    
                    var warpedGrouped = groupedShape
                    warpedGrouped.path = warpedPath
                    // Update bounds for grouped shapes
                    warpedGrouped.updateBounds()
                    warpedGroupedShapes.append(warpedGrouped)
                }
                
                warpObject.groupedShapes = warpedGroupedShapes
                Log.info("   ✅ Created warp object from group with \(warpedGroupedShapes.count) warped shapes", category: .general)
            } else if let finalWarpedPath = previewPath {
                // SINGLE SHAPE: Store original path and use warped path
                warpObject.originalPath = currentShape.path
                warpObject.path = finalWarpedPath
                Log.info("   ✅ Created warp object from single shape", category: .general)
            }
            
            // Update bounds after warping is complete
            warpObject.updateBounds()

            // Use unified helper to update warped shape
            document.updateShapePathUnified(id: warpObject.id, path: warpObject.path)
        
        // CRITICAL FIX: Update selection to use unified objects system
        document.selectedObjectIDs.remove(currentShape.id)
        document.selectedObjectIDs.insert(warpObject.id)
        
        // CRITICAL FIX: Manually update unified objects system for shape replacement
        // Don't use updateUnifiedObjectsOptimized() as it's designed for property changes, not shape replacements
        if let unifiedObjectIndex = document.unifiedObjects.firstIndex(where: { unifiedObject in
            if case .shape(let targetShape) = unifiedObject.objectType {
                return targetShape.id == currentShape.id
            }
            return false
        }) {
            // Replace the unified object with the new warp object
            document.unifiedObjects[unifiedObjectIndex] = VectorObject(
                shape: warpObject,
                layerIndex: unifiedObject.layerIndex,
                orderID: unifiedObject.orderID
            )
            Log.info("   🔧 UNIFIED OBJECTS: Replaced original shape with warp object", category: .general)
        } else {
            // Fallback: Add the warp object to unified system if not found
            document.addShapeToUnifiedSystem(warpObject, layerIndex: layerIndex)
            Log.info("   🔧 UNIFIED OBJECTS: Added warp object to unified system", category: .general)
        }

        Log.info("   🎯 First-time warp completed - created new warp object", category: .general)
    }
    
    // Log final warp state
    print("🏁 WARP COMPLETED: Final envelope TL(\(String(format: "%.1f", warpedCorners[0].x)), \(String(format: "%.1f", warpedCorners[0].y))), TR(\(String(format: "%.1f", warpedCorners[1].x)), \(String(format: "%.1f", warpedCorners[1].y))), BR(\(String(format: "%.1f", warpedCorners[2].x)), \(String(format: "%.1f", warpedCorners[2].y))), BL(\(String(format: "%.1f", warpedCorners[3].x)), \(String(format: "%.1f", warpedCorners[3].y)))")
    
    document.objectWillChange.send()
    }
    
    private func commitEnvelopeWarp() {
        Log.info("🏁 ENVELOPE WARP COMMIT: Finalizing envelope editing session", category: .general)

        // CRITICAL: Store final warp bounds when committing
        if warpedCorners.count == 4 {
            let minX = warpedCorners.map { $0.x }.min() ?? 0
            let maxX = warpedCorners.map { $0.x }.max() ?? 0
            let minY = warpedCorners.map { $0.y }.min() ?? 0
            let maxY = warpedCorners.map { $0.y }.max() ?? 0
            document.warpBounds[shape.id] = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            document.warpEnvelopeCorners[shape.id] = warpedCorners
            print("📍 WARP COMMIT: Stored final bounds: \(document.warpBounds[shape.id]!)")
        }

        // The shape has already been updated in real-time during editing
        // PRESERVE PREVIEW: Keep the preview when switching away so it shows correctly when returning
        // Don't clear previewPath - this maintains the warped shape preview for reactivation
        
        Log.info("📍 ENVELOPE SESSION COMPLETE: Warp object finalized", category: .general)
        Log.fileOperation("🔄 REACTIVATABLE: Select envelope tool again to continue editing", level: .info)
        Log.fileOperation("📋 UNWRAP VIA MENU: Use Object menu to unwrap back to original", level: .info)
        Log.info("   🎯 PREVIEW PRESERVED: Will show correct state when reactivating", category: .general)
    }
    
    // MARK: - Key Event Monitoring
    
    @State private var envelopeKeyEventMonitor: Any?
    
    private func setupEnvelopeKeyEventMonitoring() {
        // DISABLED: NSEvent monitoring to fix text input interference
        // envelopeKeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
        //     DispatchQueue.main.async {
        //         self.isShiftPressed = event.modifierFlags.contains(.shift)
        //     }
        //     return event
        // }
    }
    
    private func teardownEnvelopeKeyEventMonitoring() {
        if let monitor = envelopeKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            envelopeKeyEventMonitor = nil
        }
    }
}

