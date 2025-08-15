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
                        
                        // Drawer toggle buttons
                        VStack(spacing: 4) {
                            DrawerToggleButton(icon: "sidebar.left") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isLeftDrawerOpen.toggle()
                                }
                            }
                            
                            DrawerToggleButton(icon: "rectangle.bottomhalf.inset.filled") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isBottomDrawerOpen.toggle()
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        
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
                    .clipped() // CRITICAL: Clip content to prevent overflow into other panels
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
            
            // Drawer overlays
            DrawerView(direction: .left, size: 320, isOpen: $isLeftDrawerOpen) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Left Drawer")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("This is a sliding drawer from the left! You can put any content here.")
                        .font(.body)
                    
                    Divider()
                    
                    // Example content
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Create New Layer") {
                            document.addLayer(name: "New Layer")
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Duplicate Selection") {
                            // Add duplicate functionality
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear Canvas") {
                            // Add clear functionality  
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    Button("Close Drawer") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isLeftDrawerOpen = false
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            
            DrawerView(direction: .bottom, size: 240, isOpen: $isBottomDrawerOpen) {
                VStack(spacing: 16) {
                    Text("Bottom Drawer")
                        .font(.headline)
                    
                    Text("This is a sliding drawer from the bottom!")
                        .font(.body)
                    
                    Divider()
                    
                    // Example content
                    HStack(spacing: 16) {
                        VStack {
                            Text("Tools")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("Brush") { document.currentTool = .brush }
                                Button("Pen") { document.currentTool = .bezierPen }
                                Button("Selection") { document.currentTool = .selection }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("Quick Settings")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("Grid On") { }
                                Button("Snap On") { }
                                Button("Guides") { }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Close Drawer") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isBottomDrawerOpen = false
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
                .padding()
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
        panel.allowedContentTypes = [UTType.json, UTType.inkpen]
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
            try FileOperations.exportToJSON(document, url: url)
            
            // Generate and set custom document icon
            DocumentIconGenerator.shared.setCustomIcon(for: url, document: document)
            
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
                    
                    // Add imported shapes to current layer without individual undo saves
                    guard let layerIndex = document.selectedLayerIndex else { return }
                    var newShapeIDs: Set<UUID> = []
                    
                    for shape in result.shapes {
                        document.layers[layerIndex].addShape(shape)
                        newShapeIDs.insert(shape.id)
                    }
                    
                    // Select all imported shapes
                    document.selectedShapeIDs = newShapeIDs
                    
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

struct MainToolbarContent: ToolbarContent {
    @ObservedObject var document: VectorDocument
    let appState: AppState
    @Binding var currentDocumentURL: URL?
    @Binding var showingDocumentSettings: Bool
    @Binding var showingExportDialog: Bool
    @Binding var showingColorPicker: Bool
    let onSave: () -> Void
    let onSaveAs: () -> Void
    let onOpen: () -> Void
    let onNew: () -> Void
    @Binding var showingImportDialog: Bool
    @Binding var importResult: VectorImportResult?
    @Binding var showingImportProgress: Bool
    @Binding var showingDWFExportDialog: Bool
    @Binding var showingDWGExportDialog: Bool
    @Binding var showingSVGTestHarness: Bool
    @Binding var showingPressureCalibration: Bool
    let onRunDiagnostics: () -> Void
    
    // MARK: - Path Closing Support Functions
    private func hasOpenPaths() -> Bool {
        // Check if there are any open paths that can be closed
        for layer in document.layers {
            for shape in layer.shapes {
                // Check if path has no close element and has enough points to close
                let hasCloseElement = shape.path.elements.contains { element in
                    if case .close = element { return true }
                    return false
                }
                
                // Count actual points (not close elements)
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
        return false
    }
    
    private func closeOpenPaths() {
        // Close all open paths in the document
        document.saveToUndoStack()
        
        for layerIndex in document.layers.indices {
            for shapeIndex in document.layers[layerIndex].shapes.indices {
                let shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // Check if path is open and has enough points
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
                    // Add close element
                    var newElements = shape.path.elements
                    newElements.append(.close)
                    
                    let newPath = VectorPath(elements: newElements, isClosed: true)
                    document.layers[layerIndex].shapes[shapeIndex].path = newPath
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                }
            }
        }
        
        document.objectWillChange.send()
    }
    
    private func hasSelectedPathsToClose() -> Bool {
        // Check if any selected shapes have open paths that can be closed
        guard !document.selectedShapeIDs.isEmpty else { return false }
        
        for layer in document.layers {
            for shape in layer.shapes {
                if document.selectedShapeIDs.contains(shape.id) {
                    // Check if path has no close element and has enough points to close
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
        // Close paths for selected shapes only
        document.saveToUndoStack()
        
        for layerIndex in document.layers.indices {
            for shapeIndex in document.layers[layerIndex].shapes.indices {
                let shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // Only close if this shape is selected
                if document.selectedShapeIDs.contains(shape.id) {
                    // Check if path is open and has enough points
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
                        // Add close element
                        var newElements = shape.path.elements
                        newElements.append(.close)
                        
                        let newPath = VectorPath(elements: newElements, isClosed: true)
                        document.layers[layerIndex].shapes[shapeIndex].path = newPath
                        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                        Log.info("🎯 Closed selected path for shape \(shape.name)", category: .shapes)
                    }
                }
            }
        }
        
        document.objectWillChange.send()
    }
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // File Operations
            Menu {
                Button("New Document") {
                    onNew()
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Button("Open Document") {
                    onOpen()
                }
                .keyboardShortcut("o", modifiers: [.command])
                
                Divider()
                
                Button("Save") {
                    onSave()
                }
                .keyboardShortcut("s", modifiers: [.command])
                
                Button("Save As...") {
                    onSaveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Divider()
                
                Menu("Export") {
                    Button("Export as DWG (AutoCAD)") {
                        showingDWGExportDialog = true
                    }
                    .help("Export to AutoCAD Drawing format with professional scaling")
                    
                    Button("Export as DWF (AutoCAD)") {
                        showingDWFExportDialog = true
                    }
                    .help("Export to Design Web Format with professional scaling")
                    
                    Divider()
                    
                    Button("Export to Other Formats...") {
                        showingExportDialog = true
                    }
                }
                
                Divider()
                
                Menu("Development") {
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
                }
                
            } label: {
                Image(systemName: "doc.text")
            }
            .help("File Operations")
            
            // ✅ CLEAN TOOLBAR: No duplicate menu functionality
            // Edit and Object commands are handled by proper menu bar menus only
            
            // Close Path button (context-sensitive)
            Button {
                closeOpenPaths()
            } label: {
                Image(systemName: "circle.dashed")
            }
            .help("Close Open Paths (⌘⇧J)")
            .disabled(!hasOpenPaths())
            
            // View Controls
            Button {
                document.viewMode = document.viewMode == .color ? .keyline : .color
            } label: {
                Image(systemName: document.viewMode.iconName)
                    .foregroundColor(document.viewMode == .keyline ? .orange : .primary)
            }
            .help(document.viewMode.description)
            
            Button {
                document.showRulers.toggle()
            } label: {
                Image(systemName: document.showRulers ? "ruler.fill" : "ruler")
            }
            .help("Toggle Rulers")
            
            Button {
                document.snapToGrid.toggle()
            } label: {
                Image(systemName: document.snapToGrid ? "grid.circle.fill" : "grid.circle")
            }
            .help("Toggle Snap to Grid")
            
            // Corner Radius Controls (for selected shapes)
            CornerRadiusToolbar(document: document)
            
            // Zoom Controls
            Menu {
                Button("Zoom In") {
                    onZoomIn()
                }
                .keyboardShortcut("=", modifiers: [.command])
                
                Button("Zoom Out") {
                    onZoomOut()
                }
                .keyboardShortcut("-", modifiers: [.command])
                
                Button("Fit to Page") {
                    onFitToPage()
                }
                .keyboardShortcut("0", modifiers: [.command])
                
                Button("Actual Size") {
                    onActualSize()
                }
                .keyboardShortcut("1", modifiers: [.command])
                
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help("Zoom Controls")
            
            // Snap page to artwork/selection
            Button {
                onSnapPageToArtwork()
            } label: {
                Image(systemName: "rectangle.3.group")
            }
            .help("Snap Page to Artwork Bounds")

            Button {
                onSnapPageToSelection()
            } label: {
                Image(systemName: "selection.pin.in.out")
            }
            .help("Snap Page to Selection Bounds")

            // Document Settings
            Button {
                showingDocumentSettings = true
            } label: {
                Image(systemName: "gear")
            }
            .help("Document Settings")
            
            
          

            if showingImportProgress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.8)
            }
            
            // Performance monitor removed - not working properly
        }
        
        // Optional: Status bar item for zoom level
        ToolbarItem(placement: .status) {
            Text("Zoom: \(Int(document.zoomLevel * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // Performance tracking helper removed - no longer needed
    
    // MARK: - Professional Zoom Functions (Professional Standards)
    
    private func onZoomIn() {
        // Zoom in by 25% (professional standard)
        let newZoom = min(16.0, document.zoomLevel * 1.25)
        document.requestZoom(to: CGFloat(newZoom), mode: .zoomIn)
        Log.info("🔍 ZOOM IN: \(String(format: "%.1f", document.zoomLevel * 100))% → \(String(format: "%.1f", newZoom * 100))%", category: .zoom)
    }
    
    private func onZoomOut() {
        // Zoom out by 25% (professional standard)
        let newZoom = max(0.1, document.zoomLevel / 1.25)
        document.requestZoom(to: CGFloat(newZoom), mode: .zoomOut)
        Log.info("🔍 ZOOM OUT: \(String(format: "%.1f", document.zoomLevel * 100))% → \(String(format: "%.1f", newZoom * 100))%", category: .zoom)
    }
    
    private func onFitToPage() {
        // Fit the entire page to the view (professional standard)
        document.requestZoom(to: 0.0, mode: .fitToPage) // 0.0 signals to calculate fit zoom
        Log.info("🔍 FIT TO PAGE: Calculated optimal zoom to fit page in view", category: .zoom)
    }
    
    private func onActualSize() {
        // Set to 100% zoom (professional standard)
        document.requestZoom(to: 1.0, mode: .actualSize)
        Log.info("🔍 ACTUAL SIZE: Set to 100% zoom", category: .zoom)
    }

    // MARK: - Page Snap Functions
    private func onSnapPageToArtwork() {
        // Compute bounds of visible artwork only (exclude pasteboard/canvas)
        guard let bounds = document.getArtworkBounds(), bounds.width > 0, bounds.height > 0 else { return }
        document.saveToUndoStack()

        // Update page size to artwork bounds
        document.settings.setSizeInPoints(CGSize(width: bounds.width, height: bounds.height))
        document.onSettingsChanged()

        // Move all content so artwork minX/minY becomes (0,0)
        let delta = CGPoint(x: -bounds.minX, y: -bounds.minY)
        document.translateAllContent(by: delta)

        // Fit to new page
        document.requestZoom(to: 0.0, mode: .fitToPage)
    }

    private func onSnapPageToSelection() {
        // Compute combined bounds of selected shapes/text
        guard let selectionBounds = getSelectionBoundsForDocument(), selectionBounds.width > 0, selectionBounds.height > 0 else { return }
        document.saveToUndoStack()

        // Update page size to selection bounds
        document.settings.setSizeInPoints(CGSize(width: selectionBounds.width, height: selectionBounds.height))
        document.onSettingsChanged()

        // Move selection so its minX/minY becomes (0,0) and non-selected relative accordingly
        let delta = CGPoint(x: -selectionBounds.minX, y: -selectionBounds.minY)
        document.translateAllContent(by: delta)

        // Fit to page after change
        document.requestZoom(to: 0.0, mode: .fitToPage)
    }

    private func getSelectionBoundsForDocument() -> CGRect? {
        var combinedBounds: CGRect?
        // Shapes in user layers only (>= 2)
        for (layerIndex, layer) in document.layers.enumerated() where layerIndex >= 2 {
            for shape in layer.shapes {
                if document.selectedShapeIDs.contains(shape.id) {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    combinedBounds = combinedBounds.map { $0.union(shapeBounds) } ?? shapeBounds
                }
            }
        }
        // Text in user layers only
        for textObj in document.textObjects {
            if document.selectedTextIDs.contains(textObj.id), let li = textObj.layerIndex, li >= 2 {
                let textBounds = CGRect(
                    x: textObj.position.x + textObj.bounds.minX,
                    y: textObj.position.y + textObj.bounds.minY,
                    width: textObj.bounds.width,
                    height: textObj.bounds.height
                ).applying(textObj.transform)
                combinedBounds = combinedBounds.map { $0.union(textBounds) } ?? textBounds
            }
        }
        return combinedBounds
    }
    
    // MARK: - Professional Object Management Functions (Industry Standards)
    
    private func bringSelectedToFront() {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        document.saveToUndoStack()
        
        // Get selected shapes and remove them from current positions
        var shapes = document.layers[layerIndex].shapes
        let selectedShapes = shapes.filter { document.selectedShapeIDs.contains($0.id) }
        shapes.removeAll { document.selectedShapeIDs.contains($0.id) }
        
        // Add selected shapes to the end (front)
        shapes.append(contentsOf: selectedShapes)
        
        document.layers[layerIndex].shapes = shapes
        Log.info("⬆️⬆️ Brought to front \(document.selectedShapeIDs.count) objects", category: .shapes)
    }
    
    private func bringSelectedForward() {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        document.saveToUndoStack()
        
        // Move each selected shape forward by one position
        var shapes = document.layers[layerIndex].shapes
        
        // Process from back to front to avoid index conflicts
        for i in (0..<shapes.count).reversed() {
            if document.selectedShapeIDs.contains(shapes[i].id) && i < shapes.count - 1 {
                shapes.swapAt(i, i + 1)
            }
        }
        
        document.layers[layerIndex].shapes = shapes
        Log.info("⬆️ Brought forward \(document.selectedShapeIDs.count) objects", category: .shapes)
    }
    
    private func sendSelectedBackward() {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        document.saveToUndoStack()
        
        // Move each selected shape backward by one position
        var shapes = document.layers[layerIndex].shapes
        
        // Process from front to back to avoid index conflicts
        for i in 0..<shapes.count {
            if document.selectedShapeIDs.contains(shapes[i].id) && i > 0 {
                shapes.swapAt(i, i - 1)
            }
        }
        
        document.layers[layerIndex].shapes = shapes
        Log.info("⬇️ Sent backward \(document.selectedShapeIDs.count) objects", category: .shapes)
    }
    
    private func sendSelectedToBack() {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        document.saveToUndoStack()
        
        // Get selected shapes and remove them from current positions
        var shapes = document.layers[layerIndex].shapes
        let selectedShapes = shapes.filter { document.selectedShapeIDs.contains($0.id) }
        shapes.removeAll { document.selectedShapeIDs.contains($0.id) }
        
        // Insert selected shapes at the beginning (back)
        shapes.insert(contentsOf: selectedShapes, at: 0)
        
        document.layers[layerIndex].shapes = shapes
        Log.info("⬇️⬇️ Sent to back \(document.selectedShapeIDs.count) objects", category: .shapes)
    }
    
    private func lockSelectedObjects() {
        guard let layerIndex = document.selectedLayerIndex else { return }
        
        document.saveToUndoStack()
        
        // Lock selected shapes
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                document.layers[layerIndex].shapes[shapeIndex].isLocked = true
            }
        }
        
        // Lock selected text objects
        for textID in document.selectedTextIDs {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                document.textObjects[textIndex].isLocked = true
            }
        }
        
        // Clear selection (locked objects can't be selected)
        document.selectedShapeIDs.removeAll()
        document.selectedTextIDs.removeAll()
        
        Log.info("🔒 Locked selected objects", category: .shapes)
    }
    
    private func unlockAllObjects() {
        document.saveToUndoStack()
        
        // Unlock all shapes in all layers
        for layerIndex in document.layers.indices {
            for shapeIndex in document.layers[layerIndex].shapes.indices {
                document.layers[layerIndex].shapes[shapeIndex].isLocked = false
            }
        }
        
        // Unlock all text objects
        for textIndex in document.textObjects.indices {
            document.textObjects[textIndex].isLocked = false
        }
        
        Log.info("🔓 Unlocked all objects", category: .shapes)
    }
    
    private func hideSelectedObjects() {
        guard let layerIndex = document.selectedLayerIndex else { return }
        
        document.saveToUndoStack()
        
        // Hide selected shapes
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                document.layers[layerIndex].shapes[shapeIndex].isVisible = false
            }
        }
        
        // Hide selected text objects
        for textID in document.selectedTextIDs {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                document.textObjects[textIndex].isVisible = false
            }
        }
        
        // Clear selection (hidden objects can't be selected)
        document.selectedShapeIDs.removeAll()
        document.selectedTextIDs.removeAll()
        
        Log.info("👁️‍🗨️ Hidden selected objects", category: .shapes)
    }
    
    private func showAllObjects() {
        document.saveToUndoStack()
        
        // Show all shapes in all layers
        for layerIndex in document.layers.indices {
            for shapeIndex in document.layers[layerIndex].shapes.indices {
                document.layers[layerIndex].shapes[shapeIndex].isVisible = true
            }
        }
        
        // Show all text objects
        for textIndex in document.textObjects.indices {
            document.textObjects[textIndex].isVisible = true
        }
        
        Log.info("👁️ Showed all objects", category: .shapes)
    }
}

struct StatusBar: View {
    @ObservedObject var document: VectorDocument
    
    var body: some View {
        HStack {
            // Current Tool with context-sensitive instructions
            VStack(alignment: .leading, spacing: 2) {
                Text("Tool: \(document.currentTool.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // PROFESSIONAL BEZIER TOOL HINTS
                if document.currentTool == .bezierPen {
                    Text("Click to place points • Click near first point to close • Double-click to finish • ⌘J to close")
                        .font(.caption2)
                        .foregroundColor(.blue)
                } else if document.currentTool == .directSelection {
                    Text("Select anchor points and handles • ⌘⇧J to close open paths")
                        .font(.caption2)
                        .foregroundColor(.blue)
                } else if document.currentTool == .warp {
                    Text("Select objects to warp • Drag handles to distort • Use envelope tool for advanced warping")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Selection Info with Object Dimensions (single line)
            HStack {
                if document.selectedShapeIDs.isEmpty && document.selectedTextIDs.isEmpty {
                    Text("No selection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    let totalSelected = document.selectedShapeIDs.count + document.selectedTextIDs.count
                    
                    // Show selection count and dimensions on one line
                    if let bounds = getSelectionBounds() {
                        Text("\(totalSelected) selected  •  W: \(formatDimension(bounds.width))pt H: \(formatDimension(bounds.height))pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(totalSelected) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Document Info - FIXED: Show proper decimals for dimensions
            Text("Size: \(formatDimension(document.settings.width))×\(formatDimension(document.settings.height)) \(document.settings.unit.abbreviation)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Zoom Level
            Text("Zoom: \(Int(document.zoomLevel * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .top
        )
    }
    
    /// Format dimension values to show decimals only when needed
    private func formatDimension(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)  // Show as integer if no decimal
        } else {
            return String(format: "%.1f", value)  // Show one decimal place
        }
    }
    
    /// Calculate combined bounds of all selected objects
    private func getSelectionBounds() -> CGRect? {
        var combinedBounds: CGRect?
        
        // Include selected shapes
        for layerIndex in document.layers.indices {
            let layer = document.layers[layerIndex]
            for shape in layer.shapes {
                if document.selectedShapeIDs.contains(shape.id) {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    if combinedBounds == nil {
                        combinedBounds = shapeBounds
                    } else {
                        combinedBounds = combinedBounds!.union(shapeBounds)
                    }
                }
            }
        }
        
        // Include selected text objects
        for textObj in document.textObjects {
            if document.selectedTextIDs.contains(textObj.id) {
                // Calculate absolute text bounds
                let textBounds = CGRect(
                    x: textObj.position.x + textObj.bounds.minX,
                    y: textObj.position.y + textObj.bounds.minY,
                    width: textObj.bounds.width,
                    height: textObj.bounds.height
                ).applying(textObj.transform)
                
                if combinedBounds == nil {
                    combinedBounds = textBounds
                } else {
                    combinedBounds = combinedBounds!.union(textBounds)
                }
            }
        }
        
        return combinedBounds
    }
}

struct DocumentSettingsView: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Professional Header
            professionalHeader
            
            // Main Content
            ScrollView {
                VStack(spacing: 24) {
                    // Document Size Section
                    documentSizeSection
                    
                    // Color Settings Section
                    colorSettingsSection
                    
                    // Display Settings Section
                    displaySettingsSection
                    
                    // Drawing Tools Section
                    drawingToolsSection
                    
                    // Advanced Smoothing Section
                    advancedSmoothingSection
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Professional Footer
            professionalFooter
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Professional Header
    private var professionalHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // App Icon and Title
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Document Settings")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Configure document properties and preferences")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Close Button
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.ui.lightGrayBackground)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Close")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Document Size Section
    private var documentSizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ruler")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Document Size")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 16) {
                // Dimensions
                HStack(spacing: 16) {
                    // Width
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Width")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("Width", value: $document.settings.width, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 100)
                                .onChange(of: document.settings.width) {
                                    document.onSettingsChanged()
                                }
                            
                            Text(document.settings.unit.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Height
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Height")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("Height", value: $document.settings.height, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 100)
                                .onChange(of: document.settings.height) {
                                    document.onSettingsChanged()
                                }
                            
                            Text(document.settings.unit.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Units
                VStack(alignment: .leading, spacing: 6) {
                    Text("Units")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("Unit", selection: $document.settings.unit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue.capitalized).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: document.settings.unit) {
                        document.onSettingsChanged()
                    }
                }
            }
        }
    }
    
    // MARK: - Color Settings Section
    private var colorSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paintpalette")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Color Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Color Mode")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Picker("Color Mode", selection: $document.settings.colorMode) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.uppercased()).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }
    
    // MARK: - Display Settings Section
    private var displaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Display Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 16) {
                // Resolution
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resolution")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        TextField("Resolution", value: $document.settings.resolution, format: .number)
                            .textFieldStyle(ProfessionalTextFieldStyle())
                            .frame(width: 100)
                        
                        Text("DPI")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Display Options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Options")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 6) {
                        ProfessionalToggle(title: "Show Rulers", isOn: $document.settings.showRulers)
                        ProfessionalToggle(title: "Show Grid", isOn: $document.settings.showGrid)
                        ProfessionalToggle(title: "Snap to Grid", isOn: $document.settings.snapToGrid)
                            .disabled(!document.settings.showGrid)
                    }
                }
                
                // Grid Spacing
                if document.settings.showGrid {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Grid Spacing")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("Grid Spacing", value: $document.settings.gridSpacing, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 100)
                            
                            Text(document.settings.unit.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Drawing Tools Section
    private var drawingToolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Drawing Tools")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Freehand Smoothing")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f", document.settings.freehandSmoothingTolerance))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                
                VStack(spacing: 8) {
                    Slider(
                        value: $document.settings.freehandSmoothingTolerance,
                        in: 0.1...10.0,
                        step: 0.1
                    ) {
                        Text("Freehand Smoothing")
                    } minimumValueLabel: {
                        Text("Detail")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("Smooth")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .onChange(of: document.settings.freehandSmoothingTolerance) {
                        document.onSettingsChanged()
                    }
                    
                    Text("Lower values preserve more detail, higher values create smoother curves")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
    
    // MARK: - Advanced Smoothing Section
    private var advancedSmoothingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.path")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.purple)
                
                Text("Advanced Smoothing")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $document.settings.advancedSmoothingEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .onChange(of: document.settings.advancedSmoothingEnabled) {
                        document.onSettingsChanged()
                    }
            }
            
            if document.settings.advancedSmoothingEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    // Real-time smoothing
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Real-time Smoothing")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $document.settings.realTimeSmoothingEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                                .onChange(of: document.settings.realTimeSmoothingEnabled) {
                                    document.onSettingsChanged()
                                }
                        }
                        
                        if document.settings.realTimeSmoothingEnabled {
                            HStack {
                                Text("Strength")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(String(format: "%.1f", document.settings.realTimeSmoothingStrength))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.purple.opacity(0.1))
                                    )
                            }
                            
                            Slider(
                                value: $document.settings.realTimeSmoothingStrength,
                                in: 0.0...1.0,
                                step: 0.1
                            ) {
                                Text("Real-time Smoothing Strength")
                            } minimumValueLabel: {
                                Text("Light")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                            } maximumValueLabel: {
                                Text("Strong")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .onChange(of: document.settings.realTimeSmoothingStrength) {
                                document.onSettingsChanged()
                            }
                        }
                    }
                    
                    // Chaikin smoothing iterations
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Chaikin Iterations")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(document.settings.chaikinSmoothingIterations)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.purple.opacity(0.1))
                                )
                        }
                        
                        Slider(
                            value: Binding<Double>(
                                get: { Double(document.settings.chaikinSmoothingIterations) },
                                set: { document.settings.chaikinSmoothingIterations = Int($0) }
                            ),
                            in: 1...3,
                            step: 1
                        ) {
                            Text("Chaikin Smoothing Iterations")
                        } minimumValueLabel: {
                            Text("1")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("3")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .onChange(of: document.settings.chaikinSmoothingIterations) {
                            document.onSettingsChanged()
                        }
                        
                        Text("More iterations create smoother curves but may lose detail")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Advanced options
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Adaptive Tension")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $document.settings.adaptiveTensionEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                                .scaleEffect(0.8)
                                .onChange(of: document.settings.adaptiveTensionEnabled) {
                                    document.onSettingsChanged()
                                }
                        }
                        
                        HStack {
                            Text("Preserve Sharp Corners")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $document.settings.preserveSharpCorners)
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                                .scaleEffect(0.8)
                                .onChange(of: document.settings.preserveSharpCorners) {
                                    document.onSettingsChanged()
                                }
                        }
                    }
                }
                .padding(.leading, 12)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Professional Footer
    private var professionalFooter: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Spacer()
                
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(ProfessionalPrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct ExportView: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    @State private var exportFormat: ExportFormat = .svg
    @State private var exportScale: Double = 1.0  // For PNG scale (1x, 2x, 3x, etc.)
    @State private var exportQuality: Double = 0.9  // For JPEG quality (0.1-1.0)
    
    enum ExportFormat: String, CaseIterable {
        case svg = "SVG"
        case pdf = "PDF"
        case png = "PNG"
        case jpeg = "JPEG"
        
        var fileExtension: String {
            switch self {
            case .svg: return "svg"
            case .pdf: return "pdf"
            case .png: return "png"
            case .jpeg: return "jpg"
            }
        }
        
        var contentType: UTType {
            switch self {
            case .svg: return UTType(filenameExtension: "svg")!
            case .pdf: return .pdf
            case .png: return .png
            case .jpeg: return .jpeg
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if exportFormat == .png {
                    Section(header: Text("Resolution")) {
                        HStack {
                            Text("Scale:")
                            Spacer()
                            Picker("Scale", selection: $exportScale) {
                                Text("1x").tag(1.0)
                                Text("2x").tag(2.0)
                                Text("3x").tag(3.0)
                                Text("4x").tag(4.0)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        let size = document.settings.sizeInPoints
                        Text("Output size: \(Int(size.width * exportScale))×\(Int(size.height * exportScale)) pixels")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if exportFormat == .jpeg {
                    Section(header: Text("Resolution")) {
                        HStack {
                            Text("Scale:")
                            Spacer()
                            Picker("Scale", selection: $exportScale) {
                                Text("1x").tag(1.0)
                                Text("2x").tag(2.0)
                                Text("3x").tag(3.0)
                                Text("4x").tag(4.0)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        let size = document.settings.sizeInPoints
                        Text("Output size: \(Int(size.width * exportScale))×\(Int(size.height * exportScale)) pixels")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section(header: Text("Quality")) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Quality:")
                                Spacer()
                                Text("\(Int(exportQuality * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $exportQuality, in: 0.1...1.0) {
                                Text("Quality")
                            }
                        }
                        
                        Text("Higher quality = larger file size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Export Options")) {
                    Text("Size: \(Int(document.settings.sizeInPoints.width))×\(Int(document.settings.sizeInPoints.height)) points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Layers: \(document.layers.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let totalShapes = document.layers.reduce(0) { $0 + $1.shapes.count }
                    Text("Shapes: \(totalShapes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Export Document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        exportDocument()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 300)
    }
    
    private func exportDocument() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [exportFormat.contentType]
        panel.nameFieldStringValue = "Document.\(exportFormat.fileExtension)"
        panel.title = "Export as \(exportFormat.rawValue)"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            do {
                switch exportFormat {
                case .svg:
                    try FileOperations.exportToSVG(document, url: url)
                case .pdf:
                    try FileOperations.exportToPDF(document, url: url)
                case .png:
                    try FileOperations.exportToPNG(document, url: url, scale: CGFloat(exportScale))
                case .jpeg:
                    try FileOperations.exportToJPEG(document, url: url, scale: CGFloat(exportScale), quality: exportQuality)
                }
                
                Log.info("✅ Successfully exported document as \(exportFormat.rawValue) to: \(url.path)", category: .fileOperations)
                
            } catch {
                Log.error("❌ Export failed: \(error)", category: .error)
                
                // Show error notification
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = "Error: \(error.localizedDescription)"
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }
}



// MARK: - Import Result View

struct ImportResultView: View {
    let result: VectorImportResult
    let onDismiss: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.success ? .green : .red)
                    .font(.largeTitle)
                
                VStack(alignment: .leading) {
                    Text(result.success ? "Import Successful" : "Import Failed")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Format: \(result.metadata.originalFormat.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Results Summary
            if result.success {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Imported Objects")
                            .font(.headline)
                        
                        Label("\(result.metadata.shapeCount) shapes", systemImage: "square.and.pencil")
                        Label("\(result.metadata.textObjectCount) text objects", systemImage: "textformat")
                        Label("\(result.metadata.layerCount) layers", systemImage: "square.stack")
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("Document Info")
                            .font(.headline)
                        
                        Label("Size: \(Int(result.metadata.documentSize.width))×\(Int(result.metadata.documentSize.height))", systemImage: "rectangle")
                        Label("DPI: \(Int(result.metadata.dpi))", systemImage: "grid")
                        Label("Units: \(result.metadata.units.rawValue)", systemImage: "ruler")
                    }
                }
            }
            
            // Warnings
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Warnings")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    ForEach(result.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Errors
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Errors")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    ForEach(result.errors, id: \.localizedDescription) { error in
                        Label(error.localizedDescription, systemImage: "xmark.circle")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Actions
            HStack {
                if !result.success {
                    Button("Try Again") {
                        onRetry()
                    }
                }
                
                Spacer()
                
                Button("Close") {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

// Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
