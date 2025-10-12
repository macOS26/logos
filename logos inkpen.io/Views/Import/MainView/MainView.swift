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


    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack(spacing: 8) {
                        VerticalToolbar(document: document)
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

                        DrawingCanvas(document: document)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .background(Color.ui.clear)
                            .zIndex(1)
                            .allowsHitTesting(true)

                        RulersView(document: document, geometry: geometry)
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

                RightPanel(document: document)
                    .frame(width: 280)
                    .frame(minWidth: 280)
                    .zIndex(100)
            }
            .frame(maxWidth: .infinity)
            .frame(minWidth: 828, minHeight: 400)
            .layoutPriority(1)

            StatusBar(document: document)
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
                    document.layers = newDocument.layers
                    document.customRgbSwatches = newDocument.customRgbSwatches
                    document.customCmykSwatches = newDocument.customCmykSwatches
                    document.customHsbSwatches = newDocument.customHsbSwatches
                    document.documentColorDefaults = newDocument.documentColorDefaults

                    document.defaultFillColor = newDocument.defaultFillColor
                    document.defaultStrokeColor = newDocument.defaultStrokeColor
                    document.defaultFillOpacity = newDocument.defaultFillOpacity
                    document.defaultStrokeOpacity = newDocument.defaultStrokeOpacity
                    document.defaultStrokeWidth = newDocument.defaultStrokeWidth

                    document.selectedLayerIndex = newDocument.selectedLayerIndex
                    document.selectedShapeIDs = newDocument.selectedShapeIDs
                    document.selectedTextIDs = newDocument.selectedTextIDs
                    document.currentTool = newDocument.currentTool
                    document.viewMode = newDocument.viewMode
                    document.zoomLevel = newDocument.zoomLevel
                    document.canvasOffset = newDocument.canvasOffset
                    document.showRulers = newDocument.showRulers
                    document.snapToGrid = newDocument.snapToGrid

                    currentDocumentURL = suggestedURL


                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        document.requestZoom(to: 0.0, mode: .fitToPage)
                    }
                }
            )
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
            document.currentTool = appState.defaultTool

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
        document.zoomLevel = 1.0
        document.canvasOffset = .zero

        document.settings = importedDoc.settings
        document.layers = importedDoc.layers
        document.customRgbSwatches = importedDoc.customRgbSwatches
        document.customCmykSwatches = importedDoc.customCmykSwatches
        document.customHsbSwatches = importedDoc.customHsbSwatches
        document.documentColorDefaults = importedDoc.documentColorDefaults

        document.selectedLayerIndex = importedDoc.selectedLayerIndex
        document.selectedShapeIDs = importedDoc.selectedShapeIDs
        document.selectedTextIDs = importedDoc.selectedTextIDs

        document.updateUnifiedObjectsOptimized()

        document.currentTool = appState.defaultTool
        document.viewMode = .color

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
                    document.saveToUndoStack()

                    guard let layerIndex = document.selectedLayerIndex else { return }
                    var newShapeIDs: Set<UUID> = []

                    for shape in result.shapes {
                        document.addShape(shape, to: layerIndex)
                        newShapeIDs.insert(shape.id)
                    }

                    document.selectedShapeIDs = newShapeIDs
                    document.selectedObjectIDs = newShapeIDs
                    document.syncSelectionArrays()


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

                if convertTextToOutlines && document.unifiedObjects.contains(where: { obj in
                    if case .shape(let shape) = obj.objectType { return shape.isTextObject }
                    return false
                }) {
                    let savedData = try JSONEncoder().encode(document)
                    let savedState = try JSONDecoder().decode(VectorDocument.self, from: savedData)

                    await MainActor.run {
                        DocumentState.convertAllTextToOutlinesForExport(document)
                    }

                    pdfData = try FileOperations.generatePDFDataForExport(from: document, useCMYK: useCMYK, textRenderingMode: textRenderingMode, includeInkpenData: true, includeBackground: includeBackground)

                    await MainActor.run {
                        document.unifiedObjects = savedState.unifiedObjects
                        document.layers = savedState.layers
                        document.selectedObjectIDs = savedState.selectedObjectIDs
                        document.selectedTextIDs = savedState.selectedTextIDs
                        document.selectedShapeIDs = savedState.selectedShapeIDs
                        document.objectWillChange.send()
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

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
