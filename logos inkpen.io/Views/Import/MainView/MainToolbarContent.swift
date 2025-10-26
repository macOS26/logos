import SwiftUI
import Combine

struct MainToolbarContent: ToolbarContent {
    @ObservedObject var document: VectorDocument
    let appState: AppState
    @Binding var currentDocumentURL: URL?
    @Binding var showingDocumentSettings: Bool
    @Binding var showingColorPicker: Bool
    @Binding var showingImportDialog: Bool
    @Binding var importResult: VectorImportResult?
    @Binding var showingImportProgress: Bool
    @Binding var showingSVGTestHarness: Bool
    @Binding var showingPressureCalibration: Bool
    @Binding var liveDragOffset: CGPoint
    @Binding var liveScaleDimensions: CGSize
    let onRunDiagnostics: () -> Void

    private func hasOpenPaths() -> Bool {
        return hasSelectedPathsToClose()
    }

    private func closeOpenPaths() {
        closeSelectedPaths()
    }

    private func hasSelectedPathsToClose() -> Bool {
        guard !document.viewState.selectedObjectIDs.isEmpty else { return false }

        for objectID in document.viewState.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .text:
                    continue
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):

                    let hasCloseElement = shape.path.elements.contains { element in
                        if case .close = element { return true }
                        return false
                    }

                    let pointCount = shape.path.elements.filter { element in
                        switch element {
                        case .move, .line, .curve, .quadCurve: return true
                        case .close: return false
                        }
                    }.count

                    if !hasCloseElement && pointCount >= 3 {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func closeSelectedPaths() {
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for objectID in document.viewState.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .text:
                    continue
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):

                    if let layerIndex = unifiedObject.layerIndex < document.snapshot.layers.count ? unifiedObject.layerIndex : nil {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if shapes.contains(where: { $0.id == shape.id }) {

                            let hasCloseElement = shape.path.elements.contains { element in
                                if case .close = element { return true }
                                return false
                            }

                            let pointCount = shape.path.elements.filter { element in
                                switch element {
                                case .move, .line, .curve, .quadCurve: return true
                                case .close: return false
                                }
                            }.count

                            if !hasCloseElement && pointCount >= 3 {
                                oldShapes[shape.id] = shape
                                objectIDs.append(shape.id)

                                var newElements = shape.path.elements
                                newElements.append(.close)

                                let newPath = VectorPath(elements: newElements, isClosed: true)
                                document.updateShapePathUnified(id: shape.id, path: newPath)

                                if let updatedObject = document.findObject(by: shape.id),
                                   case .shape(let updatedShape) = updatedObject.objectType {
                                    newShapes[shape.id] = updatedShape
                                }
                            }
                        }
                    }
                }
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }
    }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
#if DEBUG
            Menu {
                Button("SVG Test Harness") {
                    showingSVGTestHarness = true
                }
                .help("Test SVG import and Core Graphics conversion")

                Button("Pressure Calibration") {
                    showingPressureCalibration = true
                }
                .help("Calibrate pressure-sensitive input devices")

                Divider()

                Button("Run Diagnostics") {
                    onRunDiagnostics()
                }
                .help("Run pasteboard diagnostics")

            } label: {
                Image(systemName: "doc.text")
                    .offset(y: 1)
            }
            .help("Development Tools")
#endif

            TransformationControls(document: document, liveDragOffset: $liveDragOffset, liveScaleDimensions: $liveScaleDimensions)

            CornerRadiusToolbar(document: document)

            Button {
                closeOpenPaths()
            } label: {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 20))
                    .offset(y: 1)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        closeOpenPaths()
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Close Open Paths (⌘⇧J)")
            .disabled(!hasOpenPaths())

            Button {
                document.viewState.viewMode = document.viewState.viewMode == .color ? .keyline : .color
            } label: {
                Image(systemName: document.viewState.viewMode.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(document.viewState.viewMode == .keyline ? InkPenUIColors.shared.toolOrange : .primary)
                    .offset(y: 1)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        document.viewState.viewMode = document.viewState.viewMode == .color ? .keyline : .color
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help(document.viewState.viewMode.description)

            Button {
                document.gridSettings.showRulers.toggle()
            } label: {
                Image(systemName: document.gridSettings.showRulers ? "ruler.fill" : "ruler")
                    .font(.system(size: 20))
                    .offset(y: 1)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())

                    .onTapGesture {
                        document.gridSettings.showRulers.toggle()
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Toggle Rulers")

            Button {
                document.gridSettings.showGrid.toggle()
                document.gridSettings.snapToGrid = document.gridSettings.showGrid
            } label: {
                Image(systemName: document.gridSettings.showGrid ? "grid.circle.fill" : "grid.circle")
                    .font(.system(size: 20))
                    .offset(y: 1)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        document.gridSettings.showGrid.toggle()
                        document.gridSettings.snapToGrid = document.gridSettings.showGrid
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Toggle Grid")

            Button {
                onSnapPageToArtwork()
            } label: {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 20))
                    .offset(y: 1)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSnapPageToArtwork()
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Snap Page to Artwork Bounds")

            Button {
                onSnapPageToSelection()
            } label: {
                Image(systemName: "selection.pin.in.out")
                    .font(.system(size: 20))
                    .offset(y: 1)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSnapPageToSelection()
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Snap Page to Selection Bounds")

            Button {
                showingDocumentSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 20))
                    .offset(y: 1)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingDocumentSettings = true
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Document Settings")

            if showingImportProgress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: InkPenUIColors.shared.primaryBlue))
                    .scaleEffect(0.8)
            }

        }
    }

    private func onSnapPageToArtwork() {
        guard let bounds = document.getArtworkBounds(), bounds.width > 0, bounds.height > 0 else { return }

        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for unifiedObject in document.snapshot.objects.values {
            if case .shape(let shape) = unifiedObject.objectType {
                oldShapes[shape.id] = shape
                objectIDs.append(shape.id)
            }
        }

        document.settings.setSizeInPoints(CGSize(width: bounds.width, height: bounds.height))
        document.onSettingsChanged()

        let delta = CGPoint(x: -bounds.minX, y: -bounds.minY)
        document.translateAllContent(by: delta)

        for unifiedObject in document.snapshot.objects.values {
            if case .shape(let shape) = unifiedObject.objectType {
                newShapes[shape.id] = shape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }

        document.requestZoom(to: 0.0, mode: .fitToPage)
    }

    private func onSnapPageToSelection() {
        guard let selectionBounds = getSelectionBoundsForDocument(), selectionBounds.width > 0, selectionBounds.height > 0 else { return }

        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for unifiedObject in document.snapshot.objects.values {
            if case .shape(let shape) = unifiedObject.objectType {
                oldShapes[shape.id] = shape
                objectIDs.append(shape.id)
            }
        }

        document.settings.setSizeInPoints(CGSize(width: selectionBounds.width, height: selectionBounds.height))
        document.onSettingsChanged()

        let delta = CGPoint(x: -selectionBounds.minX, y: -selectionBounds.minY)
        document.translateAllContent(by: delta)

        for unifiedObject in document.snapshot.objects.values {
            if case .shape(let shape) = unifiedObject.objectType {
                newShapes[shape.id] = shape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }

        document.requestZoom(to: 0.0, mode: .fitToPage)
    }

    private func getSelectionBoundsForDocument() -> CGRect? {
        var combinedBounds: CGRect?

        for objectID in document.viewState.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                if unifiedObject.layerIndex >= 2 {
                    switch unifiedObject.objectType {
                    case .shape(let shape),
                         .image(let shape),
                         .text(let shape),
                         .warp(let shape),
                         .group(let shape),
                         .clipGroup(let shape),
                         .clipMask(let shape):
                        let shapeBounds = shape.bounds.applying(shape.transform)
                        combinedBounds = combinedBounds.map { $0.union(shapeBounds) } ?? shapeBounds
                    }
                }
            }
        }
        return combinedBounds
    }

    private func bringSelectedToFront() {
        document.bringSelectedToFront()
    }

    private func bringSelectedForward() {
        document.bringSelectedForward()
    }

    private func sendSelectedBackward() {
        document.sendSelectedBackward()
    }

    private func sendSelectedToBack() {
        document.sendSelectedToBack()
    }

    private func lockSelectedObjects() {
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for objectID in document.viewState.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .text(let shape):
                    oldShapes[shape.id] = shape
                    objectIDs.append(shape.id)
                    document.lockTextInUnified(id: shape.id)
                    if let updatedObject = document.findObject(by: shape.id),
                       case .text(let updatedShape) = updatedObject.objectType {
                        newShapes[shape.id] = updatedShape
                    }
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    oldShapes[shape.id] = shape
                    objectIDs.append(shape.id)

                    if let layerIndex = unifiedObject.layerIndex < document.snapshot.layers.count ? unifiedObject.layerIndex : nil {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if shapes.contains(where: { $0.id == shape.id }) {
                            document.lockShapeInUnified(id: shape.id)
                        }
                    }

                    if let updatedObject = document.findObject(by: shape.id) {
                        newShapes[shape.id] = updatedObject.shape
                    }
                }
            }
        }

        document.viewState.selectedObjectIDs.removeAll()

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }
    }

    private func unlockAllObjects() {
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for unifiedObject in document.snapshot.objects.values {
            if case .shape(let shape) = unifiedObject.objectType {
                oldShapes[shape.id] = shape
                objectIDs.append(shape.id)

                document.unlockShapeInUnified(id: shape.id)
            }
        }

        for unifiedObj in document.snapshot.objects.values {
            if case .text(let shape) = unifiedObj.objectType {
                document.unlockTextInUnified(id: shape.id)
            }
        }

        for unifiedObject in document.snapshot.objects.values {
            if case .shape(let shape) = unifiedObject.objectType {
                newShapes[shape.id] = shape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }
    }

    private func hideSelectedObjects() {
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for objectID in document.viewState.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .text(let shape):
                    oldShapes[shape.id] = shape
                    objectIDs.append(shape.id)
                    document.hideTextInUnified(id: shape.id)
                    if let updatedObject = document.findObject(by: shape.id) {
                        newShapes[shape.id] = updatedObject.shape
                    }
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    oldShapes[shape.id] = shape
                    objectIDs.append(shape.id)
                    if let layerIndex = unifiedObject.layerIndex < document.snapshot.layers.count ? unifiedObject.layerIndex : nil {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if shapes.contains(where: { $0.id == shape.id }) {
                            document.hideShapeInUnified(id: shape.id)
                        }
                    }

                    if let updatedObject = document.findObject(by: shape.id) {
                        newShapes[shape.id] = updatedObject.shape
                    }
                }
            }
        }

        document.viewState.selectedObjectIDs.removeAll()

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }
    }

    private func showAllObjects() {
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for unifiedObject in document.snapshot.objects.values {
            if case .shape(let shape) = unifiedObject.objectType {
                oldShapes[shape.id] = shape
                objectIDs.append(shape.id)

                document.showShapeInUnified(id: shape.id)
            }
        }

        for unifiedObj in document.snapshot.objects.values {
            if case .text(let shape) = unifiedObj.objectType {
                document.showTextInUnified(id: shape.id)
            }
        }

        for unifiedObject in document.snapshot.objects.values {
            if case .shape(let shape) = unifiedObject.objectType {
                newShapes[shape.id] = shape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }
    }
}
