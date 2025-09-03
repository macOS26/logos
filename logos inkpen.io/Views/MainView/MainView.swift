//
//  MainView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject private var document = TemplateManager.shared.createBlankDocument()
    @StateObject private var documentState = DocumentState()
    @Environment(AppState.self) private var appState
    @State private var showingDocumentSettings = false
    @State private var showingExportDialog = false
    @State private var showingColorPicker = false
    @State private var currentDocumentURL: URL? = nil // Track current document location
    @State private var showingImportDialog = false
    @State private var importFileURL: URL?
    @State private var importResult: VectorImportResult?
    @State private var showingImportProgress = false
    @State private var showingDWFExportDialog = false
    @State private var dwfExportOptions = DWFExportOptions()
    @State private var showingDWGExportDialog = false
    @State private var dwgExportOptions = DWGExportOptions()
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
        .toolbar {
            MainToolbarContent(
            document: document,
            appState: appState,
            currentDocumentURL: $currentDocumentURL,
            showingDocumentSettings: $showingDocumentSettings,
            showingExportDialog: $showingExportDialog,
            showingColorPicker: $showingColorPicker,
            onSave: saveDocument,
            onSaveAs: saveDocumentAs,
            onOpen: openDocument,
            onNew: newDocument,
            showingImportDialog: $showingImportDialog,
            importResult: $importResult,
            showingImportProgress: $showingImportProgress,
            showingDWFExportDialog: $showingDWFExportDialog,
            showingDWGExportDialog: $showingDWGExportDialog,
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
                    document.rgbSwatches = newDocument.rgbSwatches
                    document.cmykSwatches = newDocument.cmykSwatches
                    document.hsbSwatches = newDocument.hsbSwatches
                    
                    document.selectedLayerIndex = newDocument.selectedLayerIndex
                    document.selectedShapeIDs = newDocument.selectedShapeIDs
                    document.selectedTextIDs = newDocument.selectedTextIDs
                    document.textObjects = newDocument.textObjects
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
        .sheet(isPresented: $showingExportDialog) {
            ExportView(document: document)
        }
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
                .svg,                                    // SVG files
                .pdf,                                    // PDF files
                UTType("com.adobe.illustrator.ai-image")!, // AI files
                UTType("com.adobe.encapsulated-postscript")!, // EPS files
                UTType("com.adobe.postscript")!,         // PostScript files
                UTType(filenameExtension: "ps")!,        // PostScript files (.ps)
                UTType(filenameExtension: "ai")!,        // AI files (.ai)
                UTType(filenameExtension: "eps")!,       // EPS files (.eps)
                UTType(filenameExtension: "dwf")!,       // DWF files (.dwf)
                .png, .jpeg, .tiff, .gif, .bmp, UTType("public.heic")!, // Raster images
                .data                                    // Generic data for unknown formats
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
        .sheet(isPresented: $showingDWFExportDialog) {
            DWFExportView(document: document, options: $dwfExportOptions) { finalOptions in
                showingDWFExportDialog = false
                exportToDWF(with: finalOptions)
            }
        }
        .sheet(isPresented: $showingDWGExportDialog) {
            DWGExportView(document: document, options: $dwgExportOptions) { finalOptions in
                showingDWGExportDialog = false
                exportToDWG(with: finalOptions)
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.showingCoreGraphicsTest },
            set: { appState.showingCoreGraphicsTest = $0 }
        )) {
            CoreGraphicsPathTestView()
                .frame(width: 1000, height: 700)
        }
        .sheet(isPresented: $showingSVGTestHarness) {
            SVGTestHarness { importedDoc in
                // Load the imported document into the main app
                loadImportedDocument(importedDoc)
            }
            .frame(width: 1000, height: 800)
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
        panel.allowedContentTypes = [UTType.json, UTType.inkpen, UTType(filenameExtension: "svg")!]
        panel.nameFieldStringValue = "Document.inkpen"
        panel.title = "Save Document"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            // Update current document URL
            currentDocumentURL = url
            saveDocumentToURL(url)
        }
    }
    
    private func saveDocumentToURL(_ url: URL) {
        do {
            // Check file extension to determine format
            if url.pathExtension.lowercased() == "svg" {
                try FileOperations.exportToSVG(document, url: url)
                Log.info("✅ Successfully saved document as SVG to: \(url.path)", category: .fileOperations)
            } else {
                try FileOperations.exportToJSON(document, url: url)
                // Generate and set custom document icon only for inkpen files
                DocumentIconGenerator.shared.setCustomIcon(for: url, document: document)
                Log.info("✅ Successfully saved document to: \(url.path)", category: .fileOperations)
            }
            
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
    
    private func newDocument() {
        // Show the new document setup window
        showingNewDocumentSetup = true
    }
    
    private func loadImportedDocument(_ importedDoc: VectorDocument) {
        // Reset view state BEFORE loading document to prevent two-step process
        document.zoomLevel = 1.0
        document.canvasOffset = .zero
        
        // Load the imported SVG document into the main Ink Pen interface
        document.settings = importedDoc.settings
        document.layers = importedDoc.layers
        document.rgbSwatches = importedDoc.rgbSwatches
        document.cmykSwatches = importedDoc.cmykSwatches
        document.hsbSwatches = importedDoc.hsbSwatches
        
        document.selectedLayerIndex = importedDoc.selectedLayerIndex
        document.selectedShapeIDs = importedDoc.selectedShapeIDs
        document.selectedTextIDs = importedDoc.selectedTextIDs
        document.textObjects = importedDoc.textObjects
        
        // CRITICAL FIX: Sync unified objects system to ensure imported images are properly registered
        document.updateUnifiedObjectsOptimized()
        
        // Reset tool and view states for the new document
        document.currentTool = appState.defaultTool
        document.viewMode = .color
        
        // Clear the current document URL (imported document needs to be saved)
        currentDocumentURL = nil
        
        Log.info("✅ Loaded imported SVG document into Ink Pen - \(document.layers.count) layers, \(document.layers.reduce(0) { $0 + $1.shapes.count }) shapes", category: .fileOperations)
        
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
    
    private func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json, UTType.svg, UTType.inkpen]
        panel.allowsMultipleSelection = false
        panel.title = "Open Document"
        
        panel.begin { response in
            guard response == .OK, let url = panel.urls.first else { return }
            
            let fileExtension = url.pathExtension.lowercased()
            
            Task {
                do {
                    let loadedDocument: VectorDocument
                    
                    if fileExtension == "svg" {
                        // Import SVG file
                        loadedDocument = try await FileOperations.importFromSVG(url: url)
                    } else if fileExtension == "inkpen" {
                        // Import Ink Pen document file
                        loadedDocument = try FileOperations.importFromJSON(url: url)
                    } else {
                        // Import JSON file (default)
                        loadedDocument = try FileOperations.importFromJSON(url: url)
                    }
                    
                    // Replace current document with loaded one
                    await MainActor.run {
                        // Reset view state BEFORE loading document to prevent two-step process
                        document.zoomLevel = 1.0
                        document.canvasOffset = .zero
                        
                        // Update the document by copying all properties
                        document.settings = loadedDocument.settings
                        document.layers = loadedDocument.layers
                        document.rgbSwatches = loadedDocument.rgbSwatches
                        document.cmykSwatches = loadedDocument.cmykSwatches
                        document.hsbSwatches = loadedDocument.hsbSwatches
                        
                        document.selectedLayerIndex = loadedDocument.selectedLayerIndex
                        document.selectedShapeIDs = loadedDocument.selectedShapeIDs
                        document.selectedTextIDs = loadedDocument.selectedTextIDs
                        document.textObjects = loadedDocument.textObjects
                        document.currentTool = loadedDocument.currentTool
                        document.viewMode = loadedDocument.viewMode
                        // DON'T copy zoom/offset - we'll set them to fit-to-page
                        document.showRulers = loadedDocument.showRulers
                        document.snapToGrid = loadedDocument.snapToGrid
                        
                        // CRITICAL FIX: Sync unified objects system to ensure imported images are properly registered
                        document.updateUnifiedObjectsOptimized()
                        
                        // Update current document URL
                        currentDocumentURL = url
                        
                        Log.info("✅ Successfully opened \(fileExtension.uppercased()) document from: \(url.path)", category: .fileOperations)
                        
                        // Defer fit to page operation to prevent blocking
                        Task {
                            await performMainViewOpenDocumentSetupAsync()
                        }
                        
                    }
                    
                } catch {
                    Log.error("❌ Open failed: \(error)", category: .error)
                    
                    // Show error notification
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Open Failed"
                        alert.informativeText = "Error: \(error.localizedDescription)"
                        alert.alertStyle = .critical
                        alert.runModal()
                    }
                }
            }
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
    
    // MARK: - Professional DWF Export
    private func exportToDWF(with options: DWFExportOptions) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "dwf")].compactMap { $0 }
        panel.nameFieldStringValue = "export.dwf"
        panel.title = "Export as DWF"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            do {
                try FileOperations.exportDWF(document, url: url, options: options)
                
                Log.info("✅ Successfully exported DWF to: \(url.path)", category: .fileOperations)
                
            } catch {
                Log.error("❌ DWF export failed: \(error)", category: .error)
                
                // Show error notification
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "DWF Export Failed"
                    alert.informativeText = "Error: \(error.localizedDescription)"
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
    
    // MARK: - Development Functions
    private func runPathOperationsBenchmark() {
        Log.performance("🚀 RUNNING PATH OPERATIONS BENCHMARK", level: .info)
        Log.performance("Benchmarking CoreGraphics performance...", level: .info)
        
        // Create test paths
        let testCases = [
            ("Simple Circles", createTestCircles()),
            ("Complex Curves", createTestComplexPaths()),
            ("Many Points", createTestManyPointPaths())
        ]
        
        for (name, paths) in testCases {
            Log.performance("\n📊 Testing: \(name)", level: .info)
            benchmarkPathOperations(name: name, pathA: paths.0, pathB: paths.1)
        }
        
        Log.performance("\n✅ BENCHMARK COMPLETE", level: .info)
    }
    
    private func createTestCircles() -> (CGPath, CGPath) {
        let pathA = CGMutablePath()
        pathA.addEllipse(in: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let pathB = CGMutablePath()
        pathB.addEllipse(in: CGRect(x: 50, y: 50, width: 100, height: 100))
        
        return (pathA, pathB)
    }
    
    private func createTestComplexPaths() -> (CGPath, CGPath) {
        let pathA = CGMutablePath()
        pathA.move(to: CGPoint(x: 0, y: 50))
        pathA.addCurve(to: CGPoint(x: 100, y: 50), 
                      control1: CGPoint(x: 25, y: 0), 
                      control2: CGPoint(x: 75, y: 100))
        pathA.addCurve(to: CGPoint(x: 0, y: 50), 
                      control1: CGPoint(x: 75, y: 25), 
                      control2: CGPoint(x: 25, y: 75))
        pathA.closeSubpath()
        
        let pathB = CGMutablePath()
        pathB.move(to: CGPoint(x: 50, y: 0))
        pathB.addCurve(to: CGPoint(x: 50, y: 100), 
                      control1: CGPoint(x: 100, y: 25), 
                      control2: CGPoint(x: 0, y: 75))
        pathB.addCurve(to: CGPoint(x: 50, y: 0), 
                      control1: CGPoint(x: 25, y: 75), 
                      control2: CGPoint(x: 75, y: 25))
        pathB.closeSubpath()
        
        return (pathA, pathB)
    }
    
    private func createTestManyPointPaths() -> (CGPath, CGPath) {
        let pathA = CGMutablePath()
        pathA.move(to: CGPoint(x: 0, y: 0))
        for i in 1...100 {
            let x = CGFloat(i)
            let y = sin(CGFloat(i) * 0.1) * 50 + 50
            pathA.addLine(to: CGPoint(x: x, y: y))
        }
        pathA.closeSubpath()
        
        let pathB = CGMutablePath()
        pathB.move(to: CGPoint(x: 0, y: 25))
        for i in 1...100 {
            let x = CGFloat(i)
            let y = cos(CGFloat(i) * 0.1) * 50 + 75
            pathB.addLine(to: CGPoint(x: x, y: y))
        }
        pathB.closeSubpath()
        
        return (pathA, pathB)
    }
    
    private func benchmarkPathOperations(name: String, pathA: CGPath, pathB: CGPath) {
        let iterations = 100
        
        // Benchmark CoreGraphics
        let coreGraphicsStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            let _ = pathA.union(pathB, using: .winding)
            let _ = pathA.intersection(pathB, using: .winding)
            let _ = pathA.subtracting(pathB, using: .winding)
        }
        let coreGraphicsTime = CFAbsoluteTimeGetCurrent() - coreGraphicsStart
        
        Log.performance("  CoreGraphics: \(String(format: "%.4f", coreGraphicsTime))s (\(iterations) iterations)", level: .info)
    }
    
    // MARK: - Professional DWG Export
    private func exportToDWG(with options: DWGExportOptions) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "dwg")].compactMap { $0 }
        panel.nameFieldStringValue = "export.dwg"
        panel.title = "Export as DWG"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            do {
                try FileOperations.exportDWG(document, url: url, options: options)
                
                Log.info("✅ Successfully exported DWG to: \(url.path)", category: .fileOperations)
                
            } catch {
                Log.error("❌ DWG export failed: \(error)", category: .error)
                
                // Show error notification
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "DWG Export Failed"
                    alert.informativeText = "Error: \(error.localizedDescription)"
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }
}


// Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
