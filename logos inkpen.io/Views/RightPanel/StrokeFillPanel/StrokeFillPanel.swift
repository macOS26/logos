import SwiftUI
import Combine


struct StrokeFillPanel: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState

    @State private var fillOpacityState: Double = 1.0
    @State private var strokeOpacityState: Double = 1.0
    @State private var strokeWidthState: Double = 1.0
    @State private var strokePlacementState: StrokePlacement = .center
    @State private var strokeMiterLimitState: Double = 10.0
    @State private var selectedImageOpacityState: Double = 1.0

    @State private var cachedIndexMap: [UUID: Int] = [:]
    @State private var isDragging: Bool = false
    @State private var strokePlacementCommitTask: DispatchWorkItem? = nil

    private var selectedStrokeColor: VectorColor {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return shape.typography?.hasStroke == true ? shape.typography?.strokeColor ?? .clear : .clear
                } else {
                    if let strokeColor = shape.strokeStyle?.color {
                        return strokeColor
                    } else {
                        return .clear
                    }
                }
            }
        }
        return document.defaultStrokeColor
    }

    private var selectedFillColor: VectorColor {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return shape.typography?.fillColor ?? .black
                } else {
                    if let fillStyle = shape.fillStyle {
                        return fillStyle.color
                    }
                }
            }
        }
        return document.defaultFillColor
    }

    private var strokeWidth: Double {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return shape.typography?.strokeWidth ?? document.defaultStrokeWidth
                } else {
                    return shape.strokeStyle?.width ?? document.defaultStrokeWidth
                }
            }
        }
        return document.defaultStrokeWidth
    }

    private var strokePlacement: StrokePlacement {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return document.defaultStrokePlacement
                } else {
                    return shape.strokeStyle?.placement ?? document.defaultStrokePlacement
                }
            }
        }
        return document.defaultStrokePlacement
    }

    private var fillOpacity: Double {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return shape.typography?.fillOpacity ?? document.defaultFillOpacity
                } else {
                    if let opacity = shape.fillStyle?.opacity {
                        return opacity
                    }
                }
            }
        }
        return document.defaultFillOpacity
    }

    private var strokeOpacity: Double {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return shape.typography?.strokeOpacity ?? document.defaultStrokeOpacity
                } else {
                    if let opacity = shape.strokeStyle?.opacity {
                        return opacity
                    }
                }
            }
        }
        return document.defaultStrokeOpacity
    }


    private var strokeLineJoin: CGLineJoin {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return document.defaultStrokeLineJoin
                } else {
                    return shape.strokeStyle?.lineJoin.cgLineJoin ?? document.defaultStrokeLineJoin
                }
            }
        }
        return document.defaultStrokeLineJoin
    }

    private var strokeLineCap: CGLineCap {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return document.defaultStrokeLineCap
                } else {
                    return shape.strokeStyle?.lineCap.cgLineCap ?? document.defaultStrokeLineCap
                }
            }
        }
        return document.defaultStrokeLineCap
    }

    private var strokeMiterLimit: Double {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return document.defaultStrokeMiterLimit
                } else {
                    return shape.strokeStyle?.miterLimit ?? document.defaultStrokeMiterLimit
                }
            }
        }
        return document.defaultStrokeMiterLimit
    }

    private var hasSelectedImages: Bool {
        return document.selectedObjectIDs.contains { objectID in
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        return false
                    } else {
                        return ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil
                    }
                }
            }
            return false
        }
    }

    private var selectedImageOpacity: Double {
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        continue
                    } else {
                        if ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                            return shape.opacity
                        }
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
                            document.activeColorTarget = .stroke
                            appState.persistentInkHUD.show(document: document)
                        },
                        onFillColorTap: {
                            document.activeColorTarget = .fill
                            appState.persistentInkHUD.show(document: document)
                        }
                    )

                    FillPropertiesSection(
                        fillOpacity: fillOpacityState,
                        onApplyFill: applyFillToSelectedShapes,
                        onUpdateFillOpacity: { value in
                            fillOpacityState = value
                            updateFillOpacityLive(value, isEditing: true)
                        },
                        onFillOpacityEditingChanged: { isEditing in
                            if isEditing {
                                cachedIndexMap = Dictionary(uniqueKeysWithValues: document.unifiedObjects.enumerated().map { ($0.element.id, $0.offset) })
                            } else {
                                // Save to undo stack BEFORE making any changes
                                document.saveToUndoStack()
                                document.defaultFillOpacity = fillOpacityState
                                updateFillOpacityLive(fillOpacityState, isEditing: false)

                                // Sync unifiedObjects changes back to layers for undo to work
                                let activeShapeIDs = document.getActiveShapeIDs()
                                for shapeID in activeShapeIDs {
                                    if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                                        if case .shape(let unifiedShape) = unifiedObj.objectType {
                                            return unifiedShape.id == shapeID
                                        }
                                        return false
                                    }) {
                                        for layerIndex in document.layers.indices {
                                            let shapes = document.getShapesForLayer(layerIndex)
                                            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                                               let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                                                document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                                                break
                                            }
                                        }
                                    }
                                }

                                cachedIndexMap.removeAll()
                                // Clear preview for text objects
                                for objectID in document.selectedObjectIDs {
                                    document.clearTextPreviewTypography(id: objectID)
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
                        strokeLineJoin: strokeLineJoin,
                        strokeLineCap: strokeLineCap,
                        strokeMiterLimit: strokeMiterLimitState,
                        onUpdateStrokeWidth: { value in
                            strokeWidthState = value
                            updateStrokeWidthLive(value, isEditing: true)
                        },
                        onUpdateStrokePlacement: { value in
                            strokePlacementState = value
                            updateStrokePlacementLive(value)
                        },
                        onUpdateStrokeOpacity: { value in
                            strokeOpacityState = value
                            updateStrokeOpacityLive(value, isEditing: true)
                        },
                        onUpdateLineJoin: { value in
                            document.defaultStrokeLineJoin = value
                            updateStrokeLineJoin(value)
                        },
                        onUpdateLineCap: { value in
                            document.defaultStrokeLineCap = value
                            updateStrokeLineCap(value)
                        },
                        onUpdateMiterLimit: { value in
                            strokeMiterLimitState = value
                            updateStrokeMiterLimitDirectNoUndo(value)
                        },
                        onStrokeWidthEditingChanged: { isEditing in
                            if isEditing {
                                cachedIndexMap = Dictionary(uniqueKeysWithValues: document.unifiedObjects.enumerated().map { ($0.element.id, $0.offset) })
                            } else {
                                document.defaultStrokeWidth = strokeWidthState
                                updateStrokeWidthLive(strokeWidthState, isEditing: false)
                                document.saveToUndoStack()
                                cachedIndexMap.removeAll()
                            }
                        },
                        onStrokeOpacityEditingChanged: { isEditing in
                            if isEditing {
                                cachedIndexMap = Dictionary(uniqueKeysWithValues: document.unifiedObjects.enumerated().map { ($0.element.id, $0.offset) })
                            } else {
                                // Save to undo stack BEFORE making any changes
                                document.saveToUndoStack()
                                document.defaultStrokeOpacity = strokeOpacityState
                                updateStrokeOpacityLive(strokeOpacityState, isEditing: false)

                                // Sync unifiedObjects changes back to layers for undo to work
                                let activeShapeIDs = document.getActiveShapeIDs()
                                for shapeID in activeShapeIDs {
                                    if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                                        if case .shape(let unifiedShape) = unifiedObj.objectType {
                                            return unifiedShape.id == shapeID
                                        }
                                        return false
                                    }) {
                                        for layerIndex in document.layers.indices {
                                            let shapes = document.getShapesForLayer(layerIndex)
                                            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                                               let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                                                document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                                                break
                                            }
                                        }
                                    }
                                }

                                cachedIndexMap.removeAll()
                            }
                        },
                        onMiterLimitEditingChanged: { isEditing in
                            if isEditing {
                                cachedIndexMap = Dictionary(uniqueKeysWithValues: document.unifiedObjects.enumerated().map { ($0.element.id, $0.offset) })
                            } else {
                                document.defaultStrokeMiterLimit = strokeMiterLimitState
                                document.saveToUndoStack()
                                cachedIndexMap.removeAll()
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

                    switch document.currentTool {
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
        .onChange(of: document.selectedObjectIDs) { _, _ in
            syncOpacityStates()
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
        document.defaultFillOpacity = opacity

        var hasChanges = false

        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        document.updateTextFillOpacityInUnified(id: shape.id, opacity: opacity)
                        hasChanges = true
                    } else {
                        if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil,
                           document.getShapesForLayer(layerIndex).contains(where: { $0.id == shape.id }) {
                            document.updateShapeFillOpacityInUnified(id: shape.id, opacity: opacity)
                            hasChanges = true
                        }
                    }
                }
            }
        }

        if hasChanges {
            document.saveToUndoStack()
        }
    }

    private func updateFillOpacityDirectNoUndo(_ opacity: Double) {
        for objectID in document.selectedObjectIDs {
            guard let index = cachedIndexMap[objectID] else { continue }
            if case .shape(var shape) = document.unifiedObjects[index].objectType {
                if shape.isTextObject {
                    shape.typography?.fillOpacity = opacity
                } else {
                    shape.fillStyle?.opacity = opacity
                }
                document.unifiedObjects[index] = VectorObject(
                    shape: shape,
                    layerIndex: document.unifiedObjects[index].layerIndex,
                    orderID: document.unifiedObjects[index].orderID
                )
            }
        }
    }

    /// Updates fill opacity for selected objects using lightweight notifications during dragging.
    /// This provides fast, responsive UI updates without triggering full document republishing.
    /// - Parameters:
    ///   - opacity: The new opacity value (0.0 to 1.0)
    ///   - isEditing: True during dragging (uses preview), false on release (commits change)
    private func updateFillOpacityLive(_ opacity: Double, isEditing: Bool) {
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        if isEditing {
                            document.updateTextFillOpacityPreview(id: shape.id, opacity: opacity)
                        } else {
                            document.updateTextFillOpacityInUnified(id: shape.id, opacity: opacity)
                        }
                    } else {
                        if isEditing {
                            document.updateShapeFillOpacityPreview(id: shape.id, opacity: opacity)
                        } else {
                            document.updateShapeFillOpacityInUnified(id: shape.id, opacity: opacity)
                        }
                    }
                }
            }
        }
    }

    /// Updates stroke opacity for selected objects using lightweight notifications during dragging.
    /// This provides fast, responsive UI updates without triggering full document republishing.
    /// - Parameters:
    ///   - opacity: The new opacity value (0.0 to 1.0)
    ///   - isEditing: True during dragging (uses preview), false on release (commits change)
    private func updateStrokeOpacityLive(_ opacity: Double, isEditing: Bool) {
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if !shape.isTextObject {
                        if isEditing {
                            document.updateShapeStrokeOpacityPreview(id: shape.id, opacity: opacity)
                        } else {
                            document.updateShapeStrokeOpacityInUnified(id: shape.id, opacity: opacity)
                        }
                    }
                }
            }
        }
    }

    /// Updates stroke width for selected objects using lightweight notifications during dragging.
    /// This provides fast, responsive UI updates without triggering full document republishing.
    /// - Parameters:
    ///   - width: The new stroke width value
    ///   - isEditing: True during dragging (uses preview), false on release (commits change)
    private func updateStrokeWidthLive(_ width: Double, isEditing: Bool) {
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        if !isEditing {
                            document.updateTextStrokeWidthInUnified(id: shape.id, width: width)
                        }
                    } else {
                        if isEditing {
                            document.updateShapeStrokeWidthPreview(id: shape.id, width: width)
                        } else {
                            document.updateShapeStrokeWidthInUnified(id: shape.id, width: width)
                        }
                    }
                }
            }
        }
    }

    /// Updates stroke placement for selected shapes using lightweight notifications.
    /// Sends preview FIRST for instant visual update, then commits after 2 second debounce delay.
    /// - Parameter placement: The new stroke placement (center, inside, outside)
    private func updateStrokePlacementLive(_ placement: StrokePlacement) {
        document.defaultStrokePlacement = placement

        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty { return }

        // Send preview notification FIRST for immediate visual update (NO document modification)
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if !shape.isTextObject {
                        document.updateShapeStrokePlacementPreview(id: shape.id, placement: placement)
                    }
                }
            }
        }

        // Cancel any pending commit
        strokePlacementCommitTask?.cancel()

        // Schedule new commit after 2 second debounce (allows rapid menu changes without blocking)
        let commitTask = DispatchWorkItem {
            // Save to undo stack BEFORE making any changes
            self.document.saveToUndoStack()

            for shapeID in activeShapeIDs {
                for layerIndex in self.document.layers.indices {
                    let shapes = self.document.getShapesForLayer(layerIndex)
                    if shapes.firstIndex(where: { $0.id == shapeID }) != nil {
                        self.document.updateShapeStrokePlacementInUnified(id: shapeID, placement: placement)
                        break
                    }
                }
            }

            // Sync unifiedObjects changes back to layers for undo to work
            for shapeID in activeShapeIDs {
                if let unifiedIndex = self.document.unifiedObjects.firstIndex(where: { unifiedObj in
                    if case .shape(let unifiedShape) = unifiedObj.objectType {
                        return unifiedShape.id == shapeID
                    }
                    return false
                }) {
                    for layerIndex in self.document.layers.indices {
                        let shapes = self.document.getShapesForLayer(layerIndex)
                        if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                           let shape = self.document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            self.document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: self.document.unifiedObjects[unifiedIndex].orderID)
                            break
                        }
                    }
                }
            }
        }

        strokePlacementCommitTask = commitTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: commitTask)
    }

    private func updateStrokeWidth(_ width: Double) {
        document.defaultStrokeWidth = width

        var hasChanges = false

        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        document.updateTextStrokeWidthInUnified(id: shape.id, width: width)
                        hasChanges = true
                    } else {
                        if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil,
                           document.getShapesForLayer(layerIndex).contains(where: { $0.id == shape.id }) {
                            document.updateShapeStrokeWidthInUnified(id: shape.id, width: width)
                            hasChanges = true
                        }
                    }
                }
            }
        }

        if hasChanges {
            document.saveToUndoStack()
        }
    }

    private func updateStrokeWidthDirectNoUndo(_ width: Double) {
        for objectID in document.selectedObjectIDs {
            guard let index = cachedIndexMap[objectID] else { continue }
            if case .shape(var shape) = document.unifiedObjects[index].objectType {
                if shape.isTextObject {
                    shape.typography?.strokeWidth = width
                } else {
                    shape.strokeStyle?.width = width
                }
                document.unifiedObjects[index] = VectorObject(
                    shape: shape,
                    layerIndex: document.unifiedObjects[index].layerIndex,
                    orderID: document.unifiedObjects[index].orderID
                )
            }
        }
    }

    private func updateStrokePlacement(_ placement: StrokePlacement) {
        document.defaultStrokePlacement = placement
        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty {
            return
        }

        document.saveToUndoStack()

        for shapeID in activeShapeIDs {
            for layerIndex in document.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if shapes.firstIndex(where: { $0.id == shapeID }) != nil {
                    document.updateShapeStrokePlacementInUnified(id: shapeID, placement: placement)
                    break
                }
            }
        }

        for shapeID in activeShapeIDs {
            if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                if case .shape(let unifiedShape) = unifiedObj.objectType {
                    return unifiedShape.id == shapeID
                }
                return false
            }) {
                for layerIndex in document.layers.indices {
                    let shapes = document.getShapesForLayer(layerIndex)
                    if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                       let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                        document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                        break
                    }
                }
            }
        }
    }

    private func updateStrokeOpacity(_ opacity: Double) {
        document.defaultStrokeOpacity = opacity

        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            document.saveToUndoStack()

            for shapeID in activeShapeIDs {
                for layerIndex in document.layers.indices {
                    if document.getShapesForLayer(layerIndex).contains(where: { $0.id == shapeID }) {
                        document.updateShapeStrokeOpacityInUnified(id: shapeID, opacity: opacity)
                        break
                    }
                }
            }

            for shapeID in activeShapeIDs {
                if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                    if case .shape(let unifiedShape) = unifiedObj.objectType {
                        return unifiedShape.id == shapeID
                    }
                    return false
                }) {
                    for layerIndex in document.layers.indices {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                           let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                            break
                        }
                    }
                }
            }
        }
    }

    private func updateStrokeOpacityDirectNoUndo(_ opacity: Double) {
        for objectID in document.selectedObjectIDs {
            guard let index = cachedIndexMap[objectID] else { continue }
            if case .shape(var shape) = document.unifiedObjects[index].objectType {
                shape.strokeStyle?.opacity = opacity
                document.unifiedObjects[index] = VectorObject(
                    shape: shape,
                    layerIndex: document.unifiedObjects[index].layerIndex,
                    orderID: document.unifiedObjects[index].orderID
                )
            }
        }
    }


    private func updateStrokeLineJoin(_ lineJoin: CGLineJoin) {
        document.defaultStrokeLineJoin = lineJoin

        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            document.saveToUndoStack()

            for shapeID in activeShapeIDs {
                for layerIndex in document.layers.indices {
                    if document.getShapesForLayer(layerIndex).contains(where: { $0.id == shapeID }) {
                        document.updateShapeStrokeLineJoinInUnified(id: shapeID, lineJoin: lineJoin)
                        break
                    }
                }
            }

            for shapeID in activeShapeIDs {
                if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                    if case .shape(let unifiedShape) = unifiedObj.objectType {
                        return unifiedShape.id == shapeID
                    }
                    return false
                }) {
                    for layerIndex in document.layers.indices {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                           let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                            break
                        }
                    }
                }
            }
        }
    }

    private func updateStrokeLineCap(_ lineCap: CGLineCap) {
        document.defaultStrokeLineCap = lineCap

        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            document.saveToUndoStack()

            for shapeID in activeShapeIDs {
                for layerIndex in document.layers.indices {
                    if document.getShapesForLayer(layerIndex).contains(where: { $0.id == shapeID }) {
                        document.updateShapeStrokeLineCapInUnified(id: shapeID, lineCap: lineCap)
                        break
                    }
                }
            }

            for shapeID in activeShapeIDs {
                if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                    if case .shape(let unifiedShape) = unifiedObj.objectType {
                        return unifiedShape.id == shapeID
                    }
                    return false
                }) {
                    for layerIndex in document.layers.indices {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                           let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                            break
                        }
                    }
                }
            }
        }
    }

    private func updateStrokeMiterLimit(_ miterLimit: Double) {
        document.defaultStrokeMiterLimit = miterLimit

        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            document.saveToUndoStack()

            for shapeID in activeShapeIDs {
                for layerIndex in document.layers.indices {
                    if document.getShapesForLayer(layerIndex).contains(where: { $0.id == shapeID }) {
                        document.updateShapeStrokeMiterLimitInUnified(id: shapeID, miterLimit: miterLimit)
                        break
                    }
                }
            }

            for shapeID in activeShapeIDs {
                if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                    if case .shape(let unifiedShape) = unifiedObj.objectType {
                        return unifiedShape.id == shapeID
                    }
                    return false
                }) {
                    for layerIndex in document.layers.indices {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                           let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                            break
                        }
                    }
                }
            }
        }
    }

    private func updateStrokeMiterLimitDirectNoUndo(_ miterLimit: Double) {
        for objectID in document.selectedObjectIDs {
            guard let index = cachedIndexMap[objectID] else { continue }
            if case .shape(var shape) = document.unifiedObjects[index].objectType {
                shape.strokeStyle?.miterLimit = miterLimit
                document.unifiedObjects[index] = VectorObject(
                    shape: shape,
                    layerIndex: document.unifiedObjects[index].layerIndex,
                    orderID: document.unifiedObjects[index].orderID
                )
            }
        }
    }

    private func updateImageOpacity(_ opacity: Double) {
        guard let layerIndex = document.selectedLayerIndex else { return }

        document.saveToUndoStack()

        for shapeID in document.selectedShapeIDs {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
               let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                if ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                    document.updateShapeOpacityInUnified(id: shape.id, opacity: opacity)
                }
            }
        }
    }

    private func applyFillToSelectedShapes() {
        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty { return }

        document.saveToUndoStack()

        for shapeID in activeShapeIDs {
            document.createFillStyleInUnified(id: shapeID, color: selectedFillColor, opacity: fillOpacity)
        }
    }

}
