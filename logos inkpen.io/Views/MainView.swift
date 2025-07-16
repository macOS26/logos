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
    
    // MARK: - Development Views State
    @State private var showingCoreGraphicsTest = false
    @State private var showingPathOperationsComparison = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content Area
            HStack(spacing: 0) {
                // Left Toolbar - Fixed width, hugs left - ISOLATED HIT TESTING
                VerticalToolbar(document: document)
                    .frame(width: 48)
                    .contentShape(Rectangle()) // CRITICAL: Toolbar has its own hit testing bounds
                    .background(Color.black.opacity(0.8)) // Visual confirmation of toolbar bounds
                
                                // Center Drawing Area - Flexible width - STRICTLY CONSTRAINED TO CENTER COLUMN
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Drawing canvas area - CLIPPED AND CONSTRAINED
                        ZStack {
                            // DEBUGGING: Background to see exact bounds
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .allowsHitTesting(false) // Background doesn't capture gestures
                            
                            // Main Drawing Canvas - PROPERLY CLIPPED TO CENTER COLUMN ONLY
                            DrawingCanvas(document: document)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped() // CRITICAL: Clip to view bounds - prevents extending under toolbar
                                .background(Color.clear) // Ensure no background extension
                                .padding(.top, document.showRulers ? 20 : 0)
                                .padding(.leading, document.showRulers ? 20 : 0)
                            
                            // Rulers
                            RulersView(document: document, geometry: geometry)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped() // DOUBLE CLIP: Ensure entire ZStack is clipped
                        
                        // Status Bar at bottom
                        StatusBar(document: document)
                            .frame(height: 24)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle()) // CRITICAL: Define exact hit testing bounds for center column
                
                // Right Panel - Fixed width, hugs right
                RightPanel(document: document)
                    .frame(width: 280)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            MainToolbarContent(
            document: document,
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
            onRunDiagnostics: runPasteboardDiagnostics
        )
        }
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
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [
                .svg,                                    // SVG files
                .pdf,                                    // PDF files
                UTType("com.adobe.illustrator.ai-image")!, // Adobe Illustrator files
                UTType("com.adobe.encapsulated-postscript")!, // EPS files
                UTType("com.adobe.postscript")!,         // PostScript files
                UTType(filenameExtension: "ps")!,        // PostScript files (.ps)
                UTType(filenameExtension: "ai")!,        // Adobe Illustrator files (.ai)
                UTType(filenameExtension: "eps")!,       // EPS files (.eps)
                UTType(filenameExtension: "dwf")!,       // DWF files (.dwf)
                .data                                    // Generic data for unknown formats
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importVectorFile(from: url)
            case .failure(let error):
                 print("❌ File import error: \(error)")
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
        .sheet(isPresented: $showingCoreGraphicsTest) {
            CoreGraphicsPathTestView()
                .frame(width: 1000, height: 700)
        }
        .sheet(isPresented: $showingPathOperationsComparison) {
            PathOperationsComparisonView(document: document)
                .frame(width: 1000, height: 700)
        }
        .frame(minWidth: 1200, minHeight: 800)
        // Note: No longer using focusedValue - using focusedSceneObject instead
        .onAppear {
            // SOLUTION: Connect document to menu system using NEW approach
            documentState.setDocument(document)
            
            // Set up notification observers for menu commands
            setupMenuCommandObservers()
            
            setupDocument()
            
            // Auto-fit to page on startup for professional presentation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Use simplified fit-to-page without parameters
                fitToPage()
            }
        }
        .focusedSceneObject(documentState)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Update menu states when app becomes active
            documentState.setDocument(document)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // Note: Menu states now update automatically via @Published properties
        }
    }
    
    // MARK: - Professional Menu Command System (Adobe Illustrator Standards)
    
    private func setupMenuCommandObservers() {
        // Tool Commands
        NotificationCenter.default.addObserver(forName: .switchTool, object: nil, queue: .main) { notification in
            if let tool = notification.object as? DrawingTool {
                // SAFE CURSOR MANAGEMENT
                var popCount = 0
                while NSCursor.current != NSCursor.arrow && popCount < 10 {
                    NSCursor.pop()
                    popCount += 1
                }
                if NSCursor.current != NSCursor.arrow {
                    NSCursor.arrow.set()
                }
                
                document.currentTool = tool
                tool.cursor.push()
                print("🛠️ Menu: Switched to tool: \(tool.rawValue)")
            }
        }
        
        // Selection Commands - PROPERLY IMPLEMENTED
        NotificationCenter.default.addObserver(forName: .selectAll, object: nil, queue: .main) { _ in
            // Select all shapes and text objects
            for layerIndex in 0..<document.layers.count {
                let layer = document.layers[layerIndex]
                for shape in layer.shapes {
                    document.selectedShapeIDs.insert(shape.id)
                }
            }
            for textObj in document.textObjects {
                document.selectedTextIDs.insert(textObj.id)
            }
            print("📝 MENU: Selected all objects (\(document.selectedShapeIDs.count) shapes, \(document.selectedTextIDs.count) text)")
        }
        
        NotificationCenter.default.addObserver(forName: .deselectAll, object: nil, queue: .main) { _ in
            let shapeCount = document.selectedShapeIDs.count
            let textCount = document.selectedTextIDs.count
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs.removeAll()
            print("📝 MENU: Deselected all objects (\(shapeCount) shapes, \(textCount) text)")
        }
        
        // Object Commands - Arrange - PROPERLY IMPLEMENTED
        NotificationCenter.default.addObserver(forName: .bringToFront, object: nil, queue: .main) { _ in
            guard !document.selectedShapeIDs.isEmpty else { 
                print("📝 MENU: Bring to Front - No objects selected")
                return 
            }
            
            // Move selected shapes to end of current layer (front)
            let layerIndex = document.selectedLayerIndex ?? 0
            let currentLayer = document.layers[layerIndex]
            var shapesToMove: [VectorShape] = []
            
            // Collect selected shapes
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = currentLayer.shapes.firstIndex(where: { $0.id == shapeID }) {
                    shapesToMove.append(currentLayer.shapes[shapeIndex])
                }
            }
            
            // Remove from current positions
            document.layers[layerIndex].shapes.removeAll { shape in
                document.selectedShapeIDs.contains(shape.id)
            }
            
            // Add to front (end of array)
            document.layers[layerIndex].shapes.append(contentsOf: shapesToMove)
            print("📝 MENU: Brought \(shapesToMove.count) objects to front")
        }
        
        NotificationCenter.default.addObserver(forName: .bringForward, object: nil, queue: .main) { _ in
            guard !document.selectedShapeIDs.isEmpty else { 
                print("📝 MENU: Bring Forward - No objects selected")
                return 
            }
            
            // Move selected shapes forward one position
            let layerIndex = document.selectedLayerIndex ?? 0
            var layer = document.layers[layerIndex]
            for shapeID in document.selectedShapeIDs {
                if let currentIndex = layer.shapes.firstIndex(where: { $0.id == shapeID }) {
                    let newIndex = min(currentIndex + 1, layer.shapes.count - 1)
                    if newIndex != currentIndex {
                        let shape = layer.shapes.remove(at: currentIndex)
                        layer.shapes.insert(shape, at: newIndex)
                    }
                }
            }
            document.layers[layerIndex] = layer
            print("📝 MENU: Brought forward \(document.selectedShapeIDs.count) objects")
        }
        
        NotificationCenter.default.addObserver(forName: .sendBackward, object: nil, queue: .main) { _ in
            guard !document.selectedShapeIDs.isEmpty else { 
                print("📝 MENU: Send Backward - No objects selected")
                return 
            }
            
            // Move selected shapes backward one position
            let layerIndex = document.selectedLayerIndex ?? 0
            var layer = document.layers[layerIndex]
            for shapeID in document.selectedShapeIDs {
                if let currentIndex = layer.shapes.firstIndex(where: { $0.id == shapeID }) {
                    let newIndex = max(currentIndex - 1, 0)
                    if newIndex != currentIndex {
                        let shape = layer.shapes.remove(at: currentIndex)
                        layer.shapes.insert(shape, at: newIndex)
                    }
                }
            }
            document.layers[layerIndex] = layer
            print("📝 MENU: Sent backward \(document.selectedShapeIDs.count) objects")
        }
        
        NotificationCenter.default.addObserver(forName: .sendToBack, object: nil, queue: .main) { _ in
            guard !document.selectedShapeIDs.isEmpty else { 
                print("📝 MENU: Send to Back - No objects selected")
                return 
            }
            
            // Move selected shapes to beginning of current layer (back)
            let layerIndex = document.selectedLayerIndex ?? 0
            let currentLayer = document.layers[layerIndex]
            var shapesToMove: [VectorShape] = []
            
            // Collect selected shapes
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = currentLayer.shapes.firstIndex(where: { $0.id == shapeID }) {
                    shapesToMove.append(currentLayer.shapes[shapeIndex])
                }
            }
            
            // Remove from current positions
            document.layers[layerIndex].shapes.removeAll { shape in
                document.selectedShapeIDs.contains(shape.id)
            }
            
            // Insert at beginning (back)
            document.layers[layerIndex].shapes.insert(contentsOf: shapesToMove, at: 0)
            print("📝 MENU: Sent \(shapesToMove.count) objects to back")
        }
        
        // Object Commands - Lock/Hide
        NotificationCenter.default.addObserver(forName: .lockObjects, object: nil, queue: .main) { _ in
            document.lockSelectedObjects()
            print("📝 MENU: Lock Objects")
        }
        
        NotificationCenter.default.addObserver(forName: .unlockAll, object: nil, queue: .main) { _ in
            document.unlockAllObjects()
            print("📝 MENU: Unlock All")
        }
        
        NotificationCenter.default.addObserver(forName: .hideObjects, object: nil, queue: .main) { _ in
            document.hideSelectedObjects()
            print("📝 MENU: Hide Objects")
        }
        
        NotificationCenter.default.addObserver(forName: .showAll, object: nil, queue: .main) { _ in
            document.showAllObjects()
            print("📝 MENU: Show All")
        }
        
        // View Commands - Zoom - PROPERLY IMPLEMENTED
        NotificationCenter.default.addObserver(forName: .zoomIn, object: nil, queue: .main) { _ in
            let oldZoom = document.zoomLevel
            let newZoom = min(document.zoomLevel * 1.25, 50.0)
            document.zoomLevel = newZoom
            print("📝 MENU: Zoom In from \(String(format: "%.1f", oldZoom * 100))% to \(String(format: "%.1f", newZoom * 100))%")
        }
        
        NotificationCenter.default.addObserver(forName: .zoomOut, object: nil, queue: .main) { _ in
            let oldZoom = document.zoomLevel
            let newZoom = max(document.zoomLevel / 1.25, 0.01)
            document.zoomLevel = newZoom
            print("📝 MENU: Zoom Out from \(String(format: "%.1f", oldZoom * 100))% to \(String(format: "%.1f", newZoom * 100))%")
        }
        
        NotificationCenter.default.addObserver(forName: .fitToPage, object: nil, queue: .main) { _ in
            fitToPage()
            print("📝 MENU: Fit to Page")
        }
        
        NotificationCenter.default.addObserver(forName: .actualSize, object: nil, queue: .main) { _ in
            document.zoomLevel = 1.0
            print("📝 MENU: Actual Size (100%)")
        }
        
        // View Commands - View Mode - PROPERLY IMPLEMENTED
        NotificationCenter.default.addObserver(forName: .colorView, object: nil, queue: .main) { _ in
            document.viewMode = .color
            print("📝 MENU: Switched to Color View")
        }
        
        NotificationCenter.default.addObserver(forName: .keylineView, object: nil, queue: .main) { _ in
            document.viewMode = .keyline
            print("📝 MENU: Switched to Keyline View")
        }
        
        // View Commands - Show/Hide - PROPERLY IMPLEMENTED
        NotificationCenter.default.addObserver(forName: .toggleRulers, object: nil, queue: .main) { _ in
            document.showRulers.toggle()
            print("📝 MENU: Rulers \(document.showRulers ? "shown" : "hidden")")
        }
        
        NotificationCenter.default.addObserver(forName: .toggleGrid, object: nil, queue: .main) { _ in
            document.settings.showGrid.toggle()
            print("📝 MENU: Grid \(document.settings.showGrid ? "shown" : "hidden")")
        }
        
        NotificationCenter.default.addObserver(forName: .toggleSnapToGrid, object: nil, queue: .main) { _ in
            document.snapToGrid.toggle()
            print("📝 MENU: Snap to Grid \(document.snapToGrid ? "enabled" : "disabled")")
        }
        
        // Text Commands
        NotificationCenter.default.addObserver(forName: .createOutlines, object: nil, queue: .main) { _ in
            if !document.selectedTextIDs.isEmpty {
                document.convertSelectedTextToOutlines()
            }
        }
        
        // MARK: - Path Cleanup Commands (Professional Tools)
        
        // Clean up duplicate points in selected shapes
        NotificationCenter.default.addObserver(forName: .cleanupDuplicatePoints, object: nil, queue: .main) { _ in
            if !document.selectedShapeIDs.isEmpty {
                ProfessionalPathOperations.cleanupSelectedShapesDuplicates(document, tolerance: 5.0)
                print("🧹 MENU: Cleaned duplicate points in selected shapes")
            } else {
                ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 5.0)
                print("🧹 MENU: Cleaned duplicate points in all shapes")
            }
        }
        
        // Clean up duplicate points in all shapes
        NotificationCenter.default.addObserver(forName: .cleanupAllDuplicatePoints, object: nil, queue: .main) { _ in
            ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 5.0)
            print("🧹 MENU: Cleaned duplicate points in all document shapes")
        }
        
        // Test duplicate point merger (for verification)
        NotificationCenter.default.addObserver(forName: .testDuplicatePointMerger, object: nil, queue: .main) { _ in
            ProfessionalPathOperations.testDuplicatePointMerger()
            print("🧪 MENU: Ran duplicate point merger test")
        }
        
        // Window Commands - Panel Switching
        NotificationCenter.default.addObserver(forName: .showLayersPanel, object: nil, queue: .main) { _ in
            NotificationCenter.default.post(name: .switchToPanel, object: PanelTab.layers)
        }
        
        NotificationCenter.default.addObserver(forName: .showColorPanel, object: nil, queue: .main) { _ in
            NotificationCenter.default.post(name: .switchToPanel, object: PanelTab.color)
        }
        
        NotificationCenter.default.addObserver(forName: .showStrokeFillPanel, object: nil, queue: .main) { _ in
            NotificationCenter.default.post(name: .switchToPanel, object: PanelTab.properties)
        }
        
        // TYPOGRAPHY PANEL REMOVED
        
        NotificationCenter.default.addObserver(forName: .showPathOpsPanel, object: nil, queue: .main) { _ in
            NotificationCenter.default.post(name: .switchToPanel, object: PanelTab.pathOps)
        }
        
        // MARK: - Development Commands - CoreGraphics Path Operations Testing
        
        NotificationCenter.default.addObserver(forName: .showCoreGraphicsTest, object: nil, queue: .main) { _ in
            showingCoreGraphicsTest = true
        }
        
        NotificationCenter.default.addObserver(forName: .showPathOperationsComparison, object: nil, queue: .main) { _ in
            showingPathOperationsComparison = true
        }
        
        NotificationCenter.default.addObserver(forName: .runPathOperationsBenchmark, object: nil, queue: .main) { _ in
            runPathOperationsBenchmark()
        }
    }
    
    private func teardownMenuCommandObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Professional Zoom Functions (Adobe Illustrator Standards)
    
    private func fitToPage() {
        // Fit the entire page to the view (Adobe Illustrator standard)
        document.requestZoom(to: 0.0, mode: .fitToPage) // 0.0 signals to calculate fit zoom
        print("🔍 FIT TO PAGE: Calculated optimal zoom to fit page in view")
    }
    
    private func setupDocument() {
        // Document starts completely empty - no default shapes
        print("✅ Document setup complete - starting with empty canvas")
        
        // PROFESSIONAL STARTUP BEHAVIOR: Auto-fit to page on launch (like Adobe Illustrator)
        // Use a small delay to ensure the view is fully rendered before fitting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            document.requestZoom(to: 0.0, mode: .fitToPage) // 0.0 signals to calculate fit zoom
            print("🔍 AUTO-FIT TO PAGE: Applied on app launch for professional startup experience")
        }
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
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "Document.logos inkpen.io"
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
            
            print("✅ Successfully saved document to: \(url.path)")
            
            // Show success notification
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Document Saved"
                alert.informativeText = "Document saved successfully"
                alert.alertStyle = .informational
                alert.runModal()
            }
            
        } catch {
            print("❌ Save failed: \(error)")
            
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
        // PROFESSIONAL TEMPLATE SYSTEM: Use proper document template creation
        let newDoc = TemplateManager.shared.createBlankDocument()
        
        // Update the current document by copying all properties
        document.settings = newDoc.settings
        document.layers = newDoc.layers
        document.colorSwatches = newDoc.colorSwatches
        document.selectedLayerIndex = newDoc.selectedLayerIndex
        document.selectedShapeIDs = newDoc.selectedShapeIDs
        document.selectedTextIDs = newDoc.selectedTextIDs
        document.textObjects = newDoc.textObjects
        document.currentTool = newDoc.currentTool
        document.viewMode = newDoc.viewMode
        document.zoomLevel = newDoc.zoomLevel
        document.canvasOffset = newDoc.canvasOffset
        document.showRulers = newDoc.showRulers
        document.snapToGrid = newDoc.snapToGrid
        
        // Clear the current document URL (new document has no saved location)
        currentDocumentURL = nil
        
        print("✅ Created new document using TemplateManager - completely empty")
        
        // PROFESSIONAL NEW DOCUMENT BEHAVIOR: Auto-fit to page (like Adobe Illustrator)
        // Use a small delay to ensure the view is updated before fitting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            document.requestZoom(to: 0.0, mode: .fitToPage) // 0.0 signals to calculate fit zoom
            print("🔍 AUTO-FIT TO PAGE: Applied for new document creation")
        }
    }
    
    private func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json, UTType.svg]
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
                    } else {
                        // Import JSON file (default)
                        loadedDocument = try FileOperations.importFromJSON(url: url)
                    }
                    
                    // Replace current document with loaded one
                    await MainActor.run {
                        // Update the document by copying all properties
                        document.settings = loadedDocument.settings
                        document.layers = loadedDocument.layers
                        document.colorSwatches = loadedDocument.colorSwatches
                        document.selectedLayerIndex = loadedDocument.selectedLayerIndex
                        document.selectedShapeIDs = loadedDocument.selectedShapeIDs
                        document.selectedTextIDs = loadedDocument.selectedTextIDs
                        document.textObjects = loadedDocument.textObjects
                        document.currentTool = loadedDocument.currentTool
                        document.viewMode = loadedDocument.viewMode
                        document.zoomLevel = loadedDocument.zoomLevel
                        document.canvasOffset = loadedDocument.canvasOffset
                        document.showRulers = loadedDocument.showRulers
                        document.snapToGrid = loadedDocument.snapToGrid
                        
                        // Update current document URL
                        currentDocumentURL = url
                        
                        print("✅ Successfully opened \(fileExtension.uppercased()) document from: \(url.path)")
                        
                        // PROFESSIONAL DOCUMENT OPEN BEHAVIOR: Auto-fit to page (like Adobe Illustrator)
                        // Use a small delay to ensure the view is updated before fitting
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            document.requestZoom(to: 0.0, mode: .fitToPage) // 0.0 signals to calculate fit zoom
                            print("🔍 AUTO-FIT TO PAGE: Applied for opened document")
                        }
                        
                        // Show success notification
                        let alert = NSAlert()
                        alert.messageText = "Document Opened"
                        alert.informativeText = "\(fileExtension.uppercased()) document loaded successfully"
                        alert.alertStyle = .informational
                        alert.runModal()
                    }
                    
                } catch {
                    print("❌ Open failed: \(error)")
                    
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
                    // Add imported shapes to current layer
                    for shape in result.shapes {
                        document.addShape(shape)
                    }
                    print("✅ Import successful: \(result.shapes.count) shapes imported")
                    
                    // PROFESSIONAL IMPORT BEHAVIOR: Auto-fit to page after import (like Adobe Illustrator)
                    // Use a small delay to ensure the shapes are added before fitting
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        document.requestZoom(to: 0.0, mode: .fitToPage) // 0.0 signals to calculate fit zoom
                        print("🔍 AUTO-FIT TO PAGE: Applied after vector import")
                    }
                } else {
                    print("❌ Import failed: \(result.errors.map { $0.localizedDescription }.joined(separator: ", "))")
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
                
                print("✅ Successfully exported DWF to: \(url.path)")
                
                // Show success notification
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "DWF Export Successful"
                    alert.informativeText = "File exported to \(url.lastPathComponent)\nScale: \(options.scale.description)\nUnits: \(options.targetUnits.rawValue)"
                    alert.alertStyle = .informational
                    alert.runModal()
                }
                
            } catch {
                print("❌ DWF export failed: \(error)")
                
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
        print("🚀 STARTING PASTEBOARD DIAGNOSTICS FROM UI")
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
        print("🚀 RUNNING PATH OPERATIONS BENCHMARK")
        print("Comparing ClipperPath vs CoreGraphics performance...")
        
        // Create test paths
        let testCases = [
            ("Simple Circles", createTestCircles()),
            ("Complex Curves", createTestComplexPaths()),
            ("Many Points", createTestManyPointPaths())
        ]
        
        for (name, paths) in testCases {
            print("\n📊 Testing: \(name)")
            benchmarkPathOperations(name: name, pathA: paths.0, pathB: paths.1)
        }
        
        print("\n✅ BENCHMARK COMPLETE")
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
        
        // Benchmark ClipperPath (convert to ClipperPath first)
        let clipperPathA = pathA.toClipperPath()
        let clipperPathB = pathB.toClipperPath()
        
        let clipperStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            let _ = clipperPathA.union(clipperPathB)
            let _ = clipperPathA.intersection(clipperPathB)
            let _ = clipperPathA.difference(clipperPathB)
        }
        let clipperTime = CFAbsoluteTimeGetCurrent() - clipperStart
        
        print("  CoreGraphics: \(String(format: "%.4f", coreGraphicsTime))s")
        print("  ClipperPath:  \(String(format: "%.4f", clipperTime))s")
        print("  Speedup: \(String(format: "%.2f", clipperTime / coreGraphicsTime))x")
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
                
                print("✅ Successfully exported DWG to: \(url.path)")
                
                // Show success notification
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "DWG Export Successful"
                    alert.informativeText = "File exported to \(url.lastPathComponent)\nScale: \(options.scale.description)\nUnits: \(options.targetUnits.rawValue)\nVersion: \(options.dwgVersion.displayName)"
                    alert.alertStyle = .informational
                    alert.runModal()
                }
                
            } catch {
                print("❌ DWG export failed: \(error)")
                
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
                        print("🎯 Closed selected path for shape \(shape.name)")
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
            
            // Document Settings
            Button {
                showingDocumentSettings = true
            } label: {
                Image(systemName: "gear")
            }
            .help("Document Settings")
            
            // Color Picker
            Button {
                showingColorPicker = true
            } label: {
                Image(systemName: "paintpalette")
            }
            .help("Color Picker")
            
            // Import Vector Graphics
            Button {
                showingImportDialog = true
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("Import SVG, PDF, Adobe Illustrator (.ai), EPS, PostScript (.ps), and DWF files")
            
            // Debug: Run Pasteboard Diagnostics
            Button {
                onRunDiagnostics()
            } label: {
                Image(systemName: "wrench.and.screwdriver")
            }
            .help("Run Pasteboard Diagnostics (Debug)")
            
            if showingImportProgress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.8)
            }
        }
        
        ToolbarItem(placement: .status) {
            Text("Zoom: \(Int(document.zoomLevel * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Professional Zoom Functions (Adobe Illustrator Standards)
    
    private func onZoomIn() {
        // Zoom in by 25% (Adobe Illustrator standard)
        let newZoom = min(10.0, document.zoomLevel * 1.25)
        document.requestZoom(to: CGFloat(newZoom), mode: .zoomIn)
        print("🔍 ZOOM IN: \(String(format: "%.1f", document.zoomLevel * 100))% → \(String(format: "%.1f", newZoom * 100))%")
    }
    
    private func onZoomOut() {
        // Zoom out by 25% (Adobe Illustrator standard)
        let newZoom = max(0.1, document.zoomLevel / 1.25)
        document.requestZoom(to: CGFloat(newZoom), mode: .zoomOut)
        print("🔍 ZOOM OUT: \(String(format: "%.1f", document.zoomLevel * 100))% → \(String(format: "%.1f", newZoom * 100))%")
    }
    
    private func onFitToPage() {
        // Fit the entire page to the view (Adobe Illustrator standard)
        document.requestZoom(to: 0.0, mode: .fitToPage) // 0.0 signals to calculate fit zoom
        print("🔍 FIT TO PAGE: Calculated optimal zoom to fit page in view")
    }
    
    private func onActualSize() {
        // Set to 100% zoom (Adobe Illustrator standard)
        document.requestZoom(to: 1.0, mode: .actualSize)
        print("🔍 ACTUAL SIZE: Set to 100% zoom")
    }
    
    // MARK: - Professional Object Management Functions (Adobe Illustrator Standards)
    
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
        print("⬆️⬆️ Brought to front \(document.selectedShapeIDs.count) objects")
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
        print("⬆️ Brought forward \(document.selectedShapeIDs.count) objects")
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
        print("⬇️ Sent backward \(document.selectedShapeIDs.count) objects")
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
        print("⬇️⬇️ Sent to back \(document.selectedShapeIDs.count) objects")
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
        
        print("🔒 Locked selected objects")
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
        
        print("🔓 Unlocked all objects")
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
        
        print("👁️‍🗨️ Hidden selected objects")
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
        
        print("👁️ Showed all objects")
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
                }
            }
            
            Spacer()
            
            // Selection Info
            if document.selectedShapeIDs.isEmpty {
                Text("No selection")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(document.selectedShapeIDs.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
}

struct DocumentSettingsView: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Document Size")) {
                    HStack {
                        Text("Width:")
                        TextField("Width", value: $document.settings.width, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: document.settings.width) {
                                document.onSettingsChanged()
                            }
                    }
                    
                    HStack {
                        Text("Height:")
                        TextField("Height", value: $document.settings.height, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: document.settings.height) {
                                document.onSettingsChanged()
                            }
                    }
                    
                    Picker("Unit", selection: $document.settings.unit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .onChange(of: document.settings.unit) {
                        document.onSettingsChanged()
                    }
                }
                
                Section(header: Text("Color")) {
                    Picker("Color Mode", selection: $document.settings.colorMode) {
                        ForEach(ColorMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                
                Section(header: Text("Grid")) {
                    Toggle("Show Grid", isOn: $document.settings.showGrid)
                    
                    HStack {
                        Text("Grid Spacing:")
                        TextField("Spacing", value: $document.settings.gridSpacing, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Toggle("Snap to Grid", isOn: $document.settings.snapToGrid)
                }
                
                Section(header: Text("View")) {
                    Toggle("Show Rulers", isOn: $document.settings.showRulers)
                    
                    HStack {
                        Text("Resolution:")
                        TextField("DPI", value: $document.settings.resolution, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("DPI")
                    }
                }
            }
            .navigationTitle("Document Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
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
                
                print("✅ Successfully exported document as \(exportFormat.rawValue) to: \(url.path)")
                
                // Show success notification
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Export Successful"
                    alert.informativeText = "Document exported as \(exportFormat.rawValue)"
                    alert.alertStyle = .informational
                    alert.runModal()
                }
                
            } catch {
                print("❌ Export failed: \(error)")
                
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
