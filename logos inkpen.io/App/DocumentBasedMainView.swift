import SwiftUI
import UniformTypeIdentifiers

struct DocumentBasedMainView: View {
    @ObservedObject var document: VectorDocument
    let fileURL: URL?
    @StateObject private var documentState = DocumentState()
    @Environment(AppState.self) private var appState
    @Binding var imagePreviewQuality: Double
    @Binding var imageTileSize: Int
    @Binding var imageInterpolationQuality: Int
    @State var showingDocumentSettings = false
    @State var showingColorPicker = false
    @State var currentDocumentURL: URL? = nil
    @State var showingImportDialog = false
    @State var importResult: VectorImportResult?
    @State var showingImportProgress = false
    @State var showingSVGTestHarness = false
    @State var showingPressureCalibration = false
    @State var hasInitializedTool = false
    @State var layerPreviewOpacities: [UUID: Double] = [:]
    @State var liveDragOffset: CGPoint = .zero
    @State var liveScaleDimensions: CGSize = .zero
    @State var liveScaleTransform: CGAffineTransform = .identity
    @State var livePointPositions: [PointID: CGPoint] = [:]
    @State var liveHandlePositions: [HandleID: CGPoint] = [:]
    @State var colorDeltaColor: VectorColor? = nil
    @State var colorDeltaOpacity: Double? = nil
    @State var colorDeltaBlendMode: BlendMode? = nil
    @State var fillDeltaOpacity: Double? = nil
    @State var strokeDeltaOpacity: Double? = nil
    @State var strokeDeltaWidth: Double? = nil
    @State var activeGradientDelta: VectorGradient? = nil
    @State var fontSizeDelta: Double? = nil
    @State var lineSpacingDelta: Double? = nil
    @State var lineHeightDelta: Double? = nil
    @State var letterSpacingDelta: Double? = nil
    @State var textContentDelta: (id: UUID, content: String)? = nil
    @State var selectedLayerIndex: Int? = nil
    @State var processedLayersDuringDrag: Set<Int> = []
    @State var processedObjectsDuringDrag: Set<UUID> = []
    @State var zoomLevel: Double = 1.0
    @State var canvasOffset: CGPoint = .zero
    @State var viewportSize: CGSize = .zero
    @State private var viewWindow: NSWindow? = nil


    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VerticalToolbar(
                    currentTool: document.viewState.currentTool,
                    viewState: document.viewState,
                    document: document,
                    colorDeltaColor: $colorDeltaColor,
                    colorDeltaOpacity: $colorDeltaOpacity,
                    colorDeltaBlendMode: $colorDeltaBlendMode,
                    defaultFillColor: Binding(
                        get: { document.defaultFillColor },
                        set: { document.defaultFillColor = $0 }
                    ),
                    defaultStrokeColor: Binding(
                        get: { document.defaultStrokeColor },
                        set: { document.defaultStrokeColor = $0 }
                    )
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

                        DrawingCanvas(document: document, zoomLevel: $zoomLevel, canvasOffset: $canvasOffset, layerPreviewOpacities: $layerPreviewOpacities, liveDragOffset: $liveDragOffset, liveScaleDimensions: $liveScaleDimensions, liveScaleTransform: $liveScaleTransform, livePointPositions: $livePointPositions, liveHandlePositions: $liveHandlePositions, fillDeltaOpacity: $fillDeltaOpacity, strokeDeltaOpacity: $strokeDeltaOpacity, strokeDeltaWidth: $strokeDeltaWidth, colorDeltaColor: $colorDeltaColor, colorDeltaOpacity: $colorDeltaOpacity, activeGradientDelta: $activeGradientDelta, fontSizeDelta: $fontSizeDelta, lineSpacingDelta: $lineSpacingDelta, lineHeightDelta: $lineHeightDelta, letterSpacingDelta: $letterSpacingDelta, textContentDelta: $textContentDelta, imagePreviewQuality: $imagePreviewQuality, imageTileSize: $imageTileSize, imageInterpolationQuality: $imageInterpolationQuality)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .background(Color.clear)
                            .zIndex(1)
                            //.allowsHitTesting(true)
                            .onChange(of: geometry.size) { _, newSize in
                                viewportSize = newSize
                            }
                            .onAppear {
                                viewportSize = geometry.size
                            }

                        RulersView(
                            document: document,
                            geometry: geometry,
                            zoomLevel: zoomLevel,
                            canvasOffset: canvasOffset
                        )
                        .zIndex(50)
                        //.allowsHitTesting(true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minWidth: 400, minHeight: 300)
                }
                .frame(maxWidth: .infinity)
                .frame(minWidth: 500)
                .contentShape(Rectangle())
               // .allowsHitTesting(true)

                RightPanel(
                    snapshot: document.snapshot,
                    viewState: document.viewState,
                    document: document,
                    layerPreviewOpacities: $layerPreviewOpacities,
                    colorDeltaColor: $colorDeltaColor,
                    colorDeltaOpacity: $colorDeltaOpacity,
                    colorDeltaBlendMode: $colorDeltaBlendMode,
                    fillDeltaOpacity: $fillDeltaOpacity,
                    strokeDeltaOpacity: $strokeDeltaOpacity,
                    strokeDeltaWidth: $strokeDeltaWidth,
                    activeGradientDelta: $activeGradientDelta,
                    fontSizeDelta: $fontSizeDelta,
                    lineSpacingDelta: $lineSpacingDelta,
                    lineHeightDelta: $lineHeightDelta,
                    letterSpacingDelta: $letterSpacingDelta,
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
            StatusBar(zoomLevel: zoomLevel, document: document)
        }
        .frame(minHeight: 524)
        .toolbarBackground(Color.platformControlBackground, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {

            MainToolbarContent(
                document: document,
                appState: appState,
                currentDocumentURL: $currentDocumentURL,
                showingDocumentSettings: $showingDocumentSettings,
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
        .sheet(isPresented: Binding(
            get: { documentState.showMoveDialog },
            set: { documentState.showMoveDialog = $0 }
        )) {
            MoveObjectDialog(document: document, isPresented: Binding(
                get: { documentState.showMoveDialog },
                set: { documentState.showMoveDialog = $0 }
            ))
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
        .onAppear {
            if !hasInitializedTool {
                document.viewState.currentTool = appState.defaultTool
                hasInitializedTool = true
            }

            documentState.setDocument(document)

            // Set as active document if this view's window is key
            DispatchQueue.main.async {
                if let window = self.viewWindow, window.isKeyWindow {
                    AppEventMonitor.shared.setActiveDocument(document)
                    print("🟢 onAppear: Set active document \(ObjectIdentifier(document))")
                }
            }

            if let configured = appState.pendingNewDocument {
                loadImportedDocument(configured)
                appState.pendingNewDocument = nil
            }
        }
        .background(HostingWindowFinder(callback: { window in
            self.viewWindow = window
        }))
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            // Update active document ONLY when THIS view's window becomes key
            guard let window = notification.object as? NSWindow,
                  let viewWindow = viewWindow,
                  window === viewWindow else { return }
            print("🪟 Window became key for document \(ObjectIdentifier(document))")
            AppEventMonitor.shared.setActiveDocument(document)
        }
        .onDisappear {
            documentState.cleanup()
        }
        .focusedSceneObject(documentState)
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

    private func calculateInitialZoom() {
        document.requestZoom(to: 0.0, mode: .fitToPage)
    }
}

// Helper to get the NSWindow for this view
struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            self.callback(view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
