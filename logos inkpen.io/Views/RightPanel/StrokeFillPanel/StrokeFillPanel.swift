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

    // PROTOTYPE: Test anchor point type selection
    @State private var testAnchorType: AnchorPointType = .auto

    private var prototypeAnchorTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anchor Point Type")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Button("Auto") {
                    testAnchorType = .auto
                    print("PROTOTYPE: Set anchor type to Auto")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(testAnchorType == .auto ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(testAnchorType == .auto ? .white : .primary)
                .cornerRadius(4)
                .buttonStyle(PlainButtonStyle())

                Button("Corner") {
                    testAnchorType = .corner
                    applyAnchorTypeToSelection(.corner)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(testAnchorType == .corner ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(testAnchorType == .corner ? .white : .primary)
                .cornerRadius(4)
                .buttonStyle(PlainButtonStyle())

                Button("Cusp") {
                    testAnchorType = .cusp
                    applyAnchorTypeToSelection(.cusp)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(testAnchorType == .cusp ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(testAnchorType == .cusp ? .white : .primary)
                .cornerRadius(4)
                .buttonStyle(PlainButtonStyle())

                Button("Smooth") {
                    testAnchorType = .smooth
                    applyAnchorTypeToSelection(.smooth)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(testAnchorType == .smooth ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(testAnchorType == .smooth ? .white : .primary)
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
        guard let firstSelectedID = selectedObjectIDs.first,
              let object = snapshot.objects[firstSelectedID],
              case .shape(var shape) = object.objectType else {
            print("PROTOTYPE: No shape selected")
            return
        }

        print("PROTOTYPE: Applying \(type) to shape \(firstSelectedID)")

        var elements = shape.path.elements

        for (index, element) in elements.enumerated() {
            guard case .curve(let to, let control1, let control2) = element else { continue }

            switch type {
            case .auto:
                // Do nothing
                break

            case .corner:
                // Collapse both handles to anchor
                let collapsedHandle = VectorPoint(to.x, to.y)
                elements[index] = .curve(to: to, control1: control1, control2: collapsedHandle)

                // Also collapse outgoing handle (next element's control1)
                if index + 1 < elements.count, case .curve(let nextTo, _, let nextControl2) = elements[index + 1] {
                    elements[index + 1] = .curve(to: nextTo, control1: VectorPoint(to.x, to.y), control2: nextControl2)
                }

            case .cusp:
                // Expand handles at 90° if collapsed
                let isIncomingCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)

                if index + 1 < elements.count, case .curve(let nextTo, let nextControl1, let nextControl2) = elements[index + 1] {
                    let isOutgoingCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)

                    if isIncomingCollapsed && isOutgoingCollapsed {
                        // Both collapsed, expand at 90°
                        let handleLength = 50.0
                        let newIncoming = VectorPoint(to.x + handleLength, to.y)
                        let newOutgoing = VectorPoint(to.x, to.y + handleLength)

                        elements[index] = .curve(to: to, control1: control1, control2: newIncoming)
                        elements[index + 1] = .curve(to: nextTo, control1: newOutgoing, control2: nextControl2)
                    }
                }

            case .smooth:
                // Already smooth, do nothing
                break
            }
        }

        shape.path.elements = elements
        shape.updateBounds()

        let updatedObject = VectorObject(id: object.id, layerIndex: object.layerIndex, objectType: .shape(shape))
        snapshot.objects[firstSelectedID] = updatedObject

        print("PROTOTYPE: Applied \(type)")
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
