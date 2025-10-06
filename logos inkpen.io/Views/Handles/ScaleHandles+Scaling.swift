//
//  ScaleHandles+Scaling.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import SwiftUI
import Combine

// MARK: - Scaling Operations
extension ScaleHandles {
    func handleCornerScaling(index: Int, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
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

    func finishScaling() {
        scalingStarted = false
        isScaling = false
        document.isHandleScalingActive = false // CRITICAL: Re-enable canvas drag gestures
        document.scalePreviewDimensions = .zero // Reset preview dimensions

        // Removed excessive logging during drag operations

        // PROFESSIONAL SCALING FIX: Apply the final preview transform to coordinates
        // This ensures object origin stays with object after scaling (Professional behavior)

        // CRITICAL FIX: Find the unified object that contains this specific shape
        // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
        if let unifiedObject = document.findObject(by: shape.id),
        let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {

        let shapes = document.getShapesForLayer(layerIndex)
        if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }),
           var updatedShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {

            // Removed excessive logging during drag operations

            // CRITICAL FIX: Reset to initial transform first to prevent drift accumulation
            updatedShape.transform = initialTransform
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)

            // Apply the final transform to coordinates and reset transform to identity
            applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)

            // Reset preview transform and marquee bounds
            previewTransform = .identity
            finalMarqueeBounds = .zero // Hide marquee


            // Use common update function for transform panel (same as dragging)
            // CRITICAL: Update AFTER a delay to ensure bounds are recalculated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.document.updateTransformPanelValues()
            }

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

    // CORRECTED: Handle scaling away from the locked pin point
    func handleScalingFromPoint(draggedPointIndex: Int?, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !scalingStarted {
            startScalingFromPoint(draggedPointIndex: draggedPointIndex, bounds: bounds, dragValue: dragValue)
        }

        // CRITICAL: Check if caps-lock is pressed to prevent changing the locked pin point
        if isCapsLockPressed && draggedPointIndex != lockedPinPointIndex {
            // Caps-lock is active: locked pin point cannot be changed, only scale away from it
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

    func startScalingFromPoint(draggedPointIndex: Int?, bounds: CGRect, dragValue: DragGesture.Value) {
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
        }

        // SCALING START: Minimal logging for performance

        // Removed excessive logging during drag operations
    }

    // FIXED: Calculate preview transform from anchor point (corner pinning)
    func calculatePreviewTransform(scaleX: CGFloat, scaleY: CGFloat, anchor: CGPoint) {
        // Create scaling transform around the anchor point (opposite corner)
        let scaleTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -anchor.x, y: -anchor.y)

        // CRITICAL FIX: Always calculate from initial transform to prevent drift
        previewTransform = initialTransform.concatenating(scaleTransform)

        // TWO-WAY BINDING: Always update dimensions for immediate feedback
        // Calculate new width and height
        let newWidth = initialBounds.width * abs(scaleX)
        let newHeight = initialBounds.height * abs(scaleY)

        // Update preview dimensions for transform panel - ALWAYS update for smooth feedback
        document.scalePreviewDimensions = CGSize(width: newWidth, height: newHeight)

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
}
