import SwiftUI
import Combine

struct StrokeFillPanel: View {
    let snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    @ObservedObject var document: VectorDocument  // Keep temporarily for methods that need it
    @Environment(AppState.self) private var appState
    @State private var fillOpacityState: Double = 1.0
    @State private var strokeOpacityState: Double = 1.0
    @State private var strokeWidthState: Double = 1.0
    @State private var strokePlacementState: StrokePlacement = .center
    @State private var strokeMiterLimitState: Double = 10.0
    @State private var selectedImageOpacityState: Double = 1.0
    @State private var isDragging: Bool = false

    private var selectedStrokeColor: VectorColor {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.hasStroke == true ? shape.typography?.strokeColor ?? .clear : .clear
            case .shape(let shape),
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
        return document.defaultStrokeColor
    }

    private var selectedFillColor: VectorColor {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.fillColor ?? .black
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let fillStyle = shape.fillStyle {
                    return fillStyle.color
                }
            }
        }
        return document.defaultFillColor
    }

    private var strokeWidth: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.strokeWidth ?? document.defaultStrokeWidth
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.width ?? document.defaultStrokeWidth
            }
        }
        return document.defaultStrokeWidth
    }

    private var strokePlacement: StrokePlacement {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return document.strokeDefaults.placement
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.placement ?? document.strokeDefaults.placement
            }
        }
        return document.strokeDefaults.placement
    }

    private var fillOpacity: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.fillOpacity ?? document.defaultFillOpacity
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let opacity = shape.fillStyle?.opacity {
                    return opacity
                }
            }
        }
        return document.defaultFillOpacity
    }

    private var strokeOpacity: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text(let shape):
                return shape.typography?.strokeOpacity ?? document.defaultStrokeOpacity
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let opacity = shape.strokeStyle?.opacity {
                    return opacity
                }
            }
        }
        return document.defaultStrokeOpacity
    }

    private var strokeLineJoin: CGLineJoin {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return document.strokeDefaults.lineJoin
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.lineJoin.cgLineJoin ?? document.strokeDefaults.lineJoin
            }
        }
        return document.strokeDefaults.lineJoin
    }

    private var strokeLineCap: CGLineCap {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return document.strokeDefaults.lineCap
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.lineCap.cgLineCap ?? document.strokeDefaults.lineCap
            }
        }
        return document.strokeDefaults.lineCap
    }

    private var strokeMiterLimit: Double {
        if let firstSelectedObjectID = selectedObjectIDs.first,
           let newVectorObject = snapshot.objects[firstSelectedObjectID] {
            switch newVectorObject.objectType {
            case .text:
                return document.strokeDefaults.miterLimit
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.strokeStyle?.miterLimit ?? document.strokeDefaults.miterLimit
            }
        }
        return document.strokeDefaults.miterLimit
    }

    private var hasSelectedImages: Bool {
        return document.viewState.selectedObjectIDs.contains { objectID in
            if let newVectorObject = document.snapshot.objects[objectID] {
                switch newVectorObject.objectType {
                case .text:
                    return false
                case .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    return ImageContentRegistry.containsImage(shape, in: document) || shape.linkedImagePath != nil || shape.embeddedImageData != nil
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
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    if ImageContentRegistry.containsImage(shape, in: document) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
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
                        onStrokeColorTap: {
                            document.viewState.activeColorTarget = .stroke
                            appState.persistentInkHUD.show(document: document)
                        },
                        onFillColorTap: {
                            document.viewState.activeColorTarget = .fill
                            appState.persistentInkHUD.show(document: document)
                        }
                    )

                    FillPropertiesSection(
                        fillOpacity: fillOpacityState,
                        fillColor: selectedFillColor,
                        onApplyFill: applyFillToSelectedShapes,
                        onUpdateFillOpacity: { value in
                            fillOpacityState = value
                            updateFillOpacityLive(value, isEditing: true)
                        },
                        onFillOpacityEditingChanged: { isEditing in
                            if isEditing {
                                // No need for index map when using snapshot directly
                            } else {
                                PaintSelectionOperations.shared.handleFillOpacityEditingComplete(fillOpacityState, document: document)
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
                        document: document,
                        strokeWidth: strokeWidthState,
                        strokePlacement: strokePlacementState,
                        strokeOpacity: strokeOpacityState,
                        strokeColor: selectedStrokeColor,
                        strokeLineJoin: strokeLineJoin,
                        strokeLineCap: strokeLineCap,
                        strokeMiterLimit: strokeMiterLimitState,
                        onUpdateStrokeWidth: { value in
                            strokeWidthState = value
                            updateStrokeWidthLive(value, isEditing: true)
                        },
                        onUpdateStrokeOpacity: { value in
                            strokeOpacityState = value
                            updateStrokeOpacityLive(value, isEditing: true)
                        },
                        onUpdateStrokePlacement: { value in
                            strokePlacementState = value
                            updateStrokePlacement(value)
                        },
                        onUpdateLineJoin: { value in
                            document.strokeDefaults.lineJoin = value
                            updateStrokeLineJoin(value)
                        },
                        onUpdateLineCap: { value in
                            document.strokeDefaults.lineCap = value
                            updateStrokeLineCap(value)
                        },
                        onUpdateMiterLimit: { value in
                            strokeMiterLimitState = value
                            updateStrokeMiterLimitDirectNoUndo(value)
                        },
                        onStrokeWidthEditingChanged: { isEditing in
                            if isEditing {
                                // No need for index map when using snapshot directly
                            } else {
                                PaintSelectionOperations.shared.handleStrokeWidthEditingComplete(strokeWidthState, document: document)
                            }
                        },
                        onStrokeOpacityEditingChanged: { isEditing in
                            if isEditing {
                                // No need for index map when using snapshot directly
                            } else {
                                PaintSelectionOperations.shared.handleStrokeOpacityEditingComplete(strokeOpacityState, document: document)
                            }
                        },
                        onMiterLimitEditingChanged: { isEditing in
                            if isEditing {
                                // No need for index map when using snapshot directly
                            } else {
                                PaintSelectionOperations.shared.handleMiterLimitEditingComplete(strokeMiterLimitState, document: document)
                            }
                        }
                    )

                    HStack(spacing: 8) {
                        Button {
                            document.outlineSelectedStrokes()
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
                            document.outlineSelectedStrokes()
                        }
                        .help("Convert stroke to filled path (Cmd+Shift+O)")
                        .keyboardShortcut("o", modifiers: [.command, .shift])

                        Button {
                            document.duplicateSelectedShapes()
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
                            document.duplicateSelectedShapes()
                        }
                        .help("Duplicate selected shapes (Cmd+D)")
                        .keyboardShortcut("d", modifiers: .command)
                    }
                    .padding(.horizontal, 12)

                    switch document.viewState.currentTool {
                    case .freehand:
                        FreehandSettingsSection(document: document)
                    case .brush:
                        VariableStrokeSection(document: document)
                    case .marker:
                        MarkerSettingsSection(document: document)
                    default:
                        EmptyView()
                    }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            syncOpacityStates()
        }
        .onChange(of: document.viewState.selectedObjectIDs) { _, _ in
            syncOpacityStates()
        }
        .onChange(of: document.changeNotifier.changeToken) { _, _ in
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

    private func updateFillOpacity(_ opacity: Double) {
        PaintSelectionOperations.shared.updateFillOpacity(opacity, document: document)
    }

    private func updateFillOpacityDirectNoUndo(_ opacity: Double) {
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .text(let shape):
                document.updateTextFillOpacityInUnified(id: shape.id, opacity: opacity)
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                document.updateShapeFillOpacityInUnified(id: shape.id, opacity: opacity)
            }
        }
    }

    private func updateFillOpacityLive(_ opacity: Double, isEditing: Bool) {
        PaintSelectionOperations.shared.updateFillOpacityLive(opacity, document: document, isEditing: isEditing)
    }

    private func updateStrokeOpacityLive(_ opacity: Double, isEditing: Bool) {
        PaintSelectionOperations.shared.updateStrokeOpacityLive(opacity, document: document, isEditing: isEditing)
    }

    private func updateStrokeWidthLive(_ width: Double, isEditing: Bool) {
        PaintSelectionOperations.shared.updateStrokeWidthLive(width, document: document, isEditing: isEditing)
    }

    private func updateStrokePlacementLive(_ placement: StrokePlacement) {
        document.strokeDefaults.placement = placement

        for objectID in selectedObjectIDs {
            if let newVectorObject = snapshot.objects[objectID] {
                switch newVectorObject.objectType {
                case .text:
                    break
                case .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    document.updateShapeStrokePlacementInUnified(id: shape.id, placement: placement)
                }
            }
        }
    }

    private func updateStrokeWidth(_ width: Double) {
        // This method is called when slider finishes editing - handled in onStrokeWidthEditingChanged
        // The actual update is done via PaintSelectionOperations in that callback
    }

    private func updateStrokeWidthDirectNoUndo(_ width: Double) {
        PaintSelectionOperations.shared.updateStrokeWidthLive(width, document: document, isEditing: false)
    }

    private func updateStrokePlacement(_ placement: StrokePlacement) {
        PaintSelectionOperations.shared.updateStrokePlacement(placement, document: document)
    }

    private func updateStrokeOpacity(_ opacity: Double) {
        // This method is called when slider finishes editing - handled in onStrokeOpacityEditingChanged
        // The actual update is done via PaintSelectionOperations in that callback
    }

    private func updateStrokeOpacityDirectNoUndo(_ opacity: Double) {
        PaintSelectionOperations.shared.updateStrokeOpacityLive(opacity, document: document, isEditing: false)
    }

    private func updateStrokeLineJoin(_ lineJoin: CGLineJoin) {
        PaintSelectionOperations.shared.updateStrokeLineJoin(lineJoin, document: document)
    }

    private func updateStrokeLineCap(_ lineCap: CGLineCap) {
        PaintSelectionOperations.shared.updateStrokeLineCap(lineCap, document: document)
    }

    private func updateStrokeMiterLimit(_ miterLimit: Double) {
        PaintSelectionOperations.shared.updateStrokeMiterLimit(miterLimit, document: document)
    }

    private func updateStrokeMiterLimitDirectNoUndo(_ miterLimit: Double) {
        PaintSelectionOperations.shared.updateStrokeMiterLimitDirectNoUndo(miterLimit, document: document)
    }

    private func updateImageOpacity(_ opacity: Double) {
        PaintSelectionOperations.shared.updateImageOpacity(opacity, document: document)
    }

    private func applyFillToSelectedShapes() {
        PaintSelectionOperations.shared.applyFillToSelectedShapes(fillColor: selectedFillColor, fillOpacity: fillOpacity, document: document)
    }

}
