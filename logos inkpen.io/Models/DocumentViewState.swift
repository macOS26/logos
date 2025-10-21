import SwiftUI
import Combine

/// View-only state that should NOT trigger document saves
/// These properties affect UI rendering but are not part of the saved document
class DocumentViewState: ObservableObject {

    // MARK: - Tool State
    @Published var currentTool: DrawingTool = .brush {
        didSet {
            UserDefaults.standard.set(currentTool.rawValue, forKey: "lastUsedTool")
        }
    }

    // MARK: - Transform Controls
    @Published var scalingAnchor: ScalingAnchor = .center
    @Published var rotationAnchor: RotationAnchor = .center
    @Published var shearAnchor: ShearAnchor = .center
    @Published var transformOrigin: TransformOrigin = .center

    // MARK: - Viewport State
    @Published var viewMode: ViewMode = .color
    @Published var zoomLevel: Double = 1.0
    @Published var canvasOffset: CGPoint = .zero
    @Published var zoomRequest: ZoomRequest? = nil

    // MARK: - Color UI State
    @Published var activeColorTarget: ColorTarget = .fill
    @Published var colorChangeNotification: UUID = UUID()
    @Published var lastColorChangeType: ColorChangeType = .fillOpacity

    // MARK: - Canvas Update Triggers
    @Published var canvasTriggers = CanvasUpdateTriggers()

    // MARK: - Preview/Transient State
    @Published var objectPositionUpdateTrigger: Bool = false
    @Published var scalePreviewDimensions: CGSize = .zero
    @Published var warpEnvelopeCorners: [UUID: [CGPoint]] = [:]
    @Published var warpBounds: [UUID: CGRect] = [:]
    @Published var hasPressureInput: Bool = false

    // MARK: - Drag State
    @Published var isDraggingVisibility: Bool = false
    @Published var isDraggingLock: Bool = false

    // MARK: - Selection State (transient, not saved)
    @Published var selectedObjectIDs: Set<UUID> = []

    init() {}

    // MARK: - Canvas Trigger Helpers
    func triggerFillColorUpdate() {
        var triggers = canvasTriggers
        triggers.fillColor.toggle()
        canvasTriggers = triggers
    }

    func triggerStrokeColorUpdate() {
        var triggers = canvasTriggers
        triggers.strokeColor.toggle()
        canvasTriggers = triggers
    }

    func triggerFillOpacityUpdate() {
        var triggers = canvasTriggers
        triggers.fillOpacity.toggle()
        canvasTriggers = triggers
    }

    func triggerStrokeOpacityUpdate() {
        var triggers = canvasTriggers
        triggers.strokeOpacity.toggle()
        canvasTriggers = triggers
    }

    func triggerStrokeWidthUpdate() {
        var triggers = canvasTriggers
        triggers.strokeWidth.toggle()
        canvasTriggers = triggers
    }

    func triggerStrokePlacementUpdate() {
        var triggers = canvasTriggers
        triggers.strokePlacement.toggle()
        canvasTriggers = triggers
    }
}
