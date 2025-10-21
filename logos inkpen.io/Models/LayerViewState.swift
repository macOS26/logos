import SwiftUI

// MARK: - Viewport State
struct ViewportState: Equatable {
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let viewMode: ViewMode
}

// MARK: - Interaction State
struct InteractionState: Equatable {
    let selectedObjectIDs: Set<UUID>
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
}

// MARK: - Transform State
struct TransformState: Equatable {
    let liveScaleTransform: CGAffineTransform
    let liveGradientOriginX: Double?
    let liveGradientOriginY: Double?
}

// MARK: - Layer Properties
struct LayerProperties: Equatable {
    let layerOpacity: Double
    let layerBlendMode: BlendMode
}

// MARK: - Canvas Update Triggers (Granular)
/// Each property change gets its own trigger to minimize redraws
struct CanvasUpdateTriggers: Equatable {
    // Fill properties
    var fillColor: Bool = false
    var fillOpacity: Bool = false
    var fillGradient: Bool = false

    // Stroke properties
    var strokeColor: Bool = false
    var strokeOpacity: Bool = false
    var strokeWidth: Bool = false
    var strokePlacement: Bool = false  // center/inside/outside

    // Gradient properties
    var gradientCenterpoint: Bool = false
    var gradientStops: Bool = false
    var gradientAttributes: Bool = false  // rotation, etc

    // Text properties
    var textContent: Bool = false
    var textAttributes: Bool = false

    // Path/shape changes
    var pathGeometry: Bool = false
    var objectTransform: Bool = false

    /// Toggle all triggers for full redraw
    mutating func toggleAll() {
        fillColor.toggle()
        fillOpacity.toggle()
        fillGradient.toggle()
        strokeColor.toggle()
        strokeOpacity.toggle()
        strokeWidth.toggle()
        strokePlacement.toggle()
        gradientCenterpoint.toggle()
        gradientStops.toggle()
        gradientAttributes.toggle()
        textContent.toggle()
        textAttributes.toggle()
        pathGeometry.toggle()
        objectTransform.toggle()
    }
}
