import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

struct MainView: View {
    @StateObject private var document = TemplateManager.shared.createBlankDocument()
    @StateObject private var documentState = DocumentState()
    @Environment(AppState.self) private var appState
    @State private var showingDocumentSettings = false
    @State private var showingColorPicker = false
    @State private var currentDocumentURL: URL? = nil
    @State private var showingImportDialog = false
    @State private var importFileURL: URL?
    @State private var importResult: VectorImportResult?
    @State private var showingImportProgress = false
    @State private var showingSVGTestHarness = false
    @State private var showingNewDocumentSetup = false
    @State private var showingPressureCalibration = false
    @State private var isBottomDrawerOpen = false
    @State private var isLeftDrawerOpen = false
    @State private var layerPreviewOpacities: [UUID: Double] = [:]
    @State private var liveDragOffset: CGPoint = .zero
    @State private var liveScaleDimensions: CGSize = .zero
    @State private var liveScaleTransform: CGAffineTransform = .identity
    @State private var livePointPositions: [PointID: CGPoint] = [:]
    @State private var liveHandlePositions: [HandleID: CGPoint] = [:]
    @State private var colorDeltaColor: VectorColor?
    @State private var colorDeltaOpacity: Double?
    @State private var colorDeltaBlendMode: BlendMode?
    @State private var fillDeltaOpacity: Double?
    @State private var strokeDeltaOpacity: Double?
    @State private var strokeDeltaWidth: Double?
    @State private var activeGradientDelta: VectorGradient?
    @State private var fontSizeDelta: Double?
    @State private var lineSpacingDelta: Double?
    @State private var lineHeightDelta: Double?
    @State private var letterSpacingDelta: Double?
    @State private var imagePreviewQuality: Double = UserDefaults.standard.object(forKey: "imagePreviewQuality") as? Double ?? 1.0
    @State private var imageTileSize: Int = UserDefaults.standard.object(forKey: "imageTileSize") as? Int ?? 512
    @State private var selectedLayerIndex: Int?
    @State private var processedLayersDuringDrag: Set<Int> = []
    @State private var processedObjectsDuringDrag: Set<UUID> = []
    @State private var zoomLevel: Double = 1.0
    @State private var canvasOffset: CGPoint = .zero
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack(spacing: 8) {
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
                        Spacer()
                    }
                    .frame(width: 48)
                    .contentShape(Rectangle())
                    .background(Color.ui.darkOverlay)
                    .zIndex(100)

                GeometryReader { geometry in
                    ZStack {
                        Rectangle()
                            .fill(Color.ui.lightGrayBackground)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)

                        DrawingCanvas(viewState: document.viewState, document: document, zoomLevel: $zoomLevel, canvasOffset: $canvasOffset, layerPreviewOpacities: $layerPreviewOpacities, liveDragOffset: $liveDragOffset, liveScaleDimensions: $liveScaleDimensions, liveScaleTransform: $liveScaleTransform, livePointPositions: $livePointPositions, liveHandlePositions: $liveHandlePositions, fillDeltaOpacity: $fillDeltaOpacity, strokeDeltaOpacity: $strokeDeltaOpacity, strokeDeltaWidth: $strokeDeltaWidth, activeGradientDelta: $activeGradientDelta, fontSizeDelta: $fontSizeDelta, lineSpacingDelta: $lineSpacingDelta, lineHeightDelta: $lineHeightDelta, letterSpacingDelta: $letterSpacingDelta, imagePreviewQuality: $imagePreviewQuality, imageTileSize: $imageTileSize)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .background(Color.ui.clear)
                            .zIndex(1)
                            .allowsHitTesting(true)

                        RulersView(document: document, geometry: geometry, zoomLevel: zoomLevel, canvasOffset: canvasOffset)
                            .zIndex(50)
                            .allowsHitTesting(false)
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
            .frame(maxWidth: .infinity)
            .frame(minWidth: 828, minHeight: 400)
            .layoutPriority(1)

            StatusBar(zoomLevel: zoomLevel, document: document)
                .frame(height: 24)
                .frame(minHeight: 24)
                .frame(maxWidth: .infinity)
            }
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
        .sheet(isPresented: $showingNewDocumentSetup) {
            NewDocumentSetupView(
                isPresented: $showingNewDocumentSetup,
                onDocumentCreated: { newDocument, suggestedURL in
                    document.settings = newDocument.settings
                    document.snapshot.layers = newDocument.snapshot.layers
                    document.colorSwatches = newDocument.colorSwatches
                    document.documentColorDefaults = newDocument.documentColorDefaults

                    document.defaultFillColor = newDocument.defaultFillColor
                    document.defaultStrokeColor = newDocument.defaultStrokeColor
                    document.defaultFillOpacity = newDocument.defaultFillOpacity
                    document.defaultStrokeOpacity = newDocument.defaultStrokeOpacity
                    document.defaultStrokeWidth = newDocument.defaultStrokeWidth

                    document.selectedLayerIndex = newDocument.selectedLayerIndex
                    document.viewState.selectedObjectIDs = newDocument.viewState.selectedObjectIDs
                    document.viewState.currentTool = newDocument.viewState.currentTool
                    document.viewState.viewMode = newDocument.viewState.viewMode
                    // zoomLevel and canvasOffset managed by @State, not from loaded document
                    document.gridSettings = newDocument.gridSettings

                    currentDocumentURL = suggestedURL

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        document.requestZoom(to: 0.0, mode: .fitToPage)
                    }
                }
            )
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
                onSetActiveColor: { color in
                    if document.viewState.activeColorTarget == .stroke {
                        document.defaultStrokeColor = color
                    } else {
                        document.defaultFillColor = color
                    }
                    document.setActiveColor(color)
                },
                colorDeltaColor: $colorDeltaColor,
                colorDeltaOpacity: $colorDeltaOpacity,
                title: "Color Picker",
                onColorSelected: { color in
                    if document.viewState.activeColorTarget == .stroke {
                        document.defaultStrokeColor = color
                    } else {
                        document.defaultFillColor = color
                    }
                }
            )
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
        .frame(minWidth: 1400, minHeight: 900)
        .onAppear {
            document.viewState.currentTool = appState.defaultTool

            documentState.setDocument(document)

            Task {
                await performInitialSetupAsync()
            }
        }
        .focusedSceneObject(documentState)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                documentState.setDocument(document)
            }
        }
    }

    private func performInitialSetupAsync() async {
        try? await Task.sleep(nanoseconds: 10_000_000)

        await MainActor.run {
            document.requestZoom(to: 0.0, mode: .fitToPage)
        }
    }

    private func fitToPage() {
        document.requestZoom(to: 0.0, mode: .fitToPage)
    }

    private func saveDocument() {
        if let url = currentDocumentURL {
            saveDocumentToURL(url)
        } else {
            saveDocumentAs()
        }
    }

    private func saveDocumentAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.inkpen, UTType.svg, UTType.pdf]

        let baseName = currentDocumentURL?.deletingPathExtension().lastPathComponent ?? "Document"
        panel.nameFieldStringValue = "\(baseName).inkpen"
        panel.nameFieldLabel = "Save As:"

        panel.title = "Save Document"
        panel.isExtensionHidden = false
        panel.canSelectHiddenExtension = false
        panel.allowsOtherFileTypes = false

        let accessoryHandler = SavePanelAccessoryHandler(panel: panel, baseName: baseName)
        panel.accessoryView = accessoryHandler.createAccessoryView()

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            let fileExtension = url.pathExtension.lowercased()
            switch fileExtension {
            case "svg":
                self.showSVGExportWithBackgroundOption(saveAsURL: url)
            case "pdf":
                self.showPDFExportWithBackgroundOption(saveAsURL: url)
            default:
                self.saveDocumentToURL(url)
            }
        }
    }

    private func saveDocumentToURL(_ url: URL) {
        do {
            try FileOperations.exportToJSON(document, url: url)

        } catch {
            Log.error("❌ Save failed: \(error)", category: .error)

            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Save Failed"
                alert.informativeText = "Error: \(error.localizedDescription)"
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }

    private func loadImportedDocument(_ importedDoc: VectorDocument) {
        zoomLevel = 1.0
        canvasOffset = .zero
        document.settings = importedDoc.settings
        document.snapshot.layers = importedDoc.snapshot.layers
        document.colorSwatches = importedDoc.colorSwatches
        document.documentColorDefaults = importedDoc.documentColorDefaults
        document.selectedLayerIndex = importedDoc.selectedLayerIndex
        document.viewState.selectedObjectIDs = importedDoc.viewState.selectedObjectIDs
        document.viewState.currentTool = appState.defaultTool
        document.viewState.viewMode = .color

        currentDocumentURL = nil

        Task {
            await performMainViewImportedDocumentSetupAsync()
        }
    }

    private func performMainViewImportedDocumentSetupAsync() async {
        try? await Task.sleep(nanoseconds: 10_000_000)

        await MainActor.run {
            document.requestZoom(to: 0.0, mode: .fitToPage)
        }
    }

    private func performMainViewOpenDocumentSetupAsync() async {
        try? await Task.sleep(nanoseconds: 10_000_000)

        await MainActor.run {
            document.requestZoom(to: 0.0, mode: .fitToPage)
        }
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

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        document.requestZoom(to: 0.0, mode: .fitToPage)
                    }
                } else {
                    Log.error("❌ Import failed: \(result.errors.map { $0.localizedDescription }.joined(separator: ", "))", category: .error)
                }

                importResult = result
            }
        }
    }

    private func showSVGExportWithBackgroundOption(saveAsURL: URL) {
        let alert = NSAlert()
        alert.messageText = "SVG Export Options!"
        alert.informativeText = "Choose export options for the SVG file"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Export")
        alert.addButton(withTitle: "Cancel")

        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        let bgCheckbox = NSButton(checkboxWithTitle: "Include background",
                                   target: nil, action: nil)
        bgCheckbox.frame = NSRect(x: 20, y: 20, width: 250, height: 20)
        bgCheckbox.state = .off
        accessoryView.addSubview(bgCheckbox)

        alert.accessoryView = accessoryView

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let includeBackground = bgCheckbox.state == .on

        Task {
            do {
                let svgContent = try SVGExporter.shared.exportToSVG(document,
                                                                     includeBackground: includeBackground,
                                                                     textRenderingMode: AppState.shared.svgTextRenderingMode,
                                                                     includeInkpenData: false)

                try svgContent.write(to: saveAsURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                }
            } catch {
                await MainActor.run {
                    Log.error("❌ Save As SVG failed: \(error)", category: .error)

                    let alert = NSAlert()
                    alert.messageText = "SVG Export Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }

    private func showPDFExportWithBackgroundOption(saveAsURL: URL) {
        let alert = NSAlert()
        alert.messageText = "PDF Export Options"
        alert.informativeText = "Choose export options for the PDF file"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Export")
        alert.addButton(withTitle: "Cancel")

        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 220))
        let textToOutlinesCheckbox = NSButton(checkboxWithTitle: "Convert text to outlines",
                                               target: nil, action: nil)
        textToOutlinesCheckbox.frame = NSRect(x: 20, y: 180, width: 250, height: 20)
        textToOutlinesCheckbox.state = .off
        accessoryView.addSubview(textToOutlinesCheckbox)

        let textModeLabel = NSTextField(labelWithString: "PDF Text Rendering Mode:")
        textModeLabel.frame = NSRect(x: 40, y: 135, width: 300, height: 20)
        textModeLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        accessoryView.addSubview(textModeLabel)

        let glyphsRadio = NSButton(radioButtonWithTitle: "Individual Glyphs (most accurate)", target: nil, action: nil)
        glyphsRadio.frame = NSRect(x: 60, y: 110, width: 300, height: 18)
        glyphsRadio.state = AppState.shared.pdfTextRenderingMode == .glyphs ? .on : .off
        accessoryView.addSubview(glyphsRadio)

        let linesRadio = NSButton(radioButtonWithTitle: "By Lines (faster)", target: nil, action: nil)
        linesRadio.frame = NSRect(x: 60, y: 90, width: 300, height: 18)
        linesRadio.state = AppState.shared.pdfTextRenderingMode == .lines ? .on : .off
        accessoryView.addSubview(linesRadio)

        let cmykCheckbox = NSButton(checkboxWithTitle: "Use CMYK color space",
                                     target: nil, action: nil)
        cmykCheckbox.frame = NSRect(x: 20, y: 50, width: 250, height: 20)
        cmykCheckbox.state = .off
        accessoryView.addSubview(cmykCheckbox)

        let bgCheckbox = NSButton(checkboxWithTitle: "Include background",
                                   target: nil, action: nil)
        bgCheckbox.frame = NSRect(x: 20, y: 20, width: 250, height: 20)
        bgCheckbox.state = .off
        accessoryView.addSubview(bgCheckbox)

        let handler = ExportTextOptionsHandler(textToOutlinesCheckbox: textToOutlinesCheckbox,
                                         textModeLabel: textModeLabel,
                                         glyphsRadio: glyphsRadio,
                                         linesRadio: linesRadio)

        textToOutlinesCheckbox.target = handler
        textToOutlinesCheckbox.action = #selector(ExportTextOptionsHandler.toggleTextOptions(_:))
        glyphsRadio.target = handler
        glyphsRadio.action = #selector(ExportTextOptionsHandler.selectGlyphs(_:))
        linesRadio.target = handler
        linesRadio.action = #selector(ExportTextOptionsHandler.selectLines(_:))

        objc_setAssociatedObject(accessoryView, "textOptionsHandler", handler, .OBJC_ASSOCIATION_RETAIN)

        alert.accessoryView = accessoryView

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let useCMYK = cmykCheckbox.state == .on
        let convertTextToOutlines = textToOutlinesCheckbox.state == .on
        let includeBackground = bgCheckbox.state == .on
        let textRenderingMode: AppState.PDFTextRenderingMode = linesRadio.state == .on ? .lines : .glyphs

        AppState.shared.pdfTextRenderingMode = textRenderingMode

        Task {
            do {
                var pdfData: Data

                if convertTextToOutlines && document.snapshot.objects.values.contains(where: { obj in
                    if case .text = obj.objectType { return true }
                    return false
                }) {
                    let savedData = try JSONEncoder().encode(document)
                    let savedState = try JSONDecoder().decode(VectorDocument.self, from: savedData)

                    await MainActor.run {
                        DocumentState.convertAllTextToOutlinesForExport(document)
                    }

                    pdfData = try FileOperations.generatePDFDataForExport(from: document, useCMYK: useCMYK, textRenderingMode: textRenderingMode, includeInkpenData: true, includeBackground: includeBackground)

                    await MainActor.run {
                        document.snapshot.objects = savedState.snapshot.objects
                        document.snapshot.layers = savedState.snapshot.layers
                        document.viewState.selectedObjectIDs = savedState.viewState.selectedObjectIDs
                    }
                } else {
                    pdfData = try FileOperations.generatePDFDataForExport(from: document, useCMYK: useCMYK, textRenderingMode: textRenderingMode, includeInkpenData: true, includeBackground: includeBackground)
                }

                try pdfData.write(to: saveAsURL)

                await MainActor.run {
                }
            } catch {
                await MainActor.run {
                    Log.error("❌ Save As PDF failed: \(error)", category: .error)

                    let alert = NSAlert()
                    alert.messageText = "PDF Export Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
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

private class SavePanelAccessoryHandler: NSObject {
    weak var panel: NSSavePanel?
    let baseName: String
    private var formatObserver: Any?

    init(panel: NSSavePanel, baseName: String) {
        self.panel = panel
        self.baseName = baseName
        super.init()
    }

    func createAccessoryView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startObservingFormatChanges()
        }

        return view
    }

    private func startObservingFormatChanges() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, let panel = self.panel else {
                timer.invalidate()
                return
            }

            if !panel.isVisible {
                timer.invalidate()
                return
            }

            let currentName = panel.nameFieldStringValue
            let nameWithoutExt = (currentName as NSString).deletingPathExtension
            let currentExt = (currentName as NSString).pathExtension

            if let url = panel.url {
                let expectedExt = url.pathExtension.lowercased()

                if expectedExt != currentExt.lowercased() && ["inkpen", "svg", "pdf"].contains(expectedExt) {
                    let newName = "\(nameWithoutExt.isEmpty ? self.baseName : nameWithoutExt).\(expectedExt)"
                    panel.nameFieldStringValue = newName
                }
            }
        }
    }

    deinit {
    }
}
