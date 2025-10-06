//
//  ScaleHandles+Points.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import SwiftUI

// MARK: - Point-Based Scale System
extension ScaleHandles {
    /// Extract all path points for selection display
    func extractPathPoints() {
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
        centerPoint = VectorPoint(shape.calculateCentroid())

        Log.fileOperation("🎯 EXTRACTED \(pathPoints.count) path points + center for scale anchor selection", level: .info)
    }

    /// Display all path points with correct colors: GREEN = scalable, RED = locked pin
    @ViewBuilder
    func pathPointsView() -> some View {
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

    /// Set which point is the locked pin point (RED) - stays stationary during scaling
    func setLockedPinPoint(_ pointIndex: Int?) {
        lockedPinPointIndex = pointIndex

        // Update the scaling anchor point to the locked pin location
        if let index = pointIndex {
            if index < pathPoints.count {
                // Path point
                let point = pathPoints[index]
                scalingAnchorPoint = CGPoint(x: point.x, y: point.y)
                // Log.info("🔴 LOCKED PIN: Set to path point \(index) at (\(String(format: "%.1f", point.x)), \(String(format: "%.1f", point.y)))", category: .general)
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
                // Log.info("🔴 LOCKED PIN: Set to bounds corner \(cornerIndex) at (\(String(format: "%.1f", scalingAnchorPoint.x)), \(String(format: "%.1f", scalingAnchorPoint.y)))", category: .general)
            }
        } else {
            // Center point
            scalingAnchorPoint = shape.calculateCentroid()
            // Log.info("🔴 LOCKED PIN: Set to center point at (\(String(format: "%.1f", scalingAnchorPoint.x)), \(String(format: "%.1f", scalingAnchorPoint.y)))", category: .general)
        }
    }

    func updatePathPointsAfterScaling() {
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

        // Update center point based on NEW centroid after scaling
        centerPoint = VectorPoint(shape.calculateCentroid())

        // FORCE VIEW REFRESH: Trigger state change to rebuild UI with new points
        pointsRefreshTrigger += 1

        // Removed excessive logging during drag operations
    }
}
