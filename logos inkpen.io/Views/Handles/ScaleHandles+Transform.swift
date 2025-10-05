//
//  ScaleHandles+Transform.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import SwiftUI

// MARK: - Transform & Helper Functions
extension ScaleHandles {
    /// Get anchor point based on selected scaling mode
    func getAnchorPoint(for anchor: ScalingAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
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
    func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
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

    func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
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

    /// Check if a corner is the pinned anchor point
    func isPinnedAnchorCorner(cornerIndex: Int) -> Bool {
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
    func getAnchorForCorner(index: Int) -> ScalingAnchor {
        switch index {
        case 0: return .topLeft      // Top-left corner
        case 1: return .topRight     // Top-right corner
        case 2: return .bottomRight  // Bottom-right corner
        case 3: return .bottomLeft   // Bottom-left corner
        default: return .center      // Fallback
        }
    }

    func setupKeyEventMonitoring() {
        // DISABLED: NSEvent monitoring to fix text input interference
        // keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
        //     DispatchQueue.main.async {
        //         self.isShiftPressed = event.modifierFlags.contains(.shift)
        //     }
        //     return event
        // }
    }

    func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    /// Apply transform to corner radii (local implementation to avoid import issues)
    func applyTransformToCornerRadiiLocal(shape: inout VectorShape, transform: CGAffineTransform) {
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
