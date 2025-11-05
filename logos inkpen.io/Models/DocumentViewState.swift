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

    // MARK: - Preview/Transient State
    @Published var objectPositionUpdateTrigger: Bool = false
    @Published var objectUpdateTrigger: UInt = 0
    @Published var layerUpdateTriggers: [UUID: UInt] = [:]  // Per-layer update triggers keyed by Layer.id
    var isLivePointDrag: Bool = false  // Skip spatial index rebuild during live point drags
    @Published var scalePreviewDimensions: CGSize = .zero
    @Published var warpEnvelopeCorners: [UUID: [CGPoint]] = [:]
    @Published var warpBounds: [UUID: CGRect] = [:]
    @Published var hasPressureInput: Bool = false
    @Published var shouldApplyCursorWorkaround: Bool = false  // True when entering edit mode via Arrow->Font double-click

    // MARK: - Drag State
    @Published var isDraggingVisibility: Bool = false
    @Published var isDraggingLock: Bool = false

    // MARK: - Gradient Live State
    @Published var liveGradientOriginX: Double? = nil
    @Published var liveGradientOriginY: Double? = nil

    // MARK: - Selection State (transient, not saved)
    var selectedObjectIDs: Set<UUID> = [] {
        didSet {
            PublishedSelectedObjectIDs = selectedObjectIDs
        }
    }

    @Published var PublishedSelectedObjectIDs: Set<UUID> = []

    // Point selection for direct selection tool
    var selectedPoints: Set<PointID> = [] {
        didSet {
            PublishedSelectedPoints = selectedPoints
        }
    }

    @Published var PublishedSelectedPoints: Set<PointID> = []

    // Handle selection for direct selection tool
    var selectedHandles: Set<HandleID> = [] {
        didSet {
            PublishedSelectedHandles = selectedHandles
        }
    }

    @Published var PublishedSelectedHandles: Set<HandleID> = []

    init() {}
}
