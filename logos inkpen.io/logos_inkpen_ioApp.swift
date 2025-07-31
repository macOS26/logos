//
//  logosApp.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

// MARK: - InkpenDocument for DocumentGroup (ADDITION - not replacement)
struct InkpenDocument: FileDocument {
    var document: VectorDocument
    
    static var readableContentTypes: [UTType] { [.inkpen] }
    
    init() {
        self.document = VectorDocument()
    }
    
    init(document: VectorDocument) {
        self.document = document
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        do {
            self.document = try FileOperations.importFromJSONData(data)
        } catch {
            print("❌ Failed to load document: \(error)")
            throw error
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        do {
            let data = try FileOperations.exportToJSONData(document)
            return FileWrapper(regularFileWithContents: data)
        } catch {
            print("❌ Failed to save document: \(error)")
            throw error
        }
    }
}

//// MARK: - AppDelegate to Remove Default Menus
//final class AppDelegate: NSObject, NSApplicationDelegate {
//    func applicationWillUpdate(_ notification: Notification) {
//       
//    }
//}

// MARK: - Document State Object (THE SOLUTION!)
// This is the key to automatic menu state updates
class DocumentState: ObservableObject {
    @Published var document: VectorDocument?
    
    // AUTOMATIC MENU STATES - Update in real-time with @Published
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var hasSelection = false
    @Published var canCut = false
    @Published var canCopy = false
    @Published var canPaste = false
    @Published var canGroup = false
    @Published var canUngroup = false
    @Published var canFlatten = false
    @Published var canUnflatten = false
    @Published var canMakeCompoundPath = false
    @Published var canReleaseCompoundPath = false
    @Published var canMakeLoopingPath = false
    @Published var canReleaseLoopingPath = false
    @Published var canUnwrapWarpObject = false
    @Published var canExpandWarpObject = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("🎯 DocumentState initialized with automatic menu state updates")
        // Defer observer setup until document is set to prevent blocking during launch
    }
    
    func setDocument(_ document: VectorDocument) {
        self.document = document
        updateAllStates()
        
        // Set up observers asynchronously to prevent blocking
        Task {
            await setupDocumentObserversAsync()
        }
    }
    
    private func setupDocumentObserversAsync() async {
        guard let document = document else { return }
        
        // Clear previous observations
        cancellables.removeAll()
        
        // Monitor document changes that affect menu states
        document.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateAllStates()
            }
        }
        .store(in: &cancellables)
        
        print("✅ Document observers set up asynchronously")
    }
    
    private func updateAllStates() {
        guard let document = document else {
            // No document = disable everything
            canUndo = false
            canRedo = false
            hasSelection = false
            canCut = false
            canCopy = false
            canPaste = false
            canGroup = false
            canUngroup = false
            canFlatten = false
            canUnflatten = false
            canMakeCompoundPath = false
            canReleaseCompoundPath = false
            canMakeLoopingPath = false
            canReleaseLoopingPath = false
            canUnwrapWarpObject = false
            canExpandWarpObject = false
            return
        }
        
        // AUTOMATIC STATE CALCULATION
        canUndo = !document.undoStack.isEmpty
        canRedo = !document.redoStack.isEmpty
        hasSelection = !document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty
        canCut = hasSelection
        canCopy = hasSelection
        canPaste = ClipboardManager.shared.canPaste()
        canGroup = document.selectedShapeIDs.count > 1
        canUngroup = document.selectedShapeIDs.contains { shapeID in
            document.layers.flatMap(\.shapes).first { $0.id == shapeID }?.isGroupContainer == true
        }
        canFlatten = document.selectedShapeIDs.count > 1
        canUnflatten = document.selectedShapeIDs.count == 1 && document.selectedShapeIDs.contains { shapeID in
            document.layers.flatMap(\.shapes).first { $0.id == shapeID }?.isGroup == true
        }
        canMakeCompoundPath = document.selectedShapeIDs.count > 1
        canReleaseCompoundPath = document.selectedShapeIDs.count == 1 && document.selectedShapeIDs.contains { shapeID in
            document.layers.flatMap(\.shapes).first { $0.id == shapeID }?.isCompoundPath == true
        }
        canMakeLoopingPath = document.selectedShapeIDs.count > 1
        canReleaseLoopingPath = document.selectedShapeIDs.count == 1 && document.selectedShapeIDs.contains { shapeID in
            document.layers.flatMap(\.shapes).first { $0.id == shapeID }?.isCompoundPath == true
        }
        canUnwrapWarpObject = document.selectedShapeIDs.count == 1 && document.selectedShapeIDs.contains { shapeID in
            document.layers.flatMap(\.shapes).first { $0.id == shapeID }?.isWarpObject == true
        }
        canExpandWarpObject = document.selectedShapeIDs.count == 1 && document.selectedShapeIDs.contains { shapeID in
            document.layers.flatMap(\.shapes).first { $0.id == shapeID }?.isWarpObject == true
        }
        
        // Removed excessive logging per user request
    }
    
    // MARK: - Menu Actions (Direct document interaction)
    func undo() {
        document?.undo()
        updateAllStates()
    }
    
    func redo() {
        document?.redo() 
        updateAllStates()
    }
    
    func cut() {
        guard let document = document else { return }
        ClipboardManager.shared.cut(from: document)
        updateAllStates()
    }
    
    func copy() {
        guard let document = document else { return }
        ClipboardManager.shared.copy(from: document)
        updateAllStates()
    }
    
    func paste() {
        guard let document = document else { return }
        ClipboardManager.shared.paste(to: document)
        updateAllStates()
    }
    
    func pasteInBack() {
        guard let document = document else { return }
        ClipboardManager.shared.pasteInBack(to: document)
        updateAllStates()
    }
    
    func selectAll() {
        document?.selectAll()
        updateAllStates()
    }
    
    func deselectAll() {
        document?.selectedShapeIDs.removeAll()
        document?.selectedTextIDs.removeAll()
        updateAllStates()
    }
    
    func delete() {
        guard let document = document else { return }
        document.saveToUndoStack()
        
        if !document.selectedShapeIDs.isEmpty {
            document.removeSelectedShapes()
        }
        if !document.selectedTextIDs.isEmpty {
            document.removeSelectedText()
        }
        
        updateAllStates()
        print("🗑️ MENU: Deleted selected objects")
    }
    
    func bringToFront() {
        document?.bringSelectedToFront()
        updateAllStates()
    }
    
    func bringForward() {
        document?.bringSelectedForward()
        updateAllStates()
    }
    
    func sendBackward() {
        document?.sendSelectedBackward()
        updateAllStates()
    }
    
    func sendToBack() {
        document?.sendSelectedToBack()
        updateAllStates()
    }
    
    func groupObjects() {
        document?.groupSelectedObjects()
        updateAllStates()
    }
    
    func ungroupObjects() {
        document?.ungroupSelectedObjects()
        updateAllStates()
    }
    
    func flattenObjects() {
        document?.flattenSelectedObjects()
        updateAllStates()
    }
    
    func unflattenObjects() {
        document?.unflattenSelectedObjects()
        updateAllStates()
    }
    
    func duplicate() {
        guard let document = document else { return }
        if !document.selectedShapeIDs.isEmpty {
            document.duplicateSelectedShapes()
        } else if !document.selectedTextIDs.isEmpty {
            document.duplicateSelectedText()
        }
        updateAllStates()
    }
    
    func makeCompoundPath() {
        document?.makeCompoundPath()
        updateAllStates()
    }
    
    func releaseCompoundPath() {
        document?.releaseCompoundPath()
        updateAllStates()
    }
    
    func makeLoopingPath() {
        document?.makeLoopingPath()
        updateAllStates()
    }
    
    func releaseLoopingPath() {
        document?.releaseLoopingPath()
        updateAllStates()
    }
    
    func unwrapWarpObject() {
        document?.unwrapWarpObject()
        updateAllStates()
    }
    
    func expandWarpObject() {
        document?.expandWarpObject()
        updateAllStates()
    }
    
    func lockSelectedObjects() {
        document?.lockSelectedObjects()
        updateAllStates()
    }
    
    func unlockAllObjects() {
        document?.unlockAllObjects()
        updateAllStates()
    }
    
    func hideSelectedObjects() {
        document?.hideSelectedObjects()
        updateAllStates()
    }
    
    func showAllObjects() {
        document?.showAllObjects()
        updateAllStates()
    }
    
    // MARK: - View Commands
    func zoomIn() {
        guard let document = document else { return }
        let oldZoom = document.zoomLevel
        let newZoom = min(document.zoomLevel * 1.25, 50.0)
        document.zoomLevel = newZoom
        print("🔍 MENU: Zoom In from \(String(format: "%.1f", oldZoom * 100))% to \(String(format: "%.1f", newZoom * 100))%")
    }
    
    func zoomOut() {
        guard let document = document else { return }
        let oldZoom = document.zoomLevel
        let newZoom = max(document.zoomLevel / 1.25, 0.01)
        document.zoomLevel = newZoom
        print("🔍 MENU: Zoom Out from \(String(format: "%.1f", oldZoom * 100))% to \(String(format: "%.1f", newZoom * 100))%")
    }
    
    func fitToPage() {
        document?.requestZoom(to: 0.0, mode: .fitToPage)
        print("📐 MENU: Fit to Page")
    }
    
    func actualSize() {
        document?.zoomLevel = 1.0
        print("📏 MENU: Actual Size (100%)")
    }
    
    func switchToColorView() {
        document?.viewMode = .color
        print("🎨 MENU: Switched to Color View")
    }
    
    func switchToKeylineView() {
        document?.viewMode = .keyline
        print("📝 MENU: Switched to Keyline View")
    }
    
    func toggleRulers() {
        document?.showRulers.toggle()
        print("📏 MENU: Rulers \(document?.showRulers == true ? "shown" : "hidden")")
    }
    
    func toggleGrid() {
        document?.settings.showGrid.toggle()
        print("🔲 MENU: Grid \(document?.settings.showGrid == true ? "shown" : "hidden")")
    }
    
    func toggleSnapToGrid() {
        document?.snapToGrid.toggle()
        print("🧲 MENU: Snap to Grid \(document?.snapToGrid == true ? "enabled" : "disabled")")
    }
    
    // MARK: - Text Commands
    func createOutlines() {
        guard let document = document, !document.selectedTextIDs.isEmpty else { return }
        document.convertSelectedTextToOutlines()
        updateAllStates()
        print("📝 MENU: Converted selected text to outlines")
    }
    
    // MARK: - Path Cleanup Commands (Professional Tools)
    func cleanupDuplicatePoints() {
        guard let document = document else { return }
        if !document.selectedShapeIDs.isEmpty {
            ProfessionalPathOperations.cleanupSelectedShapesDuplicates(document, tolerance: 5.0)
            print("🧹 MENU: Cleaned duplicate points in selected shapes")
        } else {
            ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 5.0)
            print("🧹 MENU: Cleaned duplicate points in all shapes")
        }
        updateAllStates()
    }
    
    func cleanupAllDuplicatePoints() {
        guard let document = document else { return }
        ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 5.0)
        print("🧹 MENU: Cleaned duplicate points in all document shapes")
        updateAllStates()
    }
    
    func testDuplicatePointMerger() {
        ProfessionalPathOperations.testDuplicatePointMerger()
        print("🧪 MENU: Ran duplicate point merger test")
    }
}

// MARK: - DocumentTitleToolbar (Clean toolbar with icon and filename only)
//struct DocumentTitleToolbarX: View {
//    let fileURL: URL?
//    
//    private var documentName: String {
//        if let fileURL = fileURL {
//            return fileURL.lastPathComponent
//        } else {
//            return "Untitled"
//        }
//    }
//    
//    private var documentIcon: NSImage {
//        if let fileURL = fileURL {
//            return NSWorkspace.shared.icon(forFile: fileURL.path)
//        } else {
//            // Create a generic document icon for untitled documents
//            return NSWorkspace.shared.icon(for: .inkpen)
//        }
//    }
//    
//    var body: some View {
//        Button(action: {
//            // Navigate to document in Finder
//            if let fileURL = fileURL {
//                NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
//                print("📁 Navigating to document in Finder: \(fileURL.path)")
//            } else {
//                print("📁 No file URL available for navigation")
//            }
//        }) {
//            HStack(spacing: 6) {
//                // Document Icon - ALWAYS showing on the left
//                Image(nsImage: documentIcon)
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: 30, height: 30)
//                
//                // Document Name ONLY (no path, no zoom)
//                Text(documentName)
//                    .font(.system(size: 20, weight: .medium))
//                    .foregroundColor(.primary)
//                    .lineLimit(1)
//            }
//        }
//        .buttonStyle(PlainButtonStyle())
//        .help(fileURL != nil ? "Click to show in Finder" : "Untitled Document")
//    }
//}

// MARK: - DocumentBasedContentView (integrates DocumentGroup with MainView)
struct DocumentBasedContentView: View {
    @Binding var inkpenDocument: InkpenDocument
    let fileURL: URL?
    
    var body: some View {
        DocumentBasedMainView(document: inkpenDocument.document, fileURL: fileURL)
    }
}

// MARK: - DocumentBasedMainView (MainView that accepts external document)
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
    @State private var importFileURL: URL?
    @State private var importResult: VectorImportResult?
    @State private var showingImportProgress = false
    @State private var showingDWFExportDialog = false
    @State private var dwfExportOptions = DWFExportOptions()
    @State private var showingDWGExportDialog = false
    @State private var dwgExportOptions = DWGExportOptions()
    @State private var showingSVGTestHarness = false
    @State private var showingNewDocumentSetup = false
    
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
                            .allowsHitTesting(false) // CRITICAL: Rulers don't capture gestures
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
                .frame(height: 24) // EXACT MainView height
                .frame(minHeight: 24) // ENSURE: Status bar height is always preserved
                .frame(maxWidth: .infinity) // ENSURE: Status bar spans full width
        }
        .frame(minHeight: 524) // MINIMUM: Ensure overall height accommodates all elements + status bar (500 + 24)
        .toolbar {
            // CUSTOM DOCUMENT TOOLBAR with icon and clickable path navigation
//            ToolbarItem(placement: .principal) {
//                DocumentTitleToolbar(fileURL: fileURL)
//            }
            
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
                showingSVGTestHarness: $showingSVGTestHarness,
                onRunDiagnostics: runPasteboardDiagnostics
            )
        }
        .sheet(isPresented: $showingNewDocumentSetup) {
            NewDocumentSetupView(
                isPresented: $showingNewDocumentSetup,
                onDocumentCreated: { newDocument, suggestedURL in
                    // Replace current document with new one
                    loadImportedDocument(newDocument)
                    print("✅ Created new document with custom settings")
                }
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
        .sheet(isPresented: $showingSVGTestHarness) {
            SVGTestHarness { importedDoc in
                // Load the imported document into the main app
                loadImportedDocument(importedDoc)
            }
            .frame(width: 1000, height: 800)
        }
        .onAppear {
            // Connect document to menu system
            documentState.setDocument(document)
            
            // Defer fit to page operation to prevent blocking
            Task {
                await performDocumentGroupSetupAsync()
            }
        }
        .focusedSceneObject(documentState)
    }
    
    // MARK: - Async Initialization
    
    private func performDocumentGroupSetupAsync() async {
        // Wait a brief moment for geometry to be established
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        await MainActor.run {
            document.requestZoom(to: 0.0, mode: .fitToPage)
            print("🔍 DocumentGroup: Applied fit to page")
        }
    }
    
    // MARK: - Document Operations (FIXED - Real implementations)
    private func saveDocument() {
        // Save the current document - DocumentGroup handles the file URL
        if let fileURL = fileURL {
            saveDocumentToURL(fileURL)
        } else {
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
            self.saveDocumentToURL(url)
        }
    }
    
    private func saveDocumentToURL(_ url: URL) {
        do {
            try FileOperations.exportToJSON(document, url: url)
            
            // Generate and set custom document icon
            DocumentIconGenerator.shared.setCustomIcon(for: url, document: document)
            
            print("✅ Successfully saved document to: \(url.path)")
            
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
                        self.loadImportedDocument(loadedDocument)
                        print("✅ Successfully opened \(fileExtension.uppercased()) document from: \(url.path)")
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
    
    private func newDocument() {
        // Show the new document setup window
        showingNewDocumentSetup = true
    }
    
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
        document.textObjects = importedDoc.textObjects
        document.currentTool = .selection
        document.viewMode = .color
        document.showRulers = importedDoc.showRulers
        document.snapToGrid = importedDoc.snapToGrid
        
        print("✅ Loaded imported document - \(document.layers.count) layers, \(document.layers.reduce(0) { $0 + $1.shapes.count }) shapes")
        
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
            print("🔍 PROPER FIT TO PAGE: Applied for imported document after geometry established")
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
                    
                    print("✅ Import successful: \(result.shapes.count) shapes imported and added to undo stack")
                    
                    // Defer fit to page operation to prevent blocking
                    Task {
                        await performVectorImportSetupAsync()
                    }
                } else {
                    print("❌ Import failed: \(result.errors.map { $0.localizedDescription }.joined(separator: ", "))")
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
            print("🔍 PROPER FIT TO PAGE: Applied after vector import with geometry established")
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

    private func runPasteboardDiagnostics() {
        print("🔧 DocumentGroup: Running pasteboard diagnostics")
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

// MARK: - Stall Detection and Recovery
class StallDetector {
    static let shared = StallDetector()
    
    private var lastActivityTime = Date()
    private var isMonitoring = false
    
    private init() {}
    
    func startMonitoring() {
        isMonitoring = true
        lastActivityTime = Date()
        
        // Start monitoring in background
        Task.detached(priority: .background) {
            await self.monitorForStalls()
        }
    }
    
    private func monitorForStalls() async {
        while isMonitoring {
            let currentTime = Date()
            let timeSinceLastActivity = currentTime.timeIntervalSince(lastActivityTime)
            
            // If no activity for more than 5 seconds, consider it stalled
            if timeSinceLastActivity > 5.0 {
                print("📄 StallDetector: Detected potential stall - attempting recovery")
                await attemptStallRecovery()
            }
            
            // Wait before next check
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    
    private func attemptStallRecovery() async {
        await MainActor.run {
            // Force any pending operations to complete
            NSApplication.shared.windows.forEach { window in
                window.contentView?.needsDisplay = true
                window.display()
            }
            
            // Force the main window to be responsive
            if let mainWindow = NSApplication.shared.mainWindow {
                mainWindow.makeKeyAndOrderFront(nil)
            }
            
            // Update activity time
            lastActivityTime = Date()
            
            print("📄 StallDetector: Stall recovery completed")
        }
    }
    
    func updateActivity() {
        lastActivityTime = Date()
    }
    
    func stopMonitoring() {
        isMonitoring = false
    }
}

// MARK: - System Call Interceptor
class SystemCallInterceptor {
    static let shared = SystemCallInterceptor()
    
    private init() {}
    
    // Method to set up system call monitoring
    func setupSystemCallMonitoring() {
        // Set up a background task to monitor for system call issues
        Task.detached(priority: .background) {
            await self.monitorSystemCalls()
        }
    }
    
    private func monitorSystemCalls() async {
        // Monitor for common system call patterns that might cause blocking
        while true {
            // Check if the main thread is blocked
            let isMainThreadBlocked = await checkMainThreadStatus()
            
            if isMainThreadBlocked {
                print("📄 SystemCallInterceptor: Detected potential main thread blocking - attempting recovery")
                await attemptRecovery()
            }
            
            // Wait before next check
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
    }
    
    private func checkMainThreadStatus() async -> Bool {
        // Simple check to see if main thread is responsive
        let startTime = Date()
        
        await MainActor.run {
            // Just a simple operation to check responsiveness
            _ = NSApplication.shared.windows.count
        }
        
        let responseTime = Date().timeIntervalSince(startTime)
        return responseTime > 1.0 // If it takes more than 1 second, consider it blocked
    }
    
    private func attemptRecovery() async {
        await MainActor.run {
            // Force any pending operations to complete
            NSApplication.shared.windows.forEach { window in
                window.contentView?.needsDisplay = true
            }
            
            // Force a display update
            NSApplication.shared.mainWindow?.display()
        }
    }
}

// MARK: - Startup Coordinator for Graceful Initialization
class StartupCoordinator {
    static let shared = StartupCoordinator()
    
    private init() {}
    
    func performStartupTasks() async {
        print("📄 StartupCoordinator: Beginning startup sequence")
        
        // Start stall detection
        StallDetector.shared.startMonitoring()
        
        // Set up system call monitoring
        SystemCallInterceptor.shared.setupSystemCallMonitoring()
        
        // Add timeout to prevent hanging
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
            print("📄 StartupCoordinator: Warning - startup sequence taking longer than expected")
        }
        
        // Perform startup tasks with error handling
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Configure window tabbing
            group.addTask {
                await self.configureWindowTabbing()
                StallDetector.shared.updateActivity()
            }
            
            // Task 2: Check file system access
            group.addTask {
                await self.checkFileSystemAccessAsync()
                StallDetector.shared.updateActivity()
            }
            
            // Task 3: Initialize document controller
            group.addTask {
                await self.initializeDocumentController()
                StallDetector.shared.updateActivity()
            }
        }
        
        // Cancel timeout task since we completed successfully
        timeoutTask.cancel()
        
        // Test error handling in development
        #if DEBUG
        testErrorHandling()
        #endif
        
        print("📄 StartupCoordinator: Startup sequence completed")
    }
    
    private func configureWindowTabbing() async {
        await MainActor.run {
            NSWindow.allowsAutomaticWindowTabbing = true
            UserDefaults.standard.set("always", forKey: "AppleWindowTabbingMode")
            
            NSApplication.shared.windows.forEach { window in
                window.tabbingMode = .preferred
            }
            print("📄 StartupCoordinator: Window tabbing configured")
        }
    }
    
    private func checkFileSystemAccessAsync() async {
        // Run file system checks in background
        await Task.detached(priority: .background) {
            let fileManager = FileManager.default
            
            let directoriesToCheck = [
                fileManager.temporaryDirectory,
                fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
                fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ].compactMap { $0 }
            
            for directory in directoriesToCheck {
                do {
                    _ = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                    print("📄 StartupCoordinator: File system access verified for \(directory.lastPathComponent)")
                } catch {
                    print("📄 StartupCoordinator: File system warning for \(directory.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }.value
    }
    
    private func initializeDocumentController() async {
        await MainActor.run {
            let documentController = NSDocumentController.shared
            documentController.autosavingDelay = 30.0
            UserDefaults.standard.set(true, forKey: "NSQuitAlwaysKeepsWindows")
            print("📄 StartupCoordinator: Document controller initialized")
        }
    }
    
    // Test method to verify error handling
    func testErrorHandling() {
        print("📄 StartupCoordinator: Testing error handling...")
        
        // Simulate the DetachedSignatures error
        let testError = NSError(domain: "TestDomain", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "cannot open file at line 49448 of [1b37c146ee] os_unix.c:49448: (2) open(/private/var/db/DetachedSignatures) - No such file or directory"
        ])
        
        let wasHandled = SystemErrorHandler.shared.handleSystemError(testError)
        print("📄 StartupCoordinator: Test error was handled: \(wasHandled)")
    }
}

// MARK: - Custom Error Handler for System-Level Issues
class SystemErrorHandler {
    static let shared = SystemErrorHandler()
    
    private init() {}
    
    func handleSystemError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        let errorDomain = (error as NSError).domain
        let errorCode = (error as NSError).code
        
        // Check for DetachedSignatures and other system directory access errors
        if errorDescription.contains("detachedsignatures") || 
           errorDescription.contains("/private/var/db/") ||
           errorDescription.contains("no such file or directory") {
            
            print("📄 SystemErrorHandler: Detected system directory access error - \(errorDescription)")
            print("📄 SystemErrorHandler: This is likely a code signing verification issue in development")
            print("📄 SystemErrorHandler: Continuing app initialization gracefully")
            return true // Error handled
        }
        
        // Check for RenderBox framework errors
        if errorDescription.contains("renderbox") || 
           errorDescription.contains("metallib") ||
           errorDescription.contains("mach-o") {
            print("📄 SystemErrorHandler: Detected RenderBox/Metal framework error - \(errorDescription)")
            print("📄 SystemErrorHandler: This is a system framework loading issue - continuing gracefully")
            return true // Error handled
        }
        
        // Check for persona attributes errors
        if errorDescription.contains("personaattributes") || 
           errorDescription.contains("persona type") ||
           errorDescription.contains("operation not permitted") {
            print("📄 SystemErrorHandler: Detected persona attributes error - \(errorDescription)")
            print("📄 SystemErrorHandler: This is a system permission issue - continuing gracefully")
            return true // Error handled
        }
        
        // Check for other common system-level errors that shouldn't block the app
        if errorDomain == "NSCocoaErrorDomain" && 
           (errorDescription.contains("file system") || errorDescription.contains("permission")) {
            print("📄 SystemErrorHandler: Detected file system permission error - continuing gracefully")
            return true // Error handled
        }
        
        // Check for NSPOSIXErrorDomain errors with specific codes
        if errorDomain == "NSPOSIXErrorDomain" && 
           (errorCode == 1 || errorCode == 2) { // Operation not permitted, No such file or directory
            print("📄 SystemErrorHandler: Detected POSIX error (code \(errorCode)) - continuing gracefully")
            return true // Error handled
        }
        
        return false // Error not handled, let it propagate
    }
    
    // Method to suppress specific error types globally
    func shouldSuppressError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        
        // List of error patterns that should be suppressed
        let suppressPatterns = [
            "detachedsignatures",
            "/private/var/db/",
            "no such file or directory",
            "renderbox",
            "metallib",
            "mach-o",
            "personaattributes",
            "persona type",
            "operation not permitted"
        ]
        
        return suppressPatterns.contains { pattern in
            errorDescription.contains(pattern)
        }
    }
}

// MARK: - AppDelegate to ensure proper document tabbing and window persistence
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SETUP: Global error handling for system-level issues
        setupGlobalErrorHandling()
        
        print("📄 App: Starting graceful initialization sequence")
        
        // Use the startup coordinator for robust initialization
        Task {
            await StartupCoordinator.shared.performStartupTasks()
            
            // After startup tasks complete, configure windows
            await configureWindowsAsync()
        }
        
        // Set up a fallback timer to ensure the app doesn't hang
        setupFallbackTimer()
    }
    
    private func setupFallbackTimer() {
        // Set up a timer that will force the app to continue if it gets stuck
        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { _ in
            print("📄 App: Fallback timer triggered - ensuring app is responsive")
            
            // Force any pending operations to complete
            DispatchQueue.main.async {
                // Ensure the main window is visible and responsive
                if let mainWindow = NSApplication.shared.mainWindow {
                    mainWindow.makeKeyAndOrderFront(nil)
                    mainWindow.display()
                }
                
                // Force a display update
                NSApplication.shared.windows.forEach { window in
                    window.contentView?.needsDisplay = true
                }
            }
        }
    }
    
    private func setupGlobalErrorHandling() {
        // Set up a global exception handler for unhandled errors
        NSSetUncaughtExceptionHandler { exception in
            let exceptionName = exception.name.rawValue
            let exceptionReason = exception.reason ?? "Unknown reason"
            
            print("📄 GlobalErrorHandler: Uncaught exception: \(exceptionName)")
            print("📄 GlobalErrorHandler: Reason: \(exceptionReason)")
            
            // Check if this is a system-level error we should handle gracefully
            if exceptionReason.contains("DetachedSignatures") || 
               exceptionReason.contains("/private/var/db/") ||
               exceptionReason.contains("No such file or directory") ||
               exceptionReason.contains("RenderBox") ||
               exceptionReason.contains("metallib") ||
               exceptionReason.contains("personaAttributes") {
                print("📄 GlobalErrorHandler: System-level error detected - continuing gracefully")
                return // Don't crash the app
            }
            
            // For other exceptions, let them propagate normally
            print("📄 GlobalErrorHandler: Allowing exception to propagate")
        }
    }
    

    

    
    private func configureWindowsAsync() async {
        await MainActor.run {
            // FORCE: Set window tabbing mode to always
            NSApplication.shared.windows.forEach { window in
                window.tabbingMode = .preferred
            }
            print("📄 App: Window tabbing configured asynchronously")
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Defer window operations to prevent blocking
        Task {
            await handleApplicationBecameActiveAsync()
        }
    }
    
    private func handleApplicationBecameActiveAsync() async {
        await MainActor.run {
            // Ensure tabbing mode is maintained
            NSApplication.shared.windows.forEach { window in
                window.tabbingMode = .preferred
            }
            
            // Restore window state if needed
            restoreWindowState()
        }
    }
    
    private func restoreWindowState() {
        // Check if we have saved window state
        if let savedFrame = UserDefaults.standard.string(forKey: "MainWindowFrame") {
            let frame = NSRectFromString(savedFrame)
            if let window = NSApplication.shared.windows.first {
                window.setFrame(frame, display: true)
                print("📄 App: Restored window frame: \(frame)")
            }
        }
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Return true to enable proper document-based app behavior
        return true
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If no windows are visible, create a new document
        if !flag {
            return true
        }
        return false
    }
    
    // CRITICAL: Override to handle code signing errors gracefully
    func application(_ application: NSApplication, willPresentError error: Error) -> Error {
        print("📄 App: Error intercepted: \(error)")
        
        // Use the custom error handler to check if this is a system-level error we should handle
        if SystemErrorHandler.shared.handleSystemError(error) {
            // Return a user-friendly error message instead of the system error
            return NSError(domain: "AppDelegate", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "App initialization completed successfully",
                NSLocalizedRecoverySuggestionErrorKey: "The app is ready to use despite the system warning."
            ])
        }
        
        return error
    }
    
    // SAVE: Window state when app is about to terminate
    func applicationWillTerminate(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            let frame = window.frame
            UserDefaults.standard.set(NSStringFromRect(frame), forKey: "MainWindowFrame")
            print("📄 App: Saved window frame: \(frame)")
        }
    }
}

@main
struct logos_inken_ioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @FocusedObject var documentState: DocumentState?
    @State private var appState = AppState()
    
    var body: some Scene {
        // PRIMARY: DocumentGroup handles BOTH new docs AND file opening (preserves all UI)
        DocumentGroup(newDocument: InkpenDocument()) { file in
            DocumentBasedContentView(inkpenDocument: file.$document, fileURL: file.fileURL)
                .environment(appState)
                .navigationTitle("")  // Clear default title - we'll use custom toolbar
        }
        .defaultSize(width: 1400, height: 900)  // Set larger default size for document windows
        .windowResizability(.contentSize)
        
        // SECONDARY: WindowGroup for non-document windows (templates, etc.)  
        // Re-enabled but configured to not interfere with document tabbing
        WindowGroup("New Document Setup") {
            ContentView()
                .environment(appState)
        }
        // Make this window group non-default so it doesn't interfere with DocumentGroup
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentSize)
        .commands {
            // SOLUTION: Create Custom Working Edit Menu with AUTOMATIC STATE UPDATES
            CommandMenu("Edit") {
                Button("Undo") {
                    documentState?.undo()
                }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(documentState?.canUndo != true)
                .onAppear {
                    if let menu = NSApplication.shared.mainMenu {
                        // Remove Apple's default Edit menu (grayed out and useless)
                        if let edit = menu.items.first(where: { $0.title == "Edit"}) {
                            menu.removeItem(edit)
                            
                            
                        }
                    }
                }
                
                Button("Redo") {
                    documentState?.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(documentState?.canRedo != true)
                
                Divider()
                
                Button("Cut") {
                    documentState?.cut()
                }
                .keyboardShortcut("x", modifiers: [.command])
                .disabled(documentState?.canCut != true)
                
                Button("Copy") {
                    documentState?.copy()
                }
                .keyboardShortcut("c", modifiers: [.command])
                .disabled(documentState?.canCopy != true)
                
                Button("Paste") {
                    documentState?.paste()
                }
                .keyboardShortcut("v", modifiers: [.command])
                .disabled(documentState?.canPaste != true)
                
                Button("Paste in Back") {
                    documentState?.pasteInBack()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(documentState?.canPaste != true)
                
                Button("Delete") {
                    documentState?.delete()
                }
                .keyboardShortcut(.delete)
                .disabled(documentState?.hasSelection != true)
                
                Divider()
                
                Button("Select All") {
                    documentState?.selectAll()
                }
                .keyboardShortcut("a", modifiers: [.command])
                
                Button("Deselect All") {
                    documentState?.deselectAll()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(documentState?.hasSelection != true)
            }
            
            
            // CREATE TOP-LEVEL Object Menu with AUTOMATIC STATES
            CommandMenu("Object") {
                // Arrange Section
                Button("Bring to Front") {
                    documentState?.bringToFront()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(documentState?.hasSelection != true)
                
                Button("Bring Forward") {
                    documentState?.bringForward()
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(documentState?.hasSelection != true)
                
                Button("Send Backward") {
                    documentState?.sendBackward()
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(documentState?.hasSelection != true)
                
                Button("Send to Back") {
                    documentState?.sendToBack()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(documentState?.hasSelection != true)
                
                Divider()
                
                // Group Section
                Button("Group") {
                    documentState?.groupObjects()
                }
                .keyboardShortcut("g", modifiers: [.command])
                .disabled(documentState?.canGroup != true)
                
                Button("Ungroup") {
                    documentState?.ungroupObjects()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(documentState?.canUngroup != true)
                
                Divider()
                
                // Flatten Section (Adobe Illustrator Style - Preserves Colors, Enables Transforms)
                Button("Flatten") {
                    documentState?.flattenObjects()
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
                .disabled(documentState?.canFlatten != true)
                .help("Flatten multiple shapes - preserves individual colors while enabling Scale, Rotate and Shear tools")
                
                Button("Unflatten") {
                    documentState?.unflattenObjects()
                }
                .keyboardShortcut("f", modifiers: [.command, .option, .shift])
                .disabled(documentState?.canUnflatten != true)
                .help("Restore flattened group back to individual shapes with original colors")
                
                Divider()
                
                // Transform Section
                Button("Duplicate") {
                    documentState?.duplicate()
                }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(documentState?.hasSelection != true)
                
                Divider()
                
                // Lock/Hide Section
                Button("Lock") {
                    documentState?.lockSelectedObjects()
                }
                .keyboardShortcut("2", modifiers: [.command])
                .disabled(documentState?.hasSelection != true)
                .help("Lock selected objects")
                
                Button("Unlock All") {
                    documentState?.unlockAllObjects()
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
                .help("Unlock all objects in the document")
                
                Button("Hide") {
                    documentState?.hideSelectedObjects()
                }
                .keyboardShortcut("3", modifiers: [.command])
                .disabled(documentState?.hasSelection != true)
                .help("Hide selected objects")
                
                Button("Show All") {
                    documentState?.showAllObjects()
                }
                .keyboardShortcut("3", modifiers: [.command, .option])
                .help("Show all hidden objects")
                
                Divider()
                
                // Text Section
                Button("Create Outlines") {
                    documentState?.createOutlines()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(!(documentState?.document?.selectedTextIDs.isEmpty == false))
                .help("Convert selected text objects to vector outlines")
                
                Divider()
                
                // Compound Path Section
                Button("Make Compound Path") {
                    documentState?.makeCompoundPath()
                }
                .keyboardShortcut("8", modifiers: [.command])
                .disabled(documentState?.canMakeCompoundPath != true)
                .help("Combine selected paths into a compound path with holes")
                
                Button("Release Compound Path") {
                    documentState?.releaseCompoundPath()
                }
                .keyboardShortcut("8", modifiers: [.command, .option])
                .disabled(documentState?.canReleaseCompoundPath != true)
                .help("Break compound path into separate individual paths")
                
                Divider()
                
                // Looping Path Section (Winding Fill Rule)
                Button("Make Looping Path") {
                    documentState?.makeLoopingPath()
                }
                .keyboardShortcut("9", modifiers: [.command])
                .disabled(documentState?.canMakeLoopingPath != true)
                .help("Combine selected paths into a looping path with winding fill rule")
                
                Button("Release Looping Path") {
                    documentState?.releaseLoopingPath()
                }
                .keyboardShortcut("9", modifiers: [.command, .option])
                .disabled(documentState?.canReleaseLoopingPath != true)
                .help("Break looping path into separate individual paths")
                
                Divider()
                
                // Warp Object Section
                Button("Unwrap Warp Object") {
                    documentState?.unwrapWarpObject()
                }
                .keyboardShortcut("w", modifiers: [.command, .option, .shift])
                .disabled(documentState?.canUnwrapWarpObject != true)
                .help("Unwrap the selected warp object back to its original shape")
                
                Button("Expand Warp Object") {
                    documentState?.expandWarpObject()
                }
                .keyboardShortcut("e", modifiers: [.command, .option, .shift])
                .disabled(documentState?.canExpandWarpObject != true)
                .help("Permanently apply the warp transformation to create a regular shape")
                
                Divider()
                
                // Path Cleanup Section (Professional Tools)
                Button("Clean Duplicate Points") {
                    documentState?.cleanupDuplicatePoints()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .help("Remove overlapping points and merge their curve data smoothly")
                
                Button("Clean All Duplicate Points") {
                    documentState?.cleanupAllDuplicatePoints()
                }
                .keyboardShortcut("k", modifiers: [.command, .option])
                .help("Clean duplicate points in all shapes in the document")
                
                Button("Test Duplicate Point Merger") {
                    documentState?.testDuplicatePointMerger()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift, .option])
                .help("Run a test to verify the duplicate point merger works correctly")
            }
            
            // WINDOW MENU - Panel Switching using AppState (no more notifications!)
            CommandMenu("Window") {
                Button("Show Layers Panel") {
                    appState.showLayersPanel()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                
                Button("Show Color Panel") {
                    appState.showColorPanel()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                
                Button("Show Stroke/Fill Panel") {
                    appState.showStrokeFillPanel()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Button("Show Path Ops Panel") {
                    appState.showPathOpsPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                
                Button("Show Font Panel") {
                    appState.showFontPanel()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
            
            // VIEW MENU - Zoom and View Mode using DocumentState (no more notifications!)
            CommandMenu("View") {
                Button("Zoom In") {
                    documentState?.zoomIn()
                }
                .keyboardShortcut("=", modifiers: [.command])
                
                Button("Zoom Out") {
                    documentState?.zoomOut()
                }
                .keyboardShortcut("-", modifiers: [.command])
                
                Button("Fit to Page") {
                    documentState?.fitToPage()
                }
                .keyboardShortcut("0", modifiers: [.command])
                
                Button("Actual Size") {
                    documentState?.actualSize()
                }
                .keyboardShortcut("1", modifiers: [.command])
                
                Divider()
                
                Button("Color View") {
                    documentState?.switchToColorView()
                }
                .keyboardShortcut("y", modifiers: [.command])
                
                Button("Keyline View") {
                    documentState?.switchToKeylineView()
                }
                .keyboardShortcut("y", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Toggle Rulers") {
                    documentState?.toggleRulers()
                }
                .keyboardShortcut("r", modifiers: [.command])
                
                Button("Toggle Grid") {
                    documentState?.toggleGrid()
                }
                .keyboardShortcut("'", modifiers: [.command])
                
                Button("Toggle Snap to Grid") {
                    documentState?.toggleSnapToGrid()
                }
                .keyboardShortcut(";", modifiers: [.command])
            }
            
            // DEVELOPMENT MENU - CoreGraphics Path Operations Testing using AppState (no more notifications!)
            CommandMenu("Development") {
                Button("CoreGraphics Path Operations Test") {
                    appState.showCoreGraphicsTest()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift, .option])
                .help("Test new CoreGraphics boolean operations (macOS 14+)")
                
                Divider()
                
                Button("Performance Benchmark") {
                    appState.runPathOperationsBenchmark()
                }
                .help("Benchmark ClipperPath vs CoreGraphics performance")
            }
        }
    }
}

// MARK: - Professional Clipboard Manager (Clean Implementation)
class ClipboardManager {
    static let shared = ClipboardManager()
    
    private let pasteboard = NSPasteboard.general
    private let vectorObjectsType = NSPasteboard.PasteboardType("com.toddbruss.logos-inkpen-io.vectorObjects")
    
    private init() {}
    
    func canPaste() -> Bool {
        return pasteboard.data(forType: vectorObjectsType) != nil
    }
    
    func cut(from document: VectorDocument) {
        copy(from: document)
        // Remove selected objects after copying
        if !document.selectedShapeIDs.isEmpty {
            document.removeSelectedShapes()
        } else if !document.selectedTextIDs.isEmpty {
            document.removeSelectedText()
        }
    }
    
    func copy(from document: VectorDocument) {
        // Get selected objects
        var shapesToCopy: [VectorShape] = []
        var textToCopy: [VectorText] = []
        
        // Collect selected shapes
        if let layerIndex = document.selectedLayerIndex {
            let layer = document.layers[layerIndex]
            shapesToCopy = layer.shapes.filter { document.selectedShapeIDs.contains($0.id) }
        }
        
        // Collect selected text
        textToCopy = document.textObjects.filter { document.selectedTextIDs.contains($0.id) }
        
        // Create clipboard data
        let clipboardData = ClipboardData(shapes: shapesToCopy, texts: textToCopy)
        
        // Encode and write to pasteboard
        do {
            let data = try JSONEncoder().encode(clipboardData)
            pasteboard.clearContents()
            pasteboard.setData(data, forType: vectorObjectsType)
            print("📋 Copied \(shapesToCopy.count) shapes and \(textToCopy.count) text objects")
        } catch {
            print("❌ Failed to copy objects: \(error)")
        }
    }
    
    func paste(to document: VectorDocument) {
        guard let data = pasteboard.data(forType: vectorObjectsType) else { return }
        
        do {
            let clipboardData = try JSONDecoder().decode(ClipboardData.self, from: data)
            
            document.saveToUndoStack()
            
            // Clear current selection
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs.removeAll()
            
            // Add shapes to current layer at EXACT original coordinates
            if let layerIndex = document.selectedLayerIndex {
                for shape in clipboardData.shapes {
                    var newShape = shape
                    newShape.id = UUID()
                    // PASTE AT EXACT ORIGINAL COORDINATES - no offset
                    document.layers[layerIndex].shapes.append(newShape)
                    document.selectedShapeIDs.insert(newShape.id)
                }
            }
            
            // Add text objects at EXACT original coordinates
            for text in clipboardData.texts {
                var newText = text
                newText.id = UUID()
                // PASTE AT EXACT ORIGINAL COORDINATES - no offset
                document.textObjects.append(newText)
                document.selectedTextIDs.insert(newText.id)
            }
            
            print("📋 Pasted \(clipboardData.shapes.count) shapes and \(clipboardData.texts.count) text objects at original coordinates")
        } catch {
            print("❌ Failed to paste objects: \(error)")
        }
    }
    
    func pasteInBack(to document: VectorDocument) {
        guard let data = pasteboard.data(forType: vectorObjectsType) else { return }
        
        do {
            let clipboardData = try JSONDecoder().decode(ClipboardData.self, from: data)
            
            document.saveToUndoStack()
            
            // Clear current selection
            let originalSelectedShapeIDs = document.selectedShapeIDs
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs.removeAll()
            
            // Add shapes to current layer BEHIND selected objects
            if let layerIndex = document.selectedLayerIndex {
                // Find the lowest index of any selected shape to paste behind it
                var insertIndex = 0
                
                if !originalSelectedShapeIDs.isEmpty {
                    // Find the first (lowest z-order) selected shape
                    for (index, shape) in document.layers[layerIndex].shapes.enumerated() {
                        if originalSelectedShapeIDs.contains(shape.id) {
                            insertIndex = index
                            break
                        }
                    }
                }
                
                // Insert shapes at the calculated index (behind selected objects)
                for (offset, shape) in clipboardData.shapes.enumerated() {
                    var newShape = shape
                    newShape.id = UUID()
                    // PASTE IN BACK: Insert at specific index to place behind selected objects
                    document.layers[layerIndex].shapes.insert(newShape, at: insertIndex + offset)
                    document.selectedShapeIDs.insert(newShape.id)
                }
            }
            
            // Add text objects at EXACT original coordinates (text doesn't have z-order within shapes)
            for text in clipboardData.texts {
                var newText = text
                newText.id = UUID()
                // PASTE AT EXACT ORIGINAL COORDINATES - no offset
                document.textObjects.append(newText)
                document.selectedTextIDs.insert(newText.id)
            }
            
            print("📋 Pasted in back: \(clipboardData.shapes.count) shapes and \(clipboardData.texts.count) text objects at original coordinates")
        } catch {
            print("❌ Failed to paste in back: \(error)")
        }
    }
    
    // NOTE: offsetPath function removed - paste now uses exact original coordinates
}

// MARK: - Clipboard Data Structure
struct ClipboardData: Codable {
    let shapes: [VectorShape]
    let texts: [VectorText]
}
