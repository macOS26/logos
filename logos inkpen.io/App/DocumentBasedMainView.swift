//
//  DocumentBasedMainView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentBasedMainView: View {
    @ObservedObject var document: VectorDocument // External document from DocumentGroup
    let fileURL: URL? // Current document file URL
    @StateObject private var documentState = DocumentState()
    @Environment(AppState.self) private var appState
    @State private var showingDocumentSettings = false
    @State private var showingExportDialog = false
    @State private var showingColorPicker = false
    @State private var currentDocumentURL: URL? = nil
    @State private var showingImportDialog = false
    @State private var importResult: VectorImportResult?
    @State private var showingImportProgress = false
    @State private var showingSVGTestHarness = false
    @State private var showingPressureCalibration = false
    @State private var hasInitializedTool = false

    var body: some View {
        // EXACT REPLICATION of MainView structure - FIXED status bar position
        VStack(spacing: 0) {
            // Main Content Area - EXACT HStack structure from MainView
            HStack(spacing: 0) {
                // Left Toolbar - Fixed width, hugs left - EXACT MainView specs
                VerticalToolbar(document: document)
                    .frame(width: 48) // EXACT MainView width
                    .contentShape(Rectangle()) // CRITICAL: Toolbar has its own hit testing bounds
                    .background(Color.black.opacity(0.8)) // Visual confirmation of toolbar bounds
                    .zIndex(100) // CRITICAL: Toolbar above DrawingCanvas
                
                // Center Drawing Area - Flexible width with minimum - EXACT MainView structure
                GeometryReader { geometry in
                    // Drawing canvas area - CLIPPED AND CONSTRAINED
                    ZStack {
                        // DEBUGGING: Background to see exact bounds
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false) // Background doesn't capture gestures
                        
                        // Main Drawing Canvas - FULL PASTEBOARD GESTURE COVERAGE
                        DrawingCanvas(document: document)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle()) // CRITICAL: Full gesture area including pasteboard
                            .background(Color.clear) // Ensure no background extension
                            .zIndex(1) // CRITICAL: Canvas below panels but above background
                            .allowsHitTesting(true) // CRITICAL: Ensure gesture capture everywhere
                        
                        // Rulers - CRITICAL: Above canvas but below panels
                        RulersView(document: document, geometry: geometry)
                            .zIndex(50) // CRITICAL: Rulers above canvas but below toolbar/panels
                            .allowsHitTesting(true) // Allow ruler interactions (taps, drags, right-clicks)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minWidth: 400, minHeight: 300) // MINIMUM: Ensure drawing area is never crushed
                }
                .frame(maxWidth: .infinity)
                .frame(minWidth: 500) // MINIMUM: Ensure center area has enough space
                .contentShape(Rectangle()) // CRITICAL: Define exact hit testing bounds for center column
                .allowsHitTesting(true) // CRITICAL: Center column captures all gestures
                
                // Right Panel - Fixed width, hugs right - EXACT MainView specs
                RightPanel(document: document)
                    .frame(width: 280) // EXACT MainView width
                    .frame(minWidth: 280) // ENSURE: Panel width is always preserved
                    .zIndex(100) // CRITICAL: Right panel above DrawingCanvas
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: 828, minHeight: 400) // MINIMUM: 48 + 500 + 280 = 828 minimum layout width
            
            // Status Bar at bottom - MOVED OUTSIDE canvas area to prevent overlap
            StatusBar(document: document)
        }
        .frame(minHeight: 524) // MINIMUM: Ensure overall height accommodates all elements + status bar (500 + 24)
        .toolbarBackground(Color(NSColor.controlBackgroundColor), for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {
            // CUSTOM DOCUMENT TOOLBAR with icon and clickable path navigation
            //            ToolbarItem(placement: .principal) {
            //                DocumentTitleToolbar(fileURL: fileURL)
            //            }
            
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
        // New Document Setup has moved to its own WindowGroup; remove sheet
        .sheet(isPresented: $showingDocumentSettings) {
            DocumentSettingsView(document: document)
        }
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
        .onAppear {
            // Hydrate linked images when opened via DocumentGroup (where init lacks URL context)
            if let url = fileURL {
                ImageContentRegistry.setBaseDirectory(url.deletingLastPathComponent())
                for unifiedObject in document.unifiedObjects {
                    if case .shape(let shape) = unifiedObject.objectType {
                        _ = ImageContentRegistry.hydrateImageIfAvailable(for: shape)
                    }
                }
            }
        }
        .onChange(of: fileURL) { oldURL, newURL in
            // When DocumentGroup completes Save As, the fileURL updates.
            // Generate the custom icon and SVG sidecar preview at that path.
            guard let url = newURL else { return }
            currentDocumentURL = url
            DocumentIconGenerator.shared.setCustomIcon(for: url, document: document)
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [
                .svg,                                    // SVG files
                .pdf,                                    // PDF files
                .png, // PNG images only
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
        .sheet(isPresented: $showingPressureCalibration) {
            PressureCalibrationView()
                .frame(width: 1200, height: 800)
        }
        .onAppear {
            // Only apply default tool once when document is first opened
            if !hasInitializedTool {
                document.currentTool = appState.defaultTool
                hasInitializedTool = true
                Log.info("🛠️ Applied default tool \(appState.defaultTool.rawValue) to DocumentGroup document (initial setup)", category: .general)
            }
            
            // Connect document to menu system
            documentState.setDocument(document)
            
            // If a New Document was configured in the setup window, apply it now
            if let configured = appState.pendingNewDocument {
                loadImportedDocument(configured)
                appState.pendingNewDocument = nil
                Log.info("✅ Applied pending new document settings from setup window", category: .general)
            }
            
            // Defer fit to page operation to prevent blocking
            Task {
                await performDocumentGroupSetupAsync()
            }
        }
        .onDisappear {
            // CRITICAL: Clean up DocumentState when view disappears to prevent retain cycles
            Log.startup("📄 DocumentBasedMainView disappearing - cleaning up DocumentState")
            documentState.cleanup()
        }
        // Cleanup is triggered directly by the AppDelegate via DocumentStateRegistry
        .focusedSceneObject(documentState)
    }
    
    // MARK: - Async Initialization
    
    private func performDocumentGroupSetupAsync() async {
        // Wait a brief moment for geometry to be established
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        await MainActor.run {
            document.requestZoom(to: 0.0, mode: .fitToPage)
            Log.info("🔍 DocumentGroup: Applied fit to page", category: .general)
        }
    }
    
    // MARK: - Document Operations

    private func loadImportedDocument(_ importedDoc: VectorDocument) {
        // Reset view state BEFORE loading document to prevent two-step process
        document.zoomLevel = 1.0
        document.canvasOffset = .zero
        
        // Load the imported document into the current document
        document.settings = importedDoc.settings
        document.layers = importedDoc.layers
        document.rgbSwatches = importedDoc.rgbSwatches
        document.cmykSwatches = importedDoc.cmykSwatches
        document.hsbSwatches = importedDoc.hsbSwatches
        
        document.selectedLayerIndex = importedDoc.selectedLayerIndex
        document.selectedShapeIDs = importedDoc.selectedShapeIDs
        document.selectedTextIDs = importedDoc.selectedTextIDs
        // Text is now managed in unified system
        document.currentTool = appState.defaultTool
        document.viewMode = .color
        document.showRulers = importedDoc.showRulers
        document.snapToGrid = importedDoc.snapToGrid
        
        Log.info("✅ Loaded imported document - \(document.layers.count) layers, \(document.unifiedObjects.count) objects", category: .fileOperations)
        
        // Defer fit to page operation to prevent blocking
        Task {
            await performImportedDocumentSetupAsync()
        }
    }
    
    private func performImportedDocumentSetupAsync() async {
        // Wait a brief moment for geometry to be established
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        await MainActor.run {
            document.requestZoom(to: 0.0, mode: .fitToPage)
            Log.info("🔍 PROPER FIT TO PAGE: Applied for imported document after geometry established", category: .general)
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
                    
                    // Defer fit to page operation to prevent blocking
                    Task {
                        await performVectorImportSetupAsync()
                    }
                } else {
                    Log.error("❌ Import failed: \(result.errors.map { $0.localizedDescription }.joined(separator: ", "))", category: .error)
                }
                
                // Show import result dialog
                importResult = result
            }
        }
    }
    
    private func performVectorImportSetupAsync() async {
        // Wait a brief moment for geometry to be established
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        await MainActor.run {
            document.requestZoom(to: 0.0, mode: .fitToPage)
            Log.info("🔍 PROPER FIT TO PAGE: Applied after vector import with geometry established", category: .general)
        }
    }
    
    // MARK: - Helper Functions

    private func runPasteboardDiagnostics() {
        Log.info("🔧 DocumentGroup: Running pasteboard diagnostics", category: .general)
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
