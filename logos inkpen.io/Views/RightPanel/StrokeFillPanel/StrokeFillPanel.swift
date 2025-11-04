import SwiftUI
import Combine

struct StrokeFillPanel: View {
    @Binding var snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    let selectedPoints: Set<PointID>  // PROTOTYPE
    let activeColorTarget: ColorTarget
    @Binding var colorMode: ColorMode
    @Binding var defaultFillColor: VectorColor
    @Binding var defaultStrokeColor: VectorColor
    @Binding var defaultFillOpacity: Double
    @Binding var defaultStrokeOpacity: Double
    @Binding var defaultStrokeWidth: Double
    let strokeDefaults: StrokeDefaults
    let currentSwatches: [VectorColor]
    let currentTool: DrawingTool
    let hasPressureInput: Bool
    let changeToken: UUID
    let onTriggerLayerUpdates: (Set<Int>) -> Void
    let onAddColorSwatch: (VectorColor) -> Void
    let onRemoveColorSwatch: (VectorColor) -> Void
    let onSetActiveColor: (VectorColor) -> Void
    @Binding var colorDeltaColor: VectorColor?
    @Binding var colorDeltaOpacity: Double?
    @Binding var strokeDeltaWidth: Double?
    let onSetActiveColorTarget: (ColorTarget) -> Void
    let onUpdateStrokeDefaults: (StrokeDefaults) -> Void
    let onOutlineSelectedStrokes: () -> Void
    let onDuplicateSelectedShapes: () -> Void
    let onUpdateObjectOpacity: (UUID, Double, ColorTarget) -> Void
    let onUpdateObjectStrokeWidth: (UUID, Double) -> Void
    let onUpdateFillOpacityLive: (Double, Bool) -> Void
    let onUpdateStrokeOpacityLive: (Double, Bool) -> Void
    let onUpdateStrokeWidthLive: (Double, Bool) -> Void
    let onUpdateStrokePlacement: (StrokePlacement) -> Void
    let onUpdateStrokeLineJoin: (CGLineJoin) -> Void
    let onUpdateStrokeLineCap: (CGLineCap) -> Void
    let onUpdateStrokeMiterLimit: (Double) -> Void
    let onUpdateStrokeMiterLimitDirectNoUndo: (Double) -> Void
    let onUpdateStrokeScaleWithTransform: (Bool) -> Void
    let onUpdateImageOpacity: (Double) -> Void
    let onApplyFillToSelectedShapes: (VectorColor, Double) -> Void
    let onUpdateShapeStrokePlacementInUnified: (UUID, StrokePlacement) -> Void

    @Environment(AppState.self) private var appState
    @State private var fillOpacityState: Double = 1.0
    @State private var strokeOpacityState: Double = 1.0
    @State private var strokeWidthState: Double = 1.0
    @State private var strokePlacementState: StrokePlacement = .center
    @State private var strokeMiterLimitState: Double = 10.0
    @State private var selectedImageOpacityState: Double = 1.0
    @State private var isDragging: Bool = false

    // Detect current anchor type from selected points
    private var currentAnchorType: AnchorPointType {
        guard let firstPoint = selectedPoints.first,
              let object = snapshot.objects[firstPoint.shapeID],
              case .shape(let shape) = object.objectType,
              firstPoint.elementIndex < shape.path.elements.count else {
            return .auto
        }

        let element = shape.path.elements[firstPoint.elementIndex]
        let elements = shape.path.elements

        // Check incoming handle (control2 from this element)
        var incomingControl: CGPoint?
        var anchorPoint: CGPoint?

        switch element {
        case .curve(let to, _, let control2):
            let anchor = CGPoint(x: to.x, y: to.y)
            let control = CGPoint(x: control2.x, y: control2.y)
            // Check if handle is collapsed (within 0.5 pixels)
            let dist = sqrt(pow(anchor.x - control.x, 2) + pow(anchor.y - control.y, 2))
            if dist > 0.5 {
                incomingControl = control
            }
            anchorPoint = anchor
        case .move(let to), .line(let to):
            anchorPoint = CGPoint(x: to.x, y: to.y)
        default:
            break
        }

        // Check outgoing handle (control1 from next element)
        var outgoingControl: CGPoint?

        if firstPoint.elementIndex + 1 < elements.count {
            if case .curve(_, let control1, _) = elements[firstPoint.elementIndex + 1] {
                if let anchor = anchorPoint {
                    let control = CGPoint(x: control1.x, y: control1.y)
                    let dist = sqrt(pow(anchor.x - control.x, 2) + pow(anchor.y - control.y, 2))
                    if dist > 0.5 {
                        outgoingControl = control
                    }
                }
            }
        }

        // Determine type based on handles
        guard let anchor = anchorPoint else { return .auto }

        // Corner: no visible handles
        if incomingControl == nil && outgoingControl == nil {
            return .corner
        }

        // Smooth or Cusp: both handles visible
        if let incoming = incomingControl, let outgoing = outgoingControl {
            // Check if handles are collinear (180° aligned)
            let incomingVector = CGPoint(x: anchor.x - incoming.x, y: anchor.y - incoming.y)
            let outgoingVector = CGPoint(x: outgoing.x - anchor.x, y: outgoing.y - anchor.y)

            let incomingAngle = atan2(incomingVector.y, incomingVector.x)
            let outgoingAngle = atan2(outgoingVector.y, outgoingVector.x)

            let angleDiff = abs(incomingAngle - outgoingAngle)
            let isAligned = abs(angleDiff - .pi) < 0.1 || abs(angleDiff + .pi) < 0.1

            return isAligned ? .smooth : .cusp
        }

        // One handle only = cusp
        return .cusp
    }

    private var prototypeAnchorTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anchor Point Type")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Button("Auto") {
                    applyAnchorTypeToSelection(.auto)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(currentAnchorType == .auto ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(currentAnchorType == .auto ? .white : .primary)
                .cornerRadius(4)
                .buttonStyle(PlainButtonStyle())

                Button("Corner") {
                    applyAnchorTypeToSelection(.corner)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(currentAnchorType == .corner ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(currentAnchorType == .corner ? .white : .primary)
                .cornerRadius(4)
                .buttonStyle(PlainButtonStyle())

                Button("Cusp") {
                    applyAnchorTypeToSelection(.cusp)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(currentAnchorType == .cusp ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(currentAnchorType == .cusp ? .white : .primary)
                .cornerRadius(4)
                .buttonStyle(PlainButtonStyle())

                Button("Smooth") {
                    applyAnchorTypeToSelection(.smooth)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(currentAnchorType == .smooth ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(currentAnchorType == .smooth ? .white : .primary)
                .cornerRadius(4)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }

    private func applyAnchorTypeToSelection(_ type: AnchorPointType) {
        guard !selectedPoints.isEmpty else {
            print("No points selected")
            return
        }

        var layersToUpdate = Set<Int>()

        for pointID in selectedPoints {
            guard var object = snapshot.objects[pointID.shapeID],
                  case .shape(var shape) = object.objectType,
                  pointID.elementIndex < shape.path.elements.count else {
                continue
            }

            let elementIndex = pointID.elementIndex
            var elements = shape.path.elements

            // Get anchor position
            guard let anchorPosCG = getAnchorPosition(from: elements[elementIndex]) else { continue }
            let anchorPos = VectorPoint(anchorPosCG.x, anchorPosCG.y)

            // Modify the element and next element based on type
            switch type {
            case .corner:
                // Collapse handles to anchor (corner = no visible handles)
                // Collapse incoming handle (control2 of current element)
                if case .curve(_, let control1, _) = elements[elementIndex] {
                    elements[elementIndex] = .curve(to: anchorPos, control1: control1, control2: anchorPos)
                }
                // Collapse outgoing handle (control1 of next element)
                if elementIndex + 1 < elements.count {
                    if case .curve(let to, _, let control2) = elements[elementIndex + 1] {
                        elements[elementIndex + 1] = .curve(to: to, control1: anchorPos, control2: control2)
                    }
                }

            case .cusp:
                // Keep curves but make them independent
                // Extend handles if they're collapsed
                if case .curve(_, let control1, let control2) = elements[elementIndex] {
                    // Check if incoming handle (control2) is collapsed
                    let dist = sqrt(pow(anchorPos.x - control2.x, 2) + pow(anchorPos.y - control2.y, 2))
                    if dist < 0.5 {
                        let offset = VectorPoint(20, 20)
                        elements[elementIndex] = .curve(to: anchorPos, control1: control1, control2: VectorPoint(anchorPos.x - offset.x, anchorPos.y - offset.y))
                    }
                }
                // Check outgoing handle (control1 of next element)
                if elementIndex + 1 < elements.count {
                    if case .curve(let to, let control1, let control2) = elements[elementIndex + 1] {
                        let dist = sqrt(pow(anchorPos.x - control1.x, 2) + pow(anchorPos.y - control1.y, 2))
                        if dist < 0.5 {
                            let offset = VectorPoint(20, 20)
                            elements[elementIndex + 1] = .curve(to: to, control1: VectorPoint(anchorPos.x + offset.x, anchorPos.y + offset.y), control2: control2)
                        }
                    }
                }

            case .smooth:
                // Make curves collinear (180° aligned)
                if elementIndex + 1 < elements.count {
                    if case .curve(let to, let control1, _) = elements[elementIndex + 1],
                       case .curve(_, _, let control2) = elements[elementIndex] {
                        // Calculate aligned control points
                        let handleLength = distance(from: anchorPosCG, to: control1)
                        let incomingVector = normalize(from: control2, to: anchorPosCG)
                        let newControl1 = VectorPoint(
                            anchorPosCG.x + incomingVector.x * handleLength,
                            anchorPosCG.y + incomingVector.y * handleLength
                        )
                        elements[elementIndex + 1] = .curve(to: to, control1: newControl1, control2: control2)
                    }
                }

            case .auto:
                // Auto mode - keep as is
                break
            }

            // Update the shape
            shape.path = VectorPath(elements: elements)
            shape.updateBounds()
            object = VectorObject(shape: shape, layerIndex: object.layerIndex)
            snapshot.objects[pointID.shapeID] = object
            layersToUpdate.insert(object.layerIndex)
        }

        // Trigger updates for affected layers
        if !layersToUpdate.isEmpty {
            onTriggerLayerUpdates(layersToUpdate)
        }
    }

    private func getAnchorPosition(from element: PathElement) -> CGPoint? {
        switch element {
        case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
            return CGPoint(x: to.x, y: to.y)
        case .close:
            return nil
        }
    }

    private func distance(from p1: CGPoint, to p2: VectorPoint) -> Double {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }

    private func normalize(from p1: VectorPoint, to p2: CGPoint) -> CGPoint {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0.001 else { return CGPoint(x: 1, y: 0) }
        return CGPoint(x: dx / len, y: dy / len)
    }

    private var selectedStrokeColor: VectorColor {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.hasStroke == true ? shape.typography?.strokeColor ?? .clear : .clear
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let strokeColor = shape.strokeStyle?.color {
                    return strokeColor
                } else {
                    return .clear
                }
            }
        }
        return defaultStrokeColor
    }

    private var selectedFillColor: VectorColor {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.fillColor ?? .black
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let fillStyle = shape.fillStyle {
                    return fillStyle.color
                }
            }
        }
        return defaultFillColor
    }

    private var strokeWidth: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.strokeWidth ?? defaultStrokeWidth
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.width ?? defaultStrokeWidth
            }
        }
        return defaultStrokeWidth
    }

    private var strokePlacement: StrokePlacement {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return strokeDefaults.placement
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.placement ?? strokeDefaults.placement
            }
        }
        return strokeDefaults.placement
    }

    private var fillOpacity: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.fillOpacity ?? defaultFillOpacity
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let opacity = shape.fillStyle?.opacity {
                    return opacity
                }
            }
        }
        return defaultFillOpacity
    }

    private var strokeOpacity: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.strokeOpacity ?? defaultStrokeOpacity
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let opacity = shape.strokeStyle?.opacity {
                    return opacity
                }
            }
        }
        return defaultStrokeOpacity
    }

    private var strokeLineJoin: CGLineJoin {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return strokeDefaults.lineJoin
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.lineJoin.cgLineJoin ?? strokeDefaults.lineJoin
            }
        }
        return strokeDefaults.lineJoin
    }

    private var strokeLineCap: CGLineCap {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return strokeDefaults.lineCap
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.lineCap.cgLineCap ?? strokeDefaults.lineCap
            }
        }
        return strokeDefaults.lineCap
    }

    private var strokeMiterLimit: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return strokeDefaults.miterLimit
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.miterLimit ?? strokeDefaults.miterLimit
            }
        }
        return strokeDefaults.miterLimit
    }

    private var strokeScaleWithTransform: Bool {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return false
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.scaleWithTransform ?? false
            }
        }
        return false
    }

    private var hasSelectedImages: Bool {
        return selectedObjectIDs.contains { objectID in
            if let newVectorObject = snapshot.objects[objectID] {
                switch newVectorObject.objectType {
                case .text:
                    return false
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    return shape.linkedImagePath != nil || shape.embeddedImageData != nil
                }
            }
            return false
        }
    }

    private var selectedImageOpacity: Double {
        for objectID in selectedObjectIDs {
            if let newVectorObject = snapshot.objects[objectID] {
                switch newVectorObject.objectType {
                case .text:
                    continue
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    if shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                        return shape.opacity
                    }
                }
            }
        }
        return 1.0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                    CurrentColorsView(
                        strokeColor: selectedStrokeColor,
                        fillColor: selectedFillColor,
                        strokeOpacity: strokeOpacityState,
                        fillOpacity: fillOpacityState,
                        snapshot: $snapshot,
                        selectedObjectIDs: selectedObjectIDs,
                        activeColorTarget: activeColorTarget,
                        colorMode: $colorMode,
                        defaultFillColor: $defaultFillColor,
                        defaultStrokeColor: $defaultStrokeColor,
                        defaultFillOpacity: defaultFillOpacity,
                        defaultStrokeOpacity: defaultStrokeOpacity,
                        currentSwatches: currentSwatches,
                        onTriggerLayerUpdates: onTriggerLayerUpdates,
                        onAddColorSwatch: onAddColorSwatch,
                        onRemoveColorSwatch: onRemoveColorSwatch,
                        onSetActiveColor: onSetActiveColor,
                        colorDeltaColor: $colorDeltaColor,
                        colorDeltaOpacity: $colorDeltaOpacity,
                        onSetActiveColorTarget: onSetActiveColorTarget,
                        onColorSelected: onSetActiveColor
                    )

                    // PROTOTYPE: Anchor Point Type Selector
                    prototypeAnchorTypeSelector

                    FillPropertiesSection(
                        fillOpacity: fillOpacityState,
                        fillColor: selectedFillColor,
                        onApplyFill: applyFillToSelectedShapes,
                        onUpdateFillOpacity: { value in
                            fillOpacityState = value
                            colorDeltaOpacity = value
                            updateFillOpacityLive(value, isEditing: true)
                        },
                        onFillOpacityEditingChanged: { isEditing in
                            if isEditing {
                                colorDeltaOpacity = fillOpacityState
                            } else {
                                colorDeltaOpacity = nil
                                defaultFillOpacity = fillOpacityState
                                for objectID in selectedObjectIDs {
                                    onUpdateObjectOpacity(objectID, fillOpacityState, .fill)
                                }
                            }
                        }
                    )

                    if hasSelectedImages {
                        ImagePropertiesSection(
                            imageOpacity: selectedImageOpacityState,
                            onUpdateImageOpacity: { value in
                                selectedImageOpacityState = value
                                updateImageOpacity(value)
                            }
                        )
                    }

                    StrokePropertiesSection(
                        strokeWidth: strokeWidthState,
                        strokePlacement: strokePlacementState,
                        strokeOpacity: strokeOpacityState,
                        strokeColor: selectedStrokeColor,
                        strokeLineJoin: strokeLineJoin,
                        strokeLineCap: strokeLineCap,
                        strokeMiterLimit: strokeMiterLimitState,
                        strokeScaleWithTransform: strokeScaleWithTransform,
                        onUpdateStrokeWidth: { value in
                            strokeWidthState = value
                            strokeDeltaWidth = value
                            updateStrokeWidthLive(value, isEditing: true)
                        },
                        onUpdateStrokeOpacity: { value in
                            strokeOpacityState = value
                            colorDeltaOpacity = value
                            updateStrokeOpacityLive(value, isEditing: true)
                        },
                        onUpdateStrokePlacement: { value in
                            strokePlacementState = value
                            updateStrokePlacement(value)
                        },
                        onUpdateLineJoin: { value in
                            var updatedDefaults = strokeDefaults
                            updatedDefaults.lineJoin = value
                            onUpdateStrokeDefaults(updatedDefaults)
                            updateStrokeLineJoin(value)
                        },
                        onUpdateLineCap: { value in
                            var updatedDefaults = strokeDefaults
                            updatedDefaults.lineCap = value
                            onUpdateStrokeDefaults(updatedDefaults)
                            updateStrokeLineCap(value)
                        },
                        onUpdateMiterLimit: { value in
                            strokeMiterLimitState = value
                            updateStrokeMiterLimitDirectNoUndo(value)
                        },
                        onUpdateScaleWithTransform: { value in
                            updateStrokeScaleWithTransform(value)
                        },
                        onStrokeWidthEditingChanged: { isEditing in
                            if isEditing {
                                strokeDeltaWidth = strokeWidthState
                            } else {
                                strokeDeltaWidth = nil
                                defaultStrokeWidth = strokeWidthState
                                for objectID in selectedObjectIDs {
                                    onUpdateObjectStrokeWidth(objectID, strokeWidthState)
                                }
                            }
                        },
                        onStrokeOpacityEditingChanged: { isEditing in
                            if isEditing {
                                colorDeltaOpacity = strokeOpacityState
                            } else {
                                colorDeltaOpacity = nil
                                defaultStrokeOpacity = strokeOpacityState
                                for objectID in selectedObjectIDs {
                                    onUpdateObjectOpacity(objectID, strokeOpacityState, .stroke)
                                }
                            }
                        },
                        onMiterLimitEditingChanged: { isEditing in
                            if !isEditing {
                                updateStrokeMiterLimit(strokeMiterLimitState)
                            }
                        }
                    )

                    HStack(spacing: 8) {
                        Button {
                            onOutlineSelectedStrokes()
                        } label: {
                            Text("Expand Stroke")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .onTapGesture {
                            onOutlineSelectedStrokes()
                        }
                        .help("Convert stroke to filled path (Cmd+Shift+O)")
                        .keyboardShortcut("o", modifiers: [.command, .shift])

                        Button {
                            onDuplicateSelectedShapes()
                        } label: {
                            Text("Duplicate")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .onTapGesture {
                            onDuplicateSelectedShapes()
                        }
                        .help("Duplicate selected shapes (Cmd+D)")
                        .keyboardShortcut("d", modifiers: .command)
                    }
                    .padding(.horizontal, 12)

                    switch currentTool {
                    case .freehand:
                        FreehandSettingsSection()
                    case .brush:
                        VariableStrokeSection(hasPressureInput: hasPressureInput)
                    case .marker:
                        MarkerSettingsSection()
                    default:
                        EmptyView()
                    }

                    TransformPreferencesSection()

                Spacer()
            }
            .padding()
        }
        .onAppear {
            syncOpacityStates()
        }
        .onChange(of: selectedObjectIDs) { _, _ in
            syncOpacityStates()
        }
        .onChange(of: changeToken) { _, _ in
            if !isDragging {
                syncOpacityStates()
            }
        }
    }

    private func syncOpacityStates() {
        fillOpacityState = fillOpacity
        strokeOpacityState = strokeOpacity
        strokeWidthState = strokeWidth
        strokePlacementState = strokePlacement
        strokeMiterLimitState = strokeMiterLimit
        selectedImageOpacityState = selectedImageOpacity
    }

    private func updateFillOpacityLive(_ opacity: Double, isEditing: Bool) {
        onUpdateFillOpacityLive(opacity, isEditing)
    }

    private func updateStrokeOpacityLive(_ opacity: Double, isEditing: Bool) {
        onUpdateStrokeOpacityLive(opacity, isEditing)
    }

    private func updateStrokeWidthLive(_ width: Double, isEditing: Bool) {
        onUpdateStrokeWidthLive(width, isEditing)
    }

    private func updateStrokePlacementLive(_ placement: StrokePlacement) {
        var updatedDefaults = strokeDefaults
        updatedDefaults.placement = placement
        onUpdateStrokeDefaults(updatedDefaults)

        for objectID in selectedObjectIDs {
            if let newVectorObject = snapshot.objects[objectID] {
                switch newVectorObject.objectType {
                case .text:
                    break
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    onUpdateShapeStrokePlacementInUnified(shape.id, placement)
                }
            }
        }
    }

    private func updateStrokePlacement(_ placement: StrokePlacement) {
        onUpdateStrokePlacement(placement)
    }

    private func updateStrokeLineJoin(_ lineJoin: CGLineJoin) {
        onUpdateStrokeLineJoin(lineJoin)
    }

    private func updateStrokeLineCap(_ lineCap: CGLineCap) {
        onUpdateStrokeLineCap(lineCap)
    }

    private func updateStrokeMiterLimit(_ miterLimit: Double) {
        onUpdateStrokeMiterLimit(miterLimit)
    }

    private func updateStrokeMiterLimitDirectNoUndo(_ miterLimit: Double) {
        onUpdateStrokeMiterLimitDirectNoUndo(miterLimit)
    }

    private func updateStrokeScaleWithTransform(_ scaleWithTransform: Bool) {
        onUpdateStrokeScaleWithTransform(scaleWithTransform)
    }

    private func updateImageOpacity(_ opacity: Double) {
        onUpdateImageOpacity(opacity)
    }

    private func applyFillToSelectedShapes() {
        onApplyFillToSelectedShapes(selectedFillColor, fillOpacity)
    }

}
