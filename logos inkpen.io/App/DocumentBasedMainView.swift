import SwiftUI
import UniformTypeIdentifiers

struct DocumentBasedMainView: View {
    @ObservedObject var document: VectorDocument
    let fileURL: URL?
    @StateObject private var documentState = DocumentState()
    @Environment(AppState.self) private var appState
    @State private var showingDocumentSettings = false
    @State private var showingColorPicker = false
    @State private var currentDocumentURL: URL? = nil
    @State private var showingImportDialog = false
    @State private var importResult: VectorImportResult?
    @State private var showingImportProgress = false
    @State private var showingSVGTestHarness = false
    @State private var showingPressureCalibration = false
    @State private var hasInitializedTool = false
    @State private var layerPreviewOpacities: [UUID: Double] = [:]
    @State private var liveDragOffset: CGPoint = .zero
    @State private var liveScaleDimensions: CGSize = .zero
    @State private var liveScaleTransform: CGAffineTransform = .identity
    @State private var livePointPositions: [PointID: CGPoint] = [:]
    @State private var liveHandlePositions: [HandleID: CGPoint] = [:]
    @State private var colorDeltaColor: VectorColor? = nil
    @State private var colorDeltaOpacity: Double? = nil
    @State private var colorDeltaBlendMode: BlendMode? = nil
    @State private var strokeDeltaWidth: Double? = nil
    @State private var selectedLayerIndex: Int? = nil
    @State private var processedLayersDuringDrag: Set<Int> = []
    @State private var processedObjectsDuringDrag: Set<UUID> = []


    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VerticalToolbar(
                    currentTool: document.viewState.currentTool,
                    viewState: document.viewState,
                    document: document,
                    colorDeltaColor: $colorDeltaColor,
                    colorDeltaOpacity: $colorDeltaOpacity,
                    colorDeltaBlendMode: $colorDeltaBlendMode
                )
                .frame(width: 48)
                .contentShape(Rectangle())
                .background(Color.black.opacity(0.8))
                .zIndex(100)

                GeometryReader { geometry in
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)

                        DrawingCanvas(viewState: document.viewState, document: document, layerPreviewOpacities: $layerPreviewOpacities, liveDragOffset: $liveDragOffset, liveScaleDimensions: $liveScaleDimensions, liveScaleTransform: $liveScaleTransform, livePointPositions: $livePointPositions, liveHandlePositions: $liveHandlePositions)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .background(Color.clear)
                            .zIndex(1)
                            .allowsHitTesting(true)

                        RulersView(
                            document: document,
                            geometry: geometry
                        )
                        .zIndex(50)
                        .allowsHitTesting(true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minWidth: 400, minHeight: 300)
                }
                .frame(maxWidth: .infinity)
                .frame(minWidth: 500)
                .contentShape(Rectangle())
                .allowsHitTesting(true)

                RightPanel(
                    snapshot: document.snapshot,
                    viewState: document.viewState,
                    document: document,
                    layerPreviewOpacities: $layerPreviewOpacities,
                    colorDeltaColor: $colorDeltaColor,
                    colorDeltaOpacity: $colorDeltaOpacity,
                    colorDeltaBlendMode: $colorDeltaBlendMode,
                    strokeDeltaWidth: $strokeDeltaWidth,
                    selectedLayerIndex: $selectedLayerIndex,
                    processedLayersDuringDrag: $processedLayersDuringDrag,
                    processedObjectsDuringDrag: $processedObjectsDuringDrag
                )
                .frame(width: 280)
                .frame(minWidth: 280)
                .zIndex(100)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: 828, minHeight: 400)
            // TODO: Re-enable when properties are available
            // .onAppear {
            //     // Sync viewState colors from document defaults on appear
            //     document.viewState.activeFillColor = document.defaultFillColor
            //     document.viewState.activeStrokeColor = document.defaultStrokeColor
            //     document.viewState.activeFillOpacity = document.defaultFillOpacity
            //     document.viewState.activeStrokeOpacity = document.defaultStrokeOpacity
            //     document.viewState.activeStrokeWidth = document.defaultStrokeWidth
            // }
            // .onChange(of: document.viewState.activeFillColor) { _, newColor in
            //     document.defaultFillColor = newColor
            // }
            // .onChange(of: document.viewState.activeStrokeColor) { _, newColor in
            //     document.defaultStrokeColor = newColor
            // }
            // .onChange(of: document.viewState.activeFillOpacity) { _, newOpacity in
            //     document.defaultFillOpacity = newOpacity
            // }
            // .onChange(of: document.viewState.activeStrokeOpacity) { _, newOpacity in
            //     document.defaultStrokeOpacity = newOpacity
            // }
            // .onChange(of: document.viewState.activeStrokeWidth) { _, newWidth in
            //     document.defaultStrokeWidth = newWidth
            // }

            StatusBar(document: document)
        }
        .frame(minHeight: 524)
        .toolbarBackground(Color(NSColor.controlBackgroundColor), for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {

            MainToolbarContent(
                document: document,
                appState: appState,
                currentDocumentURL: $currentDocumentURL,
                showingDocumentSettings: $showingDocumentSettings,
                showingColorPicker: $showingColorPicker,
                showingImportDialog: $showingImportDialog,
                importResult: $importResult,
                showingImportProgress: $showingImportProgress,
                showingSVGTestHarness: $showingSVGTestHarness,
                showingPressureCalibration: $showingPressureCalibration,
                liveDragOffset: $liveDragOffset,
                liveScaleDimensions: $liveScaleDimensions,
                onRunDiagnostics: runPasteboardDiagnostics
            )
        }
        .sheet(isPresented: $showingDocumentSettings) {
            DocumentSettingsView(document: document)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerModal(
                snapshot: Binding(
                    get: { document.snapshot },
                    set: { document.snapshot = $0 }
                ),
                selectedObjectIDs: document.viewState.selectedObjectIDs,
                activeColorTarget: document.viewState.activeColorTarget,
                colorMode: Binding(
                    get: { document.settings.colorMode },
                    set: { document.settings.colorMode = $0 }
                ),
                defaultFillColor: Binding(
                    get: { document.defaultFillColor },
                    set: { document.defaultFillColor = $0 }
                ),
                defaultStrokeColor: Binding(
                    get: { document.defaultStrokeColor },
                    set: { document.defaultStrokeColor = $0 }
                ),
                defaultFillOpacity: document.defaultFillOpacity,
                defaultStrokeOpacity: document.defaultStrokeOpacity,
                currentSwatches: document.currentSwatches,
                onTriggerLayerUpdates: { indices in document.triggerLayerUpdates(for: indices) },
                onAddColorSwatch: { color in document.addColorSwatch(color) },
                onRemoveColorSwatch: { color in document.removeColorSwatch(color) },
                onSetActiveColor: { color in document.setActiveColor(color) },
                colorDeltaColor: $colorDeltaColor,
                colorDeltaOpacity: $colorDeltaOpacity,
                title: "Color Picker",
                onColorSelected: { color in
                    if document.viewState.activeColorTarget == .stroke {
                        document.defaultStrokeColor = color
                    } else {
                        document.defaultFillColor = color
                    }
                    document.addColorSwatch(color)
                }
            )
        }
        .onAppear {
            if let url = fileURL {
                ImageContentRegistry.setBaseDirectory(url.deletingLastPathComponent(), for: document)
                for object in document.snapshot.objects.values {
                    if case .shape(let shape) = object.objectType {
                        ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: document)
                    }
                }
            }
        }
        .onChange(of: fileURL) { oldURL, newURL in
            guard let url = newURL else { return }
            currentDocumentURL = url
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [
                .svg,
                .pdf,
                .png,
                .data
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importVectorFile(from: url)
            case .failure(let error):
                Log.error("❌ File import error: \(error)", category: .error)
            }
        }
        .sheet(item: $importResult) { result in
            ImportResultView(result: result, onDismiss: {
                importResult = nil
            }, onRetry: {
                importResult = nil
                showingImportDialog = true
            })
        }
        .sheet(isPresented: $showingPressureCalibration) {
            PressureCalibrationView()
                .frame(width: 1200, height: 800)
        }
        .background(WindowAccessor { window in
            if let window = window {
                documentState.window = window
            }
        })
        .onAppear {
            if !hasInitializedTool {
                document.viewState.currentTool = appState.defaultTool
                hasInitializedTool = true
            }

            documentState.setDocument(document)

            // Set as active document immediately on appear
            DrawingCanvasRegistry.shared.setActiveDocument(document)

            if let configured = appState.pendingNewDocument {
                loadImportedDocument(configured)
                appState.pendingNewDocument = nil
            }

            calculateInitialZoom()
        }
        .onDisappear {
            documentState.cleanup()
        }
        .focusedSceneObject(documentState)
    }

    private func calculateInitialZoom() {
        let documentBounds = document.documentBounds

        guard let window = NSApplication.shared.mainWindow else {
            document.requestZoom(to: 0.0, mode: .fitToPage)
            return
        }

        let windowSize = window.frame.size
        let rulerOffset: CGFloat = document.gridSettings.showRulers ? 20 : 0
        let availableWidth = windowSize.width - 48 - 280 - rulerOffset
        let availableHeight = windowSize.height - 24 - rulerOffset
        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let fitZoom = max(0.1, min(16.0, min(scaleX, scaleY)))

        document.viewState.zoomLevel = fitZoom

        let visibleCenter = CGPoint(
            x: (availableWidth + rulerOffset) / 2.0 + rulerOffset,
            y: (availableHeight + rulerOffset) / 2.0 + rulerOffset
        )
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        document.viewState.canvasOffset = CGPoint(
            x: visibleCenter.x - (documentCenter.x * fitZoom),
            y: visibleCenter.y - (documentCenter.y * fitZoom)
        )
    }

    private func loadImportedDocument(_ importedDoc: VectorDocument) {
        document.settings = importedDoc.settings
        document.snapshot.layers = importedDoc.snapshot.layers
        document.colorSwatches = importedDoc.colorSwatches
        document.documentColorDefaults = importedDoc.documentColorDefaults

        document.selectedLayerIndex = importedDoc.selectedLayerIndex
        document.viewState.selectedObjectIDs = importedDoc.viewState.selectedObjectIDs
        document.viewState.currentTool = appState.defaultTool
        document.viewState.viewMode = .color
        document.gridSettings = importedDoc.gridSettings

        calculateInitialZoom()
    }

    private func importVectorFile(from url: URL) {
        showingImportProgress = true

        Task {
            let result = await VectorImportManager.shared.importVectorFile(from: url)

            await MainActor.run {
                showingImportProgress = false

                if result.success {
                    guard let layerIndex = document.selectedLayerIndex else { return }
                    var newShapeIDs: Set<UUID> = []

                    for shape in result.shapes {
                        document.addShape(shape, to: layerIndex)
                        newShapeIDs.insert(shape.id)
                    }

                    document.viewState.selectedObjectIDs = newShapeIDs
                    calculateInitialZoom()
                } else {
                    Log.error("❌ Import failed: \(result.errors.map { $0.localizedDescription }.joined(separator: ", "))", category: .error)
                }

                importResult = result
            }
        }
    }

    private func runPasteboardDiagnostics() {
        let report = PasteboardDiagnostics.shared.runDiagnostics(on: document)
        report.printSummary()

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Pasteboard Diagnostics Complete"
            alert.informativeText = report.overallPassed ?
            "✅ All tests PASSED! Pasteboard is working correctly." :
            "❌ Some tests FAILED. Check the console for detailed results."
            alert.alertStyle = report.overallPassed ? .informational : .warning
            alert.runModal()
        }
    }
}
