//
//  MainView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

struct MainView: View {
    @StateObject private var document = TemplateManager.shared.createBlankDocument()
    @StateObject private var documentState = DocumentState()
    @Environment(AppState.self) private var appState
    @State private var showingDocumentSettings = false
    // @State private var showingExportDialog = false // REMOVED: Unused modal
    @State private var showingColorPicker = false
    @State private var currentDocumentURL: URL? = nil // Track current document location
    @State private var showingImportDialog = false
    @State private var importFileURL: URL?
    @State private var importResult: VectorImportResult?
    @State private var showingImportProgress = false
    @State private var showingSVGTestHarness = false // Add SVG test access
    @State private var showingNewDocumentSetup = false // New document setup window
    @State private var showingPressureCalibration = false // Pressure calibration window
    
    // Drawer state management
    @State private var isBottomDrawerOpen = false
    @State private var isLeftDrawerOpen = false
    
    // MARK: - Development Views State (moved to AppState)
    
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            // Main app layout
            VStack(spacing: 0) {
                // Main Content Area
                HStack(spacing: 0) {
                    // Left Toolbar - Fixed width, hugs left - ISOLATED HIT TESTING
                    VStack(spacing: 8) {
                        VerticalToolbar(document: document)
                        Spacer()
                    }
                    .frame(width: 48)
                    .contentShape(Rectangle()) // CRITICAL: Toolbar has its own hit testing bounds
                    .background(Color.ui.darkOverlay) // Visual confirmation of toolbar bounds
                    .zIndex(100) // CRITICAL: Toolbar above DrawingCanvas
                
                                // Center Drawing Area - Flexible width with minimum - STRICTLY CONSTRAINED TO CENTER COLUMN
                GeometryReader { geometry in
                    // Drawing canvas area - CLIPPED AND CONSTRAINED
                    ZStack {
                        // DEBUGGING: Background to see exact bounds
                        Rectangle()
                            .fill(Color.ui.lightGrayBackground)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false) // Background doesn't capture gestures
                        
                        // Main Drawing Canvas - FULL PASTEBOARD GESTURE COVERAGE
                        DrawingCanvas(document: document)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle()) // CRITICAL: Full gesture area including pasteboard
                            .background(Color.ui.clear) // Ensure no background extension
                            .zIndex(1) // CRITICAL: Canvas below panels but above background
                            .allowsHitTesting(true) // CRITICAL: Ensure gesture capture everywhere
                        
                        // Rulers - CRITICAL: Above canvas but below panels 
                        RulersView(document: document, geometry: geometry)
                            .zIndex(50) // CRITICAL: Rulers above canvas but below toolbar/panels
                            .allowsHitTesting(false) // CRITICAL: Rulers don't capture gestures
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minWidth: 400, minHeight: 300) // MINIMUM: Ensure drawing area is never crushed
                    // REMOVED: .clipped() to allow clipping masks to extend beyond canvas boundaries
                }
                .frame(maxWidth: .infinity)
                .frame(minWidth: 500) // MINIMUM: Ensure center area has enough space
                .contentShape(Rectangle()) // CRITICAL: Define exact hit testing bounds for center column
                .allowsHitTesting(true) // CRITICAL: Center column captures all gestures
                
                // Right Panel - Fixed width, hugs right
                RightPanel(document: document)
                    .frame(width: 280)
                    .frame(minWidth: 280) // ENSURE: Panel width is always preserved
                    .zIndex(100) // CRITICAL: Right panel above DrawingCanvas
            }
            .frame(maxWidth: .infinity)
            .frame(minWidth: 828, minHeight: 400) // MINIMUM: 48 + 500 + 280 = 828 minimum layout width
            .layoutPriority(1) // Give content area priority over status bar
            
            // Status Bar at bottom - MOVED OUTSIDE canvas area to prevent overlap
            StatusBar(document: document)
                .frame(height: 24)
                .frame(minHeight: 24) // ENSURE: Status bar height is always preserved
                .frame(maxWidth: .infinity) // ENSURE: Status bar spans full width
            }
        }
        .frame(minHeight: 524) // MINIMUM: Ensure overall height accommodates all elements + status bar (500 + 24)
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
                    // Replace current document with new one
                    document.settings = newDocument.settings
                    document.layers = newDocument.layers
                    document.customRgbSwatches = newDocument.customRgbSwatches
                    document.customCmykSwatches = newDocument.customCmykSwatches
                    document.customHsbSwatches = newDocument.customHsbSwatches
                    document.documentColorDefaults = newDocument.documentColorDefaults

                    // CRITICAL FIX: Copy color defaults (was missing - causing black default bug!)
                    document.defaultFillColor = newDocument.defaultFillColor
                    document.defaultStrokeColor = newDocument.defaultStrokeColor
                    document.defaultFillOpacity = newDocument.defaultFillOpacity
                    document.defaultStrokeOpacity = newDocument.defaultStrokeOpacity
                    document.defaultStrokeWidth = newDocument.defaultStrokeWidth

                    document.selectedLayerIndex = newDocument.selectedLayerIndex
                    document.selectedShapeIDs = newDocument.selectedShapeIDs
                    document.selectedTextIDs = newDocument.selectedTextIDs
                    // MIGRATION: Text is now stored as shapes in layers
                    document.currentTool = newDocument.currentTool
                    document.viewMode = newDocument.viewMode
                    document.zoomLevel = newDocument.zoomLevel
                    document.canvasOffset = newDocument.canvasOffset
                    document.showRulers = newDocument.showRulers
                    document.snapToGrid = newDocument.snapToGrid
                    
                    // Set the suggested URL as current document URL
                    currentDocumentURL = suggestedURL
                    
                    Log.info("✅ Created new document with custom settings", category: .general)
                    
                    // MICRO DELAY: Just enough for geometry to be established
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        document.requestZoom(to: 0.0, mode: .fitToPage)
                        Log.info("🔍 PROPER FIT TO PAGE: Applied for new document after geometry established", category: .zoom)
                    }
                }
            )
        }
        // Notification-based import request removed per policy
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerModal(
                document: document,
                title: "Color Picker",
                onColorSelected: { color in
                    // Apply to active target and add to swatches
                    if document.activeColorTarget == .stroke {
                        document.defaultStrokeColor = color
                    } else {
                        document.defaultFillColor = color
                    }
                    // ONLY add to swatches when explicitly using color picker
                    document.addColorSwatch(color)
                }
            )
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [
                .svg, // SVG files
                .pdf, // PDF files
                .png, // PNG images only
                .data // Generic data for unknown formats
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
        // Note: No longer using focusedValue - using focusedSceneObject instead
        .onAppear {
            // Apply the user's default tool setting to the document
            document.currentTool = appState.defaultTool
            Log.info("🛠️ Applied default tool \(appState.defaultTool.rawValue) to new document", category: .general)
            
            // SOLUTION: Connect document to menu system using NEW approach
            documentState.setDocument(document)
            
            // Defer fit to page operation to prevent blocking
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
    
    // MARK: - Async Initialization
    private func performInitialSetupAsync() async {
        // Wait a brief moment for geometry to be established
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        await MainActor.run {
            document.requestZoom(to: 0.0, mode: .fitToPage)
            Log.info("🔍 PROPER FIT TO PAGE: Applied after geometry established", category: .zoom)
        }
    }
    
    private func fitToPage() {
        // Fit the entire page to the view (professional standard)
        document.requestZoom(to: 0.0, mode: .fitToPage) // 0.0 signals to calculate fit zoom
        Log.info("🔍 FIT TO PAGE: Calculated optimal zoom to fit page in view", category: .zoom)
    }
    
    // MARK: - Document Save/Load Functionality
    private func saveDocument() {
        if let url = currentDocumentURL {
            // Save to existing location
            saveDocumentToURL(url)
        } else {
            // No existing location, show Save As dialog
            saveDocumentAs()
        }
    }
    
    private func saveDocumentAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.inkpen, UTType.svg, UTType.pdf]

        // Set initial filename with extension
        let baseName = currentDocumentURL?.deletingPathExtension().lastPathComponent ?? "Document"
        panel.nameFieldStringValue = "\(baseName).inkpen"
        panel.nameFieldLabel = "Save As:"

        panel.title = "Save Document"
        panel.isExtensionHidden = false  // Always show extensions
        panel.canSelectHiddenExtension = false  // Don't allow hiding extensions
        panel.allowsOtherFileTypes = false  // Only allow the specified types

        // Create accessory view to detect format changes
        let accessoryHandler = SavePanelAccessoryHandler(panel: panel, baseName: baseName)
        panel.accessoryView = accessoryHandler.createAccessoryView()

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            // Handle different file types
            let fileExtension = url.pathExtension.lowercased()
            switch fileExtension {
            case "svg":
                // Show SVG export options dialog similar to PDF
                self.showSVGExportWithBackgroundOption(saveAsURL: url)
            case "pdf":
                // FIXED: Use the same export code as Export PDF menu item with background toggle
                self.showPDFExportWithBackgroundOption(saveAsURL: url)
            default: // inkpen
                self.saveDocumentToURL(url)
            }
        }
    }
    
    private func saveDocumentToURL(_ url: URL) {
        do {
            try FileOperations.exportToJSON(document, url: url)
            Log.info("✅ Successfully saved document to: \(url.path)", category: .fileOperations)
            
        } catch {
            Log.error("❌ Save failed: \(error)", category: .error)
            
            // Show error notification
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
        // Reset view state BEFORE loading document to prevent two-step process
        document.zoomLevel = 1.0
        document.canvasOffset = .zero
        
        // Load the imported SVG document into the main Ink Pen interface
        document.settings = importedDoc.settings
        document.layers = importedDoc.layers
        document.customRgbSwatches = importedDoc.customRgbSwatches
        document.customCmykSwatches = importedDoc.customCmykSwatches
        document.customHsbSwatches = importedDoc.customHsbSwatches
        document.documentColorDefaults = importedDoc.documentColorDefaults
        
        document.selectedLayerIndex = importedDoc.selectedLayerIndex
        document.selectedShapeIDs = importedDoc.selectedShapeIDs
        document.selectedTextIDs = importedDoc.selectedTextIDs
        // MIGRATION: Text is now stored as shapes in layers, not in textObjects array
        // textObjects will be populated from layers during updateUnifiedObjectsOptimized()
        
        // CRITICAL FIX: Sync unified objects system to ensure imported images are properly registered
        document.updateUnifiedObjectsOptimized()
        
        // Reset tool and view states for the new document
        document.currentTool = appState.defaultTool
        document.viewMode = .color
        
        // Clear the current document URL (imported document needs to be saved)
        currentDocumentURL = nil
        
        Log.info("✅ Loaded imported SVG document into Ink Pen - \(document.layers.count) layers, \(document.unifiedObjects.count) objects", category: .fileOperations)
        
        // Defer fit to page operation to prevent blocking
        Task {
            await performMainViewImportedDocumentSetupAsync()
        }
    }
    
    private func performMainViewImportedDocumentSetupAsync() async {
        // Wait a brief moment for geometry to be established
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        await MainActor.run {
            document.requestZoom(to: 0.0, mode: .fitToPage)
            Log.info("🔍 PROPER FIT TO PAGE: Applied for imported document after geometry established", category: .zoom)
        }
    }
    
    private func performMainViewOpenDocumentSetupAsync() async {
        // Wait a brief moment for geometry to be established
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        await MainActor.run {
            document.requestZoom(to: 0.0, mode: .fitToPage)
            Log.info("🔍 PROPER FIT TO PAGE: Applied for opened document after geometry established", category: .zoom)
        }
    }
        
    // MARK: - Professional Vector Import
    private func importVectorFile(from url: URL) {
        showingImportProgress = true
        
        Task {
            let result = await VectorImportManager.shared.importVectorFile(from: url)
            
            await MainActor.run {
                showingImportProgress = false
                
                if result.success {
                    // CRITICAL FIX: Save to undo stack ONCE before importing all shapes
                    document.saveToUndoStack()
                    
                    // Add imported shapes to current layer using proper VectorDocument method
                    guard let layerIndex = document.selectedLayerIndex else { return }
                    var newShapeIDs: Set<UUID> = []
                    
                    for shape in result.shapes {
                        // CRITICAL FIX: Use VectorDocument.addShape to ensure unified system is updated
                        document.addShape(shape, to: layerIndex)
                        newShapeIDs.insert(shape.id)
                    }
                    
                    // Select all imported shapes and sync unified system
                    document.selectedShapeIDs = newShapeIDs
                    document.selectedObjectIDs = newShapeIDs
                    document.syncSelectionArrays()
                    
                    Log.info("✅ Import successful: \(result.shapes.count) shapes imported and added to undo stack", category: .fileOperations)
                    
                    // MICRO DELAY: Just enough for geometry to be established (like professional applications)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        document.requestZoom(to: 0.0, mode: .fitToPage)
                        Log.info("🔍 PROPER FIT TO PAGE: Applied after vector import with geometry established", category: .zoom)
                    }
                } else {
                    Log.error("❌ Import failed: \(result.errors.map { $0.localizedDescription }.joined(separator: ", "))", category: .error)
                }
                
                // Show import result dialog
                importResult = result
            }
        }
    }

    
    // MARK: - SVG Export Helper
    private func showSVGExportWithBackgroundOption(saveAsURL: URL) {
        // Show options dialog before saving (similar to Export SVG menu)
        let alert = NSAlert()
        alert.messageText = "SVG Export Options!"
        alert.informativeText = "Choose export options for the SVG file"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Export")
        alert.addButton(withTitle: "Cancel")

        // Create accessory view for background option
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))

        // Background checkbox
        let bgCheckbox = NSButton(checkboxWithTitle: "Include background",
                                   target: nil, action: nil)
        bgCheckbox.frame = NSRect(x: 20, y: 20, width: 250, height: 20)
        bgCheckbox.state = .off // Default to no background for Save As
        accessoryView.addSubview(bgCheckbox)

        alert.accessoryView = accessoryView

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        // Get export options
        let includeBackground = bgCheckbox.state == .on

        Task {
            do {
                // Export SVG with background option
                let svgContent = try SVGExporter.shared.exportToSVG(document,
                                                                     includeBackground: includeBackground,
                                                                     textRenderingMode: AppState.shared.svgTextRenderingMode,
                                                                     includeInkpenData: false)

                // Write to file
                try svgContent.write(to: saveAsURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                    Log.info("✅ Saved As SVG: \(saveAsURL.path) (background: \(includeBackground))", category: .fileOperations)
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

    // MARK: - PDF Export Helper
    private func showPDFExportWithBackgroundOption(saveAsURL: URL) {
        // Show options dialog before saving (same options as Export PDF menu)
        let alert = NSAlert()
        alert.messageText = "PDF Export Options"
        alert.informativeText = "Choose export options for the PDF file"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Export")
        alert.addButton(withTitle: "Cancel")

        // Create accessory view for text to outlines, text rendering mode, CMYK, and background options
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 220))

        // Convert text to outlines checkbox (at top)
        let textToOutlinesCheckbox = NSButton(checkboxWithTitle: "Convert text to outlines",
                                               target: nil, action: nil)
        textToOutlinesCheckbox.frame = NSRect(x: 20, y: 180, width: 250, height: 20)
        textToOutlinesCheckbox.state = .off // Default to keeping text as PDF text
        accessoryView.addSubview(textToOutlinesCheckbox)

        // Text rendering mode label and radio buttons (only shown when NOT converting to outlines)
        let textModeLabel = NSTextField(labelWithString: "PDF Text Rendering Mode:")
        textModeLabel.frame = NSRect(x: 40, y: 135, width: 300, height: 20)
        textModeLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        accessoryView.addSubview(textModeLabel)

        // Radio buttons for text rendering modes
        let glyphsRadio = NSButton(radioButtonWithTitle: "Individual Glyphs (most accurate)", target: nil, action: nil)
        glyphsRadio.frame = NSRect(x: 60, y: 110, width: 300, height: 18)
        glyphsRadio.state = AppState.shared.pdfTextRenderingMode == .glyphs ? .on : .off
        accessoryView.addSubview(glyphsRadio)

        let linesRadio = NSButton(radioButtonWithTitle: "By Lines (faster)", target: nil, action: nil)
        linesRadio.frame = NSRect(x: 60, y: 90, width: 300, height: 18)
        linesRadio.state = AppState.shared.pdfTextRenderingMode == .lines ? .on : .off
        accessoryView.addSubview(linesRadio)

        // CMYK checkbox
        let cmykCheckbox = NSButton(checkboxWithTitle: "Use CMYK color space",
                                     target: nil, action: nil)
        cmykCheckbox.frame = NSRect(x: 20, y: 50, width: 250, height: 20)
        cmykCheckbox.state = .off
        accessoryView.addSubview(cmykCheckbox)

        // Background checkbox
        let bgCheckbox = NSButton(checkboxWithTitle: "Include background",
                                   target: nil, action: nil)
        bgCheckbox.frame = NSRect(x: 20, y: 20, width: 250, height: 20)
        bgCheckbox.state = .off
        accessoryView.addSubview(bgCheckbox)

        // Use shared handler to eliminate duplication
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

        // Keep handler alive
        objc_setAssociatedObject(accessoryView, "textOptionsHandler", handler, .OBJC_ASSOCIATION_RETAIN)

        alert.accessoryView = accessoryView

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        // Get export options
        let useCMYK = cmykCheckbox.state == .on
        let convertTextToOutlines = textToOutlinesCheckbox.state == .on
        let includeBackground = bgCheckbox.state == .on

        // Determine text rendering mode (default to glyphs if neither is selected)
        let textRenderingMode: AppState.PDFTextRenderingMode = linesRadio.state == .on ? .lines : .glyphs

        // Save preference for next time
        AppState.shared.pdfTextRenderingMode = textRenderingMode

        Task {
            do {
                var pdfData: Data

                // If converting text to outlines, create a temporary copy and convert
                if convertTextToOutlines && document.unifiedObjects.contains(where: { obj in
                    if case .shape(let shape) = obj.objectType { return shape.isTextObject }
                    return false
                }) {
                    // Save current document state
                    let savedData = try JSONEncoder().encode(document)
                    let savedState = try JSONDecoder().decode(VectorDocument.self, from: savedData)

                    // Convert all text to outlines
                    await MainActor.run {
                        Log.info("📝 Converting all text to outlines for Save As PDF...", category: .fileOperations)
                        DocumentState.convertAllTextToOutlinesForExport(document)
                    }

                    // Generate PDF with outlined text
                    pdfData = try FileOperations.generatePDFDataForExport(from: document, useCMYK: useCMYK, textRenderingMode: textRenderingMode, includeInkpenData: false, includeBackground: includeBackground)

                    // Restore original document state
                    await MainActor.run {
                        Log.info("↩️ Restoring original document state after Save As PDF", category: .fileOperations)
                        document.unifiedObjects = savedState.unifiedObjects
                        document.layers = savedState.layers
                        document.selectedObjectIDs = savedState.selectedObjectIDs
                        document.selectedTextIDs = savedState.selectedTextIDs
                        document.selectedShapeIDs = savedState.selectedShapeIDs
                        document.objectWillChange.send()
                    }
                } else {
                    // No text conversion needed, export normally
                    pdfData = try FileOperations.generatePDFDataForExport(from: document, useCMYK: useCMYK, textRenderingMode: textRenderingMode, includeInkpenData: false, includeBackground: includeBackground)
                }

                // Write to file
                try pdfData.write(to: saveAsURL)

                await MainActor.run {
                    Log.info("✅ Saved As PDF: \(saveAsURL.path) (text to outlines: \(convertTextToOutlines), mode: \(textRenderingMode.displayName))", category: .fileOperations)
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

    // MARK: - Debug Functions
    private func runPasteboardDiagnostics() {
        Log.info("🚀 STARTING PASTEBOARD DIAGNOSTICS FROM UI", category: .general)
        let report = PasteboardDiagnostics.shared.runDiagnostics(on: document)
        report.printSummary()
        
        // Show results in an alert
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


// MARK: - Save Panel Accessory Handler
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
        // Create an empty accessory view (the system adds the format popup automatically)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))

        // Start observing format changes after a brief delay to let the system set up the popup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startObservingFormatChanges()
        }

        return view
    }

    private func startObservingFormatChanges() {
        // Create a timer to periodically check the URL and update the filename
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, let panel = self.panel else {
                timer.invalidate()
                return
            }

            // When panel is dismissed, stop the timer
            if !panel.isVisible {
                timer.invalidate()
                return
            }

            // Get current filename and extension
            let currentName = panel.nameFieldStringValue
            let nameWithoutExt = (currentName as NSString).deletingPathExtension
            let currentExt = (currentName as NSString).pathExtension

            // Try to determine the selected format
            // The panel automatically updates the URL with the selected type's extension
            if let url = panel.url {
                let expectedExt = url.pathExtension.lowercased()

                // If the extension in the filename doesn't match the selected format, update it
                if expectedExt != currentExt.lowercased() && ["inkpen", "svg", "pdf"].contains(expectedExt) {
                    let newName = "\(nameWithoutExt.isEmpty ? self.baseName : nameWithoutExt).\(expectedExt)"
                    panel.nameFieldStringValue = newName
                }
            }
        }
    }

    deinit {
        // Cleanup if needed
    }
}

// Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
