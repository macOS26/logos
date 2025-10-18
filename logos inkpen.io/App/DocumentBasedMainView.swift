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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VerticalToolbar(document: document)
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

                        DrawingCanvas(document: document, layerPreviewOpacities: $layerPreviewOpacities, liveDragOffset: $liveDragOffset, liveScaleDimensions: $liveScaleDimensions, liveScaleTransform: $liveScaleTransform)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .background(Color.clear)
                            .zIndex(1)
                            .allowsHitTesting(true)

                        RulersView(document: document, geometry: geometry)
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

                RightPanel(document: document, layerPreviewOpacities: $layerPreviewOpacities)
                    .frame(width: 280)
                    .frame(minWidth: 280)
                    .zIndex(100)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: 828, minHeight: 400)

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
                document: document,
                title: "Color Picker",
                onColorSelected: { color in
                    if document.activeColorTarget == .stroke {
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
                ImageContentRegistry.setBaseDirectory(url.deletingLastPathComponent())
                for unifiedObject in document.unifiedObjects {
                    if case .shape(let shape) = unifiedObject.objectType {
                        ImageContentRegistry.hydrateImageIfAvailable(for: shape)
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
                document.currentTool = appState.defaultTool
                hasInitializedTool = true
            }

            documentState.setDocument(document)

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
        let rulerOffset: CGFloat = document.showRulers ? 20 : 0
        let availableWidth = windowSize.width - 48 - 280 - rulerOffset
        let availableHeight = windowSize.height - 24 - rulerOffset
        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let fitZoom = max(0.1, min(16.0, min(scaleX, scaleY)))

        document.zoomLevel = fitZoom

        let visibleCenter = CGPoint(
            x: (availableWidth + rulerOffset) / 2.0 + rulerOffset,
            y: (availableHeight + rulerOffset) / 2.0 + rulerOffset
        )
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        document.canvasOffset = CGPoint(
            x: visibleCenter.x - (documentCenter.x * fitZoom),
            y: visibleCenter.y - (documentCenter.y * fitZoom)
        )
    }

    private func loadImportedDocument(_ importedDoc: VectorDocument) {
        document.settings = importedDoc.settings
        document.layers = importedDoc.layers
        document.customRgbSwatches = importedDoc.customRgbSwatches
        document.customCmykSwatches = importedDoc.customCmykSwatches
        document.customHsbSwatches = importedDoc.customHsbSwatches
        document.documentColorDefaults = importedDoc.documentColorDefaults

        document.selectedLayerIndex = importedDoc.selectedLayerIndex
        document.selectedShapeIDs = importedDoc.selectedShapeIDs
        document.selectedTextIDs = importedDoc.selectedTextIDs
        document.currentTool = appState.defaultTool
        document.viewMode = .color
        document.showRulers = importedDoc.showRulers
        document.snapToGrid = importedDoc.snapToGrid

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

                    document.selectedShapeIDs = newShapeIDs
                    document.selectedObjectIDs = newShapeIDs
                    document.syncSelectionArrays()

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
