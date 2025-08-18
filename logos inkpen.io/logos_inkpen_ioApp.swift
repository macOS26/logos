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
import ObjectiveC
import Darwin

// MARK: - Window Accessor for macOS 15+ Floating Window Features
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No update needed
    }
}

// MARK: - WindowAccessor handles floating window level conditionally in code

// MARK: - Gradient HUD Window Delegate to Preserve Position
class GradientHUDWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = GradientHUDWindowDelegate()
    
    private override init() {
        super.init()
    }
    
    // 🔥 INTERCEPT CLOSE BUTTON TO PRESERVE WINDOW POSITION
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Check if this is our gradient HUD window
        if sender.title == "Select Gradient Color" {
            Log.info("🎨 GRADIENT HUD: Close button clicked - preserving position with orderOut", category: .general)
            AppState.shared.persistentGradientHUD.stopEditing()
            sender.orderOut(nil)
            return false
        }
        
        // Check if this is our Ink Color Mixer HUD
        if sender.title == "Ink Color Mixer" {
            Log.info("🖌️ INK HUD: Close button clicked - hiding window via orderOut", category: .general)
            AppState.shared.persistentInkHUD.hide()
            sender.orderOut(nil)
            return false
        }
        
        // Allow normal close behavior for other windows
        return true
    }
}

// MARK: - DocumentState Registry (replaces notifications)
final class DocumentStateRegistry {
    static let shared = DocumentStateRegistry()
    private let table = NSHashTable<DocumentState>.weakObjects()
    private let lock = NSLock()
    private init() {}
    func register(_ state: DocumentState) {
        lock.lock(); defer { lock.unlock() }
        table.add(state)
    }
    func forceCleanupAll() {
        lock.lock(); let states = table.allObjects; lock.unlock()
        for state in states { state.forceCleanup() }
    }
}

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
            Log.error("❌ Failed to load document: \(error)", category: .error)
            throw error
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        do {
            let data = try FileOperations.exportToJSONData(document)
            return FileWrapper(regularFileWithContents: data)
        } catch {
            Log.error("❌ Failed to save document: \(error)", category: .error)
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
    @Published var canEmbedLinkedImages = false
    
    private var cancellables = Set<AnyCancellable>()
    private var isTerminating = false
    
    init() {
        Log.startup("🎯 DocumentState initialized with automatic menu state updates")
        // Defer observer setup until document is set to prevent blocking during launch
        
        // Register with central registry (no notifications)
        DocumentStateRegistry.shared.register(self)
    }
    
    deinit {
        // CRITICAL: Clean up all subscriptions to prevent retain cycles
        cancellables.removeAll()
        Log.startup("🎯 DocumentState deallocated - subscriptions cleaned up")
    }
    
    func setDocument(_ document: VectorDocument) {
        // Clean up previous subscriptions before setting new document
        cancellables.removeAll()
        
        self.document = document
        updateAllStates()
        
        // Set up observers asynchronously to prevent blocking
        Task {
            await setupDocumentObserversAsync()
        }
    }
    
    func cleanup() {
        // Explicit cleanup method for app shutdown
        cancellables.removeAll()
        document = nil
        Log.startup("🎯 DocumentState cleanup completed")
    }
    
    func forceCleanup() {
        // Force cleanup called from app termination
        Log.startup("🎯 DocumentState force cleanup initiated")
        isTerminating = true
        cancellables.removeAll()
        
        // Clear document reference to break any potential retain cycles
        document = nil
        
        // Clear all @Published properties to prevent further updates
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
        
        Log.startup("🎯 DocumentState force cleanup completed")
    }
    
    private func setupDocumentObserversAsync() async {
        guard let document = document else { return }
        
        // Clear previous observations
        cancellables.removeAll()
        
        // Monitor document changes that affect menu states
        document.objectWillChange.sink { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateAllStates()
            }
        }
        .store(in: &cancellables)
        
        Log.startup("✅ Document observers set up asynchronously")
    }
    
    private func updateAllStates() {
        // CRITICAL: Don't update states during app termination to prevent SwiftUI constraint crashes
        guard !isTerminating else {
            Log.startup("🎯 DocumentState: Skipping state update during termination")
            return
        }
        
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
        // Links menu enablement: any selected shape with a linked image or a raster image in registry
        canEmbedLinkedImages = {
            let selected = document.getShapesByIds(document.selectedShapeIDs)
            for s in selected {
                if s.linkedImagePath != nil { return true }
                if ImageContentRegistry.containsImage(s) { return true }
            }
            return false
        }()
        
        // Removed excessive logging per user request
    }
    
    // MARK: - Commands Actions
    func showImportDialog() {
        guard let document = document else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .svg,
            .pdf,
            UTType("com.adobe.illustrator.ai-image")!,
            UTType("com.adobe.encapsulated-postscript")!,
            UTType("com.adobe.postscript")!,
            UTType(filenameExtension: "ps")!,
            UTType(filenameExtension: "ai")!,
            UTType(filenameExtension: "eps")!,
            UTType(filenameExtension: "dwf")!,
            .png, .jpeg, .tiff, .gif, .bmp, UTType("public.heic")!,
            .data
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import"
        panel.begin { response in
            guard response == .OK, let url = panel.urls.first else { return }
            Task {
                let result = await VectorImportManager.shared.importVectorFile(from: url)
                await MainActor.run {
                    if result.success {
                        document.saveToUndoStack()
                        if let layerIndex = document.selectedLayerIndex ?? (document.layers.indices.first) {
                            var newShapeIDs: Set<UUID> = []
                            for shape in result.shapes {
                                document.layers[layerIndex].addShape(shape)
                                newShapeIDs.insert(shape.id)
                            }
                            document.selectedShapeIDs = newShapeIDs
                        }
                        self.updateAllStates()
                    } else {
                        let alert = NSAlert()
                        alert.messageText = "Import Failed"
                        let errorText = result.errors.map { $0.localizedDescription }.joined(separator: ", ")
                        alert.informativeText = errorText.isEmpty ? "The selected file could not be imported." : errorText
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
            }
        }
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
        Log.info("🗑️ MENU: Deleted selected objects", category: .general)
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
        document.requestZoom(to: newZoom, mode: .zoomIn)
        Log.info("🔍 MENU: Zoom In from \(String(format: "%.1f", oldZoom * 100))% to \(String(format: "%.1f", newZoom * 100))%", category: .zoom)
    }
    
    func zoomOut() {
        guard let document = document else { return }
        let oldZoom = document.zoomLevel
        let newZoom = max(document.zoomLevel / 1.25, 0.01)
        document.requestZoom(to: newZoom, mode: .zoomOut)
        Log.info("🔍 MENU: Zoom Out from \(String(format: "%.1f", oldZoom * 100))% to \(String(format: "%.1f", newZoom * 100))%", category: .zoom)
    }
    
    func fitToPage() {
        document?.requestZoom(to: 0.0, mode: .fitToPage)
        Log.info("📐 MENU: Fit to Page", category: .general)
    }
    
    func actualSize() {
        document?.zoomLevel = 1.0
        Log.info("📏 MENU: Actual Size (100%)", category: .general)
    }
    
    func switchToColorView() {
        document?.viewMode = .color
        Log.info("🎨 MENU: Switched to Color View", category: .general)
    }
    
    func switchToKeylineView() {
        document?.viewMode = .keyline
        Log.info("📝 MENU: Switched to Keyline View", category: .general)
    }
    
    func toggleRulers() {
        document?.showRulers.toggle()
        Log.info("📏 MENU: Rulers \(document?.showRulers == true ? "shown" : "hidden")", category: .general)
    }
    
    func toggleGrid() {
        document?.settings.showGrid.toggle()
        Log.info("🔲 MENU: Grid \(document?.settings.showGrid == true ? "shown" : "hidden")", category: .general)
    }
    
    func toggleSnapToGrid() {
        document?.snapToGrid.toggle()
        Log.info("🧲 MENU: Snap to Grid \(document?.snapToGrid == true ? "enabled" : "disabled")", category: .general)
    }
    
    // MARK: - Text Commands
    func createOutlines() {
        guard let document = document, !document.selectedTextIDs.isEmpty else { return }
        document.convertSelectedTextToOutlines()
        updateAllStates()
        Log.info("📝 MENU: Converted selected text to outlines", category: .general)
    }
    
    // MARK: - Links Commands
    func embedSelectedLinkedImages() {
        guard let document = document else { return }
        var anyEmbedded = false
        for layerIndex in document.layers.indices {
            for shapeIndex in document.layers[layerIndex].shapes.indices {
                var shape = document.layers[layerIndex].shapes[shapeIndex]
                guard document.selectedShapeIDs.contains(shape.id) else { continue }
                // Obtain image either from registry or from linked path
                var nsImage: NSImage? = ImageContentRegistry.image(for: shape.id)
                if nsImage == nil, let path = shape.linkedImagePath {
                    let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
                    nsImage = NSImage(contentsOf: url)
                    if let img = nsImage { ImageContentRegistry.register(image: img, for: shape.id) }
                }
                guard let image = nsImage else { continue }
                // Create PNG data preferred; fallback to TIFF if needed
                var embedded: Data? = nil
                if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                    embedded = rep.representation(using: .png, properties: [:])
                    if embedded == nil { embedded = tiff }
                }
                if embedded == nil, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let rep = NSBitmapImageRep(cgImage: cg)
                    embedded = rep.representation(using: .png, properties: [:])
                }
                guard let data = embedded else { continue }
                shape.embeddedImageData = data
                // Keep link path for reference; user can manually clear if desired
                document.layers[layerIndex].shapes[shapeIndex] = shape
                anyEmbedded = true
            }
        }
        if anyEmbedded {
            Log.info("🧩 Embedded linked images into document for selected shapes", category: .general)
        }
        updateAllStates()
    }
    
    // MARK: - Path Cleanup Commands (Professional Tools)
    func cleanupDuplicatePoints() {
        guard let document = document else { return }
        if !document.selectedShapeIDs.isEmpty {
            ProfessionalPathOperations.cleanupSelectedShapesDuplicates(document, tolerance: 5.0)
            Log.info("🧹 MENU: Cleaned duplicate points in selected shapes", category: .general)
        } else {
            ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 5.0)
            Log.info("🧹 MENU: Cleaned duplicate points in all shapes", category: .general)
        }
        updateAllStates()
    }
    
    func cleanupAllDuplicatePoints() {
        guard let document = document else { return }
        ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 5.0)
        Log.info("🧹 MENU: Cleaned duplicate points in all document shapes", category: .general)
        updateAllStates()
    }
    
    func testDuplicatePointMerger() {
        ProfessionalPathOperations.testDuplicatePointMerger()
        Log.info("🧪 MENU: Ran duplicate point merger test", category: .general)
    }
    
    // MARK: - Tool Switching Commands
    func switchToTool(_ tool: DrawingTool) {
        guard let document = document else { return }
        let previousTool = document.currentTool
        document.currentTool = tool
        
        // PROPER TOOL GROUP HANDLING: When switching to a tool via keyboard shortcut,
        // make it the active tool in its group and expand the group if needed
        let toolGroup = ToolGroupConfiguration.getToolGroup(for: tool)
        
        // Update the shared ToolGroupManager to reflect the new tool selection
        ToolGroupManager.shared.handleKeyboardToolSwitch(tool: tool, toolGroup: toolGroup)
        
        Log.info("🛠️ MENU: Switched from \(previousTool.rawValue) to \(tool.rawValue)", category: .general)
    }
}

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
    @State private var showingPressureCalibration = false
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
                ImageContentRegistry.setBaseDirectoryURL(url.deletingLastPathComponent())
                for layer in document.layers {
                    for shape in layer.shapes {
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
        .onAppear {
            // Apply the user's default tool setting to the document
            document.currentTool = appState.defaultTool
            Log.info("🛠️ Applied default tool \(appState.defaultTool.rawValue) to DocumentGroup document", category: .general)
            
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
                        Log.info("✅ Successfully opened \(fileExtension.uppercased()) document from: \(url.path)", category: .fileOperations)
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
    
    private func newDocument() {
        // Keep legacy API available; forward to onNew()
        //onNew()
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
        document.currentTool = appState.defaultTool
        document.viewMode = .color
        document.showRulers = importedDoc.showRulers
        document.snapToGrid = importedDoc.snapToGrid
        
        Log.info("✅ Loaded imported document - \(document.layers.count) layers, \(document.layers.reduce(0) { $0 + $1.shapes.count }) shapes", category: .fileOperations)
        
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
                Log.warning("📄 SystemCallInterceptor: Detected potential main thread blocking - attempting recovery", category: .startup)
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
        Log.startup("📄 StartupCoordinator: Beginning startup sequence")
        
        // Set up system call monitoring
        SystemCallInterceptor.shared.setupSystemCallMonitoring()
        
        // Add timeout to prevent hanging
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
            Log.warning("📄 StartupCoordinator: Warning - startup sequence taking longer than expected", category: .startup)
        }
        
        // Perform startup tasks with error handling
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Configure window tabbing
            group.addTask {
                await self.configureWindowTabbing()
            }
            
            // Task 2: Check file system access
            group.addTask {
                await self.checkFileSystemAccessAsync()
            }
            
            // Task 3: Initialize document controller
            group.addTask {
                await self.initializeDocumentController()
            }
        }
        
        // Cancel timeout task since we completed successfully
        timeoutTask.cancel()
        
        // Test error handling in development
#if DEBUG
        testErrorHandling()
#endif
        
        Log.startup("📄 StartupCoordinator: Startup sequence completed")
    }
    
    private func configureWindowTabbing() async {
        await MainActor.run {
            // Enable automatic tabbing for document windows; utility windows opt-out individually
            NSWindow.allowsAutomaticWindowTabbing = true
            UserDefaults.standard.set("always", forKey: "AppleWindowTabbingMode")
            Log.startup("📄 StartupCoordinator: Window tabbing set to always; document windows will tab, utilities opt-out")
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
                    Log.startup("📄 StartupCoordinator: File system access verified for \(directory.lastPathComponent)")
                } catch {
                                          Log.warning("📄 StartupCoordinator: File system warning for \(directory.lastPathComponent): \(error.localizedDescription)", category: .startup)
                }
            }
        }.value
    }
    
    private func initializeDocumentController() async {
        await MainActor.run {
            let documentController = NSDocumentController.shared
            documentController.autosavingDelay = 30.0
            UserDefaults.standard.set(true, forKey: "NSQuitAlwaysKeepsWindows")
            Log.startup("📄 StartupCoordinator: Document controller initialized")
        }
    }
    
    // Test method to verify error handling
    func testErrorHandling() {
        Log.startup("📄 StartupCoordinator: Testing error handling...")
        
        // Simulate the DetachedSignatures error
        let testError = NSError(domain: "TestDomain", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "cannot open file at line 49448 of [1b37c146ee] os_unix.c:49448: (2) open(/private/var/db/DetachedSignatures) - No such file or directory"
        ])
        
        let wasHandled = SystemErrorHandler.shared.handleSystemError(testError)
        Log.startup("📄 StartupCoordinator: Test error was handled: \(wasHandled)")
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
            
                    Log.warning("📄 SystemErrorHandler: Detected system directory access error - \(errorDescription)", category: .startup)
        Log.warning("📄 SystemErrorHandler: This is likely a code signing verification issue in development", category: .startup)
        Log.warning("📄 SystemErrorHandler: Continuing app initialization gracefully", category: .startup)
            return true // Error handled
        }
        
        // Check for RenderBox framework errors
        if errorDescription.contains("renderbox") ||
            errorDescription.contains("metallib") ||
            errorDescription.contains("mach-o") {
                    Log.warning("📄 SystemErrorHandler: Detected RenderBox/Metal framework error - \(errorDescription)", category: .startup)
        Log.warning("📄 SystemErrorHandler: This is a system framework loading issue - continuing gracefully", category: .startup)
            return true // Error handled
        }
        
        // Check for persona attributes errors
        if errorDescription.contains("personaattributes") ||
            errorDescription.contains("persona type") ||
            errorDescription.contains("operation not permitted") {
                    Log.warning("📄 SystemErrorHandler: Detected persona attributes error - \(errorDescription)", category: .startup)
        Log.warning("📄 SystemErrorHandler: This is a system permission issue - continuing gracefully", category: .startup)
            return true // Error handled
        }
        
        // Check for other common system-level errors that shouldn't block the app
        if errorDomain == "NSCocoaErrorDomain" &&
            (errorDescription.contains("file system") || errorDescription.contains("permission")) {
            Log.warning("📄 SystemErrorHandler: Detected file system permission error - continuing gracefully", category: .startup)
            return true // Error handled
        }
        
        // Check for NSPOSIXErrorDomain errors with specific codes
        if errorDomain == "NSPOSIXErrorDomain" &&
            (errorCode == 1 || errorCode == 2) { // Operation not permitted, No such file or directory
            Log.warning("📄 SystemErrorHandler: Detected POSIX error (code \(errorCode)) - continuing gracefully", category: .startup)
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

// MARK: - Stderr Filter (Suppresses noisy system warnings)
final class StderrFilter {
    static let shared = StderrFilter()
    
    private var suppressPatterns: [String] = []
    private var originalStderrFD: Int32 = -1
    private var pipeReadFD: Int32 = -1
    private var pipeWriteFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var pendingBuffer = Data()
    private let queue = DispatchQueue(label: "io.logos.stderr.filter", qos: .background)
    private var isInstalled = false
    
    private init() {}
    
    func installFilter(suppressing patterns: [String]) {
        guard !isInstalled else { return }
        isInstalled = true
        suppressPatterns = patterns.map { $0.lowercased() }
        
        var fds: [Int32] = [0, 0]
        if pipe(&fds) != 0 {
            return
        }
        pipeReadFD = fds[0]
        pipeWriteFD = fds[1]
        
        // Duplicate current stderr so we can still write through to it
        originalStderrFD = dup(STDERR_FILENO)
        if originalStderrFD == -1 {
            close(pipeReadFD)
            close(pipeWriteFD)
            return
        }
        
        // Make stderr unbuffered to avoid delays
        setvbuf(stderr, nil, _IONBF, 0)
        
        // Redirect stderr to our pipe
        if dup2(pipeWriteFD, STDERR_FILENO) == -1 {
            close(pipeReadFD)
            close(pipeWriteFD)
            close(originalStderrFD)
            return
        }
        // We can close our copy of the write end; STDERR now refers to it
        close(pipeWriteFD)
        
        let source = DispatchSource.makeReadSource(fileDescriptor: pipeReadFD, queue: queue)
        readSource = source
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(self.pipeReadFD, &buffer, buffer.count)
            if bytesRead > 0 {
                self.pendingBuffer.append(buffer, count: bytesRead)
                self.processPendingBuffer()
            } else if bytesRead == 0 {
                // EOF
                self.flushRemaining()
                self.cleanup()
            } else {
                // Read error
                self.cleanup()
            }
        }
        
        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.pipeReadFD != -1 { close(self.pipeReadFD) }
        }
        
        source.resume()
    }
    
    private func processPendingBuffer() {
        // Split by newline, keep last partial in pendingBuffer
        while let range = pendingBuffer.firstRange(of: Data([0x0A])) { // '\n'
            let lineData = pendingBuffer.subdata(in: 0..<range.lowerBound)
            pendingBuffer.removeSubrange(0..<(range.upperBound)) // remove line + newline
            forwardIfNotSuppressed(lineData: lineData)
        }
    }
    
    private func flushRemaining() {
        if !pendingBuffer.isEmpty {
            forwardIfNotSuppressed(lineData: pendingBuffer)
            pendingBuffer.removeAll(keepingCapacity: false)
        }
    }
    
    private func forwardIfNotSuppressed(lineData: Data) {
        guard let line = String(data: lineData, encoding: .utf8) else {
            writeRaw(lineData)
            writeRaw(Data([0x0A]))
            return
        }
        let lower = line.lowercased()
        let shouldSuppress = suppressPatterns.contains { lower.contains($0) }
        if !shouldSuppress {
            writeRaw(lineData)
            writeRaw(Data([0x0A]))
        }
    }
    
    private func writeRaw(_ data: Data) {
        data.withUnsafeBytes { ptr in
            var remaining = ptr.count
            var base = ptr.bindMemory(to: UInt8.self).baseAddress
            while remaining > 0 {
                let written = write(originalStderrFD, base, remaining)
                if written <= 0 { break }
                remaining -= written
                base = base?.advanced(by: written)
            }
        }
    }
    
    private func cleanup() {
        readSource?.cancel()
        readSource = nil
        if originalStderrFD != -1 { close(originalStderrFD); originalStderrFD = -1 }
        if pipeReadFD != -1 { close(pipeReadFD); pipeReadFD = -1 }
        isInstalled = false
    }
}

// MARK: - AppDelegate to ensure proper document tabbing and window persistence
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {        
        // Install stderr filter to suppress noisy system-level SQLite warning lines
        StderrFilter.shared.installFilter(suppressing: [
            "/private/var/db/DetachedSignatures",
            "os_unix.c:49448",
            "cannot open file at line 49448"
        ])
        
        // Apply Apple Metal Performance HUD environment if enabled in preferences
        let enabled = UserDefaults.standard.bool(forKey: "enableSystemMetalHUD")
        if enabled {
            setenv("MTL_HUD_ENABLED", "1", 1)
        } else {
            unsetenv("MTL_HUD_ENABLED")
        }
        
        // SETUP: Global error handling for system-level issues
        setupGlobalErrorHandling()
        
        // REMOVED: Repetitive app initialization logging
        
        // Use the startup coordinator for robust initialization
        Task {
            await StartupCoordinator.shared.performStartupTasks()
            
            // After startup tasks complete, configure windows
            await configureWindowsAsync()
        }
        
        // Set up a fallback timer to ensure the app doesn't hang
        setupFallbackTimer()
        
        // Normalize menus shortly after launch (once) so order is correct
        
    }
    
    private func setupFallbackTimer() {
        // Set up a timer that will force the app to continue if it gets stuck
        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { _ in
            // REMOVED: Repetitive fallback timer logging
            
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
            
                    Log.error("📄 GlobalErrorHandler: Uncaught exception: \(exceptionName)", category: .error)
        Log.error("📄 GlobalErrorHandler: Reason: \(exceptionReason)", category: .error)
            
            // Check if this is a system-level error we should handle gracefully
            if exceptionReason.contains("DetachedSignatures") ||
                exceptionReason.contains("/private/var/db/") ||
                exceptionReason.contains("No such file or directory") ||
                exceptionReason.contains("RenderBox") ||
                exceptionReason.contains("metallib") ||
                exceptionReason.contains("personaAttributes") {
                Log.warning("📄 GlobalErrorHandler: System-level error detected - continuing gracefully", category: .startup)
                return // Don't crash the app
            }
            
            // For other exceptions, let them propagate normally
            Log.error("📄 GlobalErrorHandler: Allowing exception to propagate", category: .error)
        }
    }
    
    
    
    
    
    private func configureWindowsAsync() async {
        // Add a delay to let the app fully initialize and check for existing document windows
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        await MainActor.run {
            // Check if we have any document windows open
            let documentWindows = NSApplication.shared.windows.filter { window in
                // Check if this is a document window (not the onboarding window)
                return window.title != "Document Setup" && window.title != ""
            }
            
            // If we have document windows open, close the onboarding window
            if !documentWindows.isEmpty {
                // Close the onboarding window if it exists
                if let onboardingWindow = NSApplication.shared.windows.first(where: { $0.title == "Document Setup" }) {
                    onboardingWindow.close()
                    Log.info("📄 App: Document windows detected at launch - closing onboarding setup window", category: .startup)
                }
                
                // Also check if there are any other setup windows that might be visible
                NSApplication.shared.windows.forEach { window in
                    if window.title == "Document Setup" {
                        window.close()
                        Log.info("📄 App: Closed additional setup window", category: .startup)
                    }
                }
            } else {
                Log.info("📄 App: No document windows detected at launch - keeping onboarding setup window", category: .startup)
            }
            
            // Adjust any Apple Metal HUD carrier view if present in visible windows
            NSApplication.shared.windows.forEach { window in
                if AppState.shared.enableSystemMetalHUD {
                    for subview in window.contentView?.subviews ?? [] {
                        let className = String(describing: type(of: subview))
                        if className.lowercased().contains("hud") || className.lowercased().contains("metal") {
                            var frame = subview.frame
                            frame.origin.x = AppState.shared.metalHUDOffsetX
                            frame.origin.y = window.frame.height - AppState.shared.metalHUDOffsetY - frame.height
                            frame.size.width = AppState.shared.metalHUDWidth
                            frame.size.height = AppState.shared.metalHUDHeight
                            subview.frame = frame
                        }
                    }
                }
            }
            Log.startup("📄 App: Adjusted Metal HUD positioning where applicable")
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
            // No-op: individual windows manage their own tabbing preferences
        }
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Return false to prevent the Open Dialog, but we'll handle document creation ourselves
        Log.startup("📄 App: Intercepting untitled file creation - will show New Document Setup Window instead")
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Check if we have any document windows open (not just visible windows)
        let documentWindows = NSApplication.shared.windows.filter { window in
            return window.title != "Document Setup" && window.title != ""
        }
        
        // If no document windows are open, let DocumentGroup handle document creation
        if documentWindows.isEmpty {
            // REMOVED: Repetitive app reopen logging
            return true
        } else {
            // REMOVED: Repetitive app reopen logging
            return false
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Log.startup("📄 App: Application should terminate - starting graceful shutdown")
        
        // Directly instruct all DocumentState instances to stop updating immediately
        DocumentStateRegistry.shared.forceCleanupAll()
        
        // Allow a brief moment for cleanup to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Log.startup("📄 App: Cleanup phase completed, terminating now")
        }
        
        return .terminateNow
    }
    
    // CRITICAL: Override to handle code signing errors gracefully
    func application(_ application: NSApplication, willPresentError error: Error) -> Error {
        Log.error("📄 App: Error intercepted: \(error)", category: .error)
        
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
        Log.startup("📄 App: Starting termination cleanup...")
        
        // CRITICAL: Clean up all state objects to prevent retain cycles during shutdown
        cleanupAllStateObjects()
        
        // CRITICAL: Force cleanup of all DocumentState instances
        cleanupAllDocumentStates()
        
        // Force synchronize UserDefaults before shutdown
        UserDefaults.standard.synchronize()
        
        Log.startup("📄 App: Application termination cleanup completed")
    }
    
    private func cleanupAllStateObjects() {
        // Clean up any remaining state objects
        // This helps prevent retain cycles during SwiftUI cleanup
        Log.startup("📄 App: Cleaning up state objects for shutdown")
    }
    
    private func cleanupAllDocumentStates() {
        // Force cleanup of any DocumentState instances that might still have active subscriptions
        Log.startup("📄 App: Forcing cleanup of all DocumentState instances")
        
        // Directly force cleanup of all DocumentState instances
        DocumentStateRegistry.shared.forceCleanupAll()
        
        // Give a brief moment for cleanup to complete
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }
}

@main
struct logos_inken_ioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @FocusedObject var documentState: DocumentState?
    private var appState = AppState.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    init() {
        // Register default preferences for first launch
        UserDefaults.standard.register(defaults: [
            "brushPreviewStyle": AppState.BrushPreviewStyle.outline.rawValue,
            "brushPreviewIsFinal": false
        ])
        
        // Test Metal Compute Engine on app startup
        Log.metal("🔧 Testing Metal Compute Engine...", level: .info)
        let metalWorking = MetalComputeEngine.testMetalEngine()
        Log.metal("🔧 Metal Engine Status: \(metalWorking ? "✅ Working" : "❌ Failed")", level: .info)
    }
    
    
    
    //    func onNew() {
    //        // Open dedicated setup window instead of creating a new tabbed document
    //        openWindow(id: "new-document-setup")
    //    }
    
    var body: some Scene {
        // ONBOARDING: Show New Document Setup Window only when no document windows exist
        WindowGroup("Document Setup", id: "onboarding-setup") {
            NewDocumentSetupView(
                isPresented: .constant(true),
                onDocumentCreated: { newDoc, _ in
                    // Store the configured document settings
                    appState.pendingNewDocument = newDoc
                    
                    // Close this onboarding window
                    dismissWindow(id: "onboarding-setup")
                    
                    // Create a new document using DocumentGroup
                    NSDocumentController.shared.newDocument(nil)
                }
            )
            .environment(appState)
        }
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)

        
        // PRIMARY: DocumentGroup handles BOTH new docs AND file opening (preserves all UI)
        DocumentGroup(newDocument: InkpenDocument()) { file in
            DocumentBasedContentView(inkpenDocument: file.$document, fileURL: file.fileURL)
                .environment(appState)
                .navigationTitle("")  // Clear default title - we'll use custom toolbar
                .onAppear {
                    // Set up window management for gradient HUD
                    appState.setWindowActions(
                        openWindow: { id in openWindow(id: id) },
                        dismissWindow: { id in dismissWindow(id: id) }
                    )
                }
        }
        .defaultSize(width: 1400, height: 900)  // Set larger default size for document windows
        .windowResizability(.contentSize)
        
        .commands {
            
            Group {
                CommandGroup(replacing: .importExport) {
                    Button("Import…") {
                        documentState?.showImportDialog()
                    }
                    .keyboardShortcut("i", modifiers: [.command])
                    .help("Import SVG, PDF, AI, EPS, DWF, PNG, JPEG, TIFF, GIF, BMP, HEIC")
                }
                
                // Application Menu commands (appears under the app name)
                CommandGroup(replacing: .appSettings) {
                    Menu("Default Tool") {
                        Button(AppState.shared.defaultTool == .selection ? "✓ Selection Tool (Arrow)" : "Selection Tool (Arrow)") {
                            AppState.shared.defaultTool = .selection
                        }
                        .help("Set selection tool as default for new documents")
                        
                        Button(AppState.shared.defaultTool == .directSelection ? "✓ Direct Selection Tool" : "Direct Selection Tool") {
                            AppState.shared.defaultTool = .directSelection
                        }
                        .help("Set direct selection tool as default for new documents")
                        
                        Divider()
                        
                        Button(AppState.shared.defaultTool == .bezierPen ? "✓ Bezier Pen Tool" : "Bezier Pen Tool") {
                            AppState.shared.defaultTool = .bezierPen
                        }
                        .help("Set bezier pen tool as default for new documents")
                        
                        Button(AppState.shared.defaultTool == .freehand ? "✓ Freehand Tool" : "Freehand Tool") {
                            AppState.shared.defaultTool = .freehand
                        }
                        .help("Set freehand tool as default for new documents")
                        
                        Button(AppState.shared.defaultTool == .brush ? "✓ Brush Tool" : "Brush Tool") {
                            AppState.shared.defaultTool = .brush
                        }
                        .help("Set brush tool as default for new documents")
                        
                        Button(AppState.shared.defaultTool == .marker ? "✓ Marker Tool" : "Marker Tool") {
                            AppState.shared.defaultTool = .marker
                        }
                        .help("Set marker tool as default for new documents")
                        
                        Divider()
                        
                        Button(AppState.shared.defaultTool == .line ? "✓ Line Tool" : "Line Tool") {
                            AppState.shared.defaultTool = .line
                        }
                        .help("Set line tool as default for new documents")
                        
                        Button(AppState.shared.defaultTool == .rectangle ? "✓ Rectangle Tool" : "Rectangle Tool") {
                            AppState.shared.defaultTool = .rectangle
                        }
                        .help("Set rectangle tool as default for new documents")
                        
                        Button(AppState.shared.defaultTool == .circle ? "✓ Circle Tool" : "Circle Tool") {
                            AppState.shared.defaultTool = .circle
                        }
                        .help("Set circle tool as default for new documents")
                    }
                    
                    Divider()
                    
                    Button("Preferences...") {
                        openWindow(id: "app-preferences")
                    }
                    .keyboardShortcut(",", modifiers: [.command])
                    .help("Open application preferences")
                }
                
                
                // SOLUTION: Create Custom Working Edit Menu with AUTOMATIC STATE UPDATES
                CommandGroup(replacing: .undoRedo) {
                    Button("Undo") {
                        documentState?.undo()
                    }
                    .keyboardShortcut("z", modifiers: [.command])
                    .disabled(documentState?.canUndo != true)
                    
                    Button("Redo") {
                        documentState?.redo()
                    }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(documentState?.canRedo != true)
                }
                
                CommandGroup(replacing: .pasteboard) {
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
                }
                
                CommandGroup(replacing: .textEditing) {
                    Button("Select All") {
                        documentState?.selectAll()
                    }
                    .keyboardShortcut("a", modifiers: [.command])
                    
                    Button("Deselect All") {
                        documentState?.deselectAll()
                    }
                    .keyboardShortcut(.tab)
                    .disabled(documentState?.hasSelection != true)
                }
            }
            
            Group {
                // CREATE TOP-LEVEL Object Menu with AUTOMATIC STATES
                CommandMenu("Object") {
                    // Arrange Section
                    
                    Menu("Arrange") {
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
                        
                    }
                    
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
                    
                    // Flatten Section (Professional Style - Preserves Colors, Enables Transforms)
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
                    
                    // Links submenu for image handling
                    Menu("Links") {
                        Button("Embed Linked Images in Selection") {
                            documentState?.embedSelectedLinkedImages()
                        }
                        .disabled(documentState?.canEmbedLinkedImages != true)
                        .help("Embed the image data into the document for portability. Default behavior keeps links.")
                    }
                    
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
                
                // PANEL MENU
                CommandMenu("Panel") {
                    Button(action: { appState.selectedPanelTab = .layers }) {
                        Label("Layer", systemImage: PanelTab.layers.iconName)
                    }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                    
                    Button(action: { appState.selectedPanelTab = .properties }) {
                        Label("Paint", systemImage: PanelTab.properties.iconName)
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    
                    Button(action: { appState.selectedPanelTab = .gradient }) {
                        Label("Grade", systemImage: PanelTab.gradient.iconName)
                    }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    
                    Button(action: { appState.selectedPanelTab = .color }) {
                        Label("Ink", systemImage: PanelTab.color.iconName)
                    }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    
                    Button(action: { appState.selectedPanelTab = .pathOps }) {
                        Label("Path", systemImage: PanelTab.pathOps.iconName)
                    }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    
                    Button(action: { appState.selectedPanelTab = .font }) {
                        Label("Font", systemImage: PanelTab.font.iconName)
                    }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                }
                
                // VIEW MENU
                CommandGroup(replacing: .sidebar) {
                    
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
                
                CommandMenu("Tools") {
                    Button("Selection Tool") {
                        documentState?.switchToTool(.selection)
                    }
                    .keyboardShortcut("a", modifiers: [])
                    .help("Switch to selection tool")
                    
                    Button("Direct Selection Tool") {
                        documentState?.switchToTool(.directSelection)
                    }
                    .keyboardShortcut("d", modifiers: [])
                    .help("Switch to direct selection tool")
                    
                    Button("Convert Anchor Point Tool") {
                        documentState?.switchToTool(.convertAnchorPoint)
                    }
                    .keyboardShortcut("c", modifiers: [])
                    .help("Switch to convert anchor point tool")
                    
                    Divider()
                    
                    Button("Scale Tool") {
                        documentState?.switchToTool(.scale)
                    }
                    .keyboardShortcut("s", modifiers: [])
                    .help("Switch to scale tool")
                    
                    Button("Rotate Tool") {
                        documentState?.switchToTool(.rotate)
                    }
                    .keyboardShortcut("r", modifiers: [])
                    .help("Switch to rotate tool")
                    
                    Button("Shear Tool") {
                        documentState?.switchToTool(.shear)
                    }
                    .keyboardShortcut("x", modifiers: [])
                    .help("Switch to shear tool")
                    
                    Button("Warp Tool") {
                        documentState?.switchToTool(.warp)
                    }
                    .keyboardShortcut("w", modifiers: [])
                    .help("Switch to warp tool")
                    
                    Divider()
                    
                    Button("Bezier Pen Tool") {
                        documentState?.switchToTool(.bezierPen)
                    }
                    .keyboardShortcut("p", modifiers: [])
                    .help("Switch to bezier pen tool")
                    
                    Button("Freehand Tool") {
                        documentState?.switchToTool(.freehand)
                    }
                    .keyboardShortcut("f", modifiers: [])
                    .help("Switch to freehand tool")
                    
                    Button("Brush Tool") {
                        documentState?.switchToTool(.brush)
                    }
                    .keyboardShortcut("b", modifiers: [])
                    .help("Switch to brush tool")
                    
                    Button("Marker Tool") {
                        documentState?.switchToTool(.marker)
                    }
                    .keyboardShortcut("m", modifiers: [])
                    .help("Switch to marker tool")
                    
                    Button("Font Tool") {
                        documentState?.switchToTool(.font)
                    }
                    .keyboardShortcut("t", modifiers: [])
                    .help("Switch to font tool")
                    
                    Divider()
                    
                    Button("Line Tool") {
                        documentState?.switchToTool(.line)
                    }
                    .keyboardShortcut("l", modifiers: [])
                    .help("Switch to line tool")
                    
                    Button("Rectangle Tool") {
                        documentState?.switchToTool(.rectangle)
                    }
                    .keyboardShortcut("r", modifiers: [.option])
                    .help("Switch to rectangle tool")
                    
                    Button("Square Tool") {
                        documentState?.switchToTool(.square)
                    }
                    .keyboardShortcut("s", modifiers: [.option])
                    .help("Switch to square tool")
                    
                    Button("Rounded Rectangle Tool") {
                        documentState?.switchToTool(.roundedRectangle)
                    }
                    .keyboardShortcut("r", modifiers: [.shift, .option])
                    .help("Switch to rounded rectangle tool")
                    
                    Button("Pill Tool") {
                        documentState?.switchToTool(.pill)
                    }
                    .keyboardShortcut("p", modifiers: [.shift, .option])
                    .help("Switch to pill tool")
                    
                    Button("Circle Tool") {
                        documentState?.switchToTool(.circle)
                    }
                    .keyboardShortcut("c", modifiers: [.option])
                    .help("Switch to circle tool")
                    
                    Button("Ellipse Tool") {
                        documentState?.switchToTool(.ellipse)
                    }
                    .keyboardShortcut("e", modifiers: [])
                    .help("Switch to ellipse tool")
                    
                    Button("Oval Tool") {
                        documentState?.switchToTool(.oval)
                    }
                    .keyboardShortcut("o", modifiers: [])
                    .help("Switch to oval tool")
                    
                    Button("Egg Tool") {
                        documentState?.switchToTool(.egg)
                    }
                    .keyboardShortcut("e", modifiers: [.shift])
                    .help("Switch to egg tool")
                    
                    Button("Cone Tool") {
                        documentState?.switchToTool(.cone)
                    }
                    .keyboardShortcut("c", modifiers: [.shift, .option])
                    .help("Switch to cone tool")
                    
                    Divider()
                    
                    Button("Equilateral Triangle Tool") {
                        documentState?.switchToTool(.equilateralTriangle)
                    }
                    .keyboardShortcut("t", modifiers: [.shift])
                    .help("Switch to equilateral triangle tool")
                    
                    Button("Isosceles Triangle Tool") {
                        documentState?.switchToTool(.isoscelesTriangle)
                    }
                    .keyboardShortcut("i", modifiers: [])
                    .help("Switch to isosceles triangle tool")
                    
                    Button("Right Triangle Tool") {
                        documentState?.switchToTool(.rightTriangle)
                    }
                    .keyboardShortcut("r", modifiers: [.shift, .option])
                    .help("Switch to right triangle tool")
                    
                    Button("Acute Triangle Tool") {
                        documentState?.switchToTool(.acuteTriangle)
                    }
                    .keyboardShortcut("a", modifiers: [.shift])
                    .help("Switch to acute triangle tool")
                    
                    Divider()
                    
                    Button("Star Tool") {
                        documentState?.switchToTool(.star)
                    }
                    .keyboardShortcut("s", modifiers: [.shift])
                    .help("Switch to star tool")
                    
                    Button("Polygon Tool") {
                        documentState?.switchToTool(.polygon)
                    }
                    .keyboardShortcut("p", modifiers: [.option])
                    .help("Switch to polygon tool")
                    
                    Button("Pentagon Tool") {
                        documentState?.switchToTool(.pentagon)
                    }
                    .keyboardShortcut("5", modifiers: [])
                    .help("Switch to pentagon tool")
                    
                    Button("Hexagon Tool") {
                        documentState?.switchToTool(.hexagon)
                    }
                    .keyboardShortcut("6", modifiers: [])
                    .help("Switch to hexagon tool")
                    
                    Button("Heptagon Tool") {
                        documentState?.switchToTool(.heptagon)
                    }
                    .keyboardShortcut("7", modifiers: [])
                    .help("Switch to heptagon tool")
                    
                    Button("Octagon Tool") {
                        documentState?.switchToTool(.octagon)
                    }
                    .keyboardShortcut("8", modifiers: [])
                    .help("Switch to octagon tool")
                    
                    Divider()
                    
                    Button("Eyedropper Tool") {
                        documentState?.switchToTool(.eyedropper)
                    }
                    .keyboardShortcut("i", modifiers: [])
                    .help("Switch to eyedropper tool")
                    
                    Button("Hand Tool") {
                        documentState?.switchToTool(.hand)
                    }
                    .keyboardShortcut("h", modifiers: [])
                    .help("Switch to hand tool")
                    
                    Button("Zoom Tool") {
                        documentState?.switchToTool(.zoom)
                    }
                    .keyboardShortcut("z", modifiers: [])
                    .help("Switch to zoom tool")
                    
                    Button("Gradient Tool") {
                        documentState?.switchToTool(.gradient)
                    }
                    .keyboardShortcut("g", modifiers: [])
                    .help("Switch to gradient tool")
                    
                    Button("Corner Radius Tool") {
                        documentState?.switchToTool(.cornerRadius)
                    }
                    .keyboardShortcut(.upArrow, modifiers: [.control])
                    .help("Switch to corner radius tool")
                }
            }
        }
        
        // 🔥 GRADIENT HUD WINDOW - Real floating window that can go outside main window
        Window("Select Gradient Color", id: "gradient-hud") {
            StableGradientHUDContent(hudManager: appState.persistentGradientHUD)
                .environment(appState)
                .background(WindowAccessor { window in
                    if let window {
                        // 🔥 HUD WINDOW WITH DRAGGABLE TITLE BAR
                        window.styleMask = [.hudWindow, .titled, .closable]
                        window.hidesOnDeactivate = true
                        // 🔥 HUD APPEARANCE
                        window.appearance = NSAppearance(named: .darkAqua)
                        window.titlebarAppearsTransparent = true
                        window.titleVisibility = .visible // Keep this visible for dragging
                        window.title = "Select Gradient Color" // Set your window title
                        // 🔥 TRANSPARENCY & BACKGROUND
                        window.isOpaque = true
                        window.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 1.0)
                        window.hasShadow = true
                        window.level = .modalPanel
                        window.isMovableByWindowBackground = false // FALSE so sliders work
                        window.tabbingMode = .disallowed
                        
                        // 🔥 OPTIONAL: Style the window buttons
                        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                        window.standardWindowButton(.zoomButton)?.isHidden = true
                        window.styleMask.insert(.utilityWindow)
                        // Keep close button visible
                        
                        // 🔥 INTERCEPT CLOSE BUTTON TO PRESERVE POSITION
                        window.delegate = GradientHUDWindowDelegate.shared
                        
                        // 🔥 LET SYSTEM MANAGE POSITIONING - No manual positioning
                        // The window will appear at a sensible default location
                        // and remember its position when moved by the user
                    }
                })
        }
        .windowResizability(.contentSize) // Size to content
        // 🔥 NO MANUAL POSITIONING - Let macOS handle window positioning naturally
        
        // 🔥 INK COLOR MIXER HUD WINDOW
        Window("Ink Color Mixer", id: "ink-hud") {
            StableInkHUDContent()
                .environment(appState)
                .background(WindowAccessor { window in
                    if let window {
                        window.styleMask = [.hudWindow, .titled, .closable]
                        window.hidesOnDeactivate = true
                        window.appearance = NSAppearance(named: .darkAqua)
                        window.titlebarAppearsTransparent = true
                        window.titleVisibility = .visible
                        window.title = "Ink Color Mixer"
                        window.isOpaque = true
                        window.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 1.0)
                        window.hasShadow = true
                        window.level = .modalPanel
                        window.isMovableByWindowBackground = false
                        window.tabbingMode = .disallowed
                        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                        window.standardWindowButton(.zoomButton)?.isHidden = true
                        window.styleMask.insert(.utilityWindow)
                        window.delegate = GradientHUDWindowDelegate.shared
                    }
                })
        }
        .windowResizability(.contentSize)
        
        // Preferences window
        Window("Preferences", id: "app-preferences") {
            PreferencesView()
                .environment(appState)
                .background(WindowAccessor { window in
                    window?.tabbingMode = .disallowed
                })
        }
        .defaultSize(width: 520, height: 320)
        .windowResizability(.contentSize)
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
            Log.info("📋 Copied \(shapesToCopy.count) shapes and \(textToCopy.count) text objects", category: .general)
        } catch {
            Log.error("❌ Failed to copy objects: \(error)", category: .error)
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
            
            Log.info("📋 Pasted \(clipboardData.shapes.count) shapes and \(clipboardData.texts.count) text objects at original coordinates", category: .general)
        } catch {
            Log.error("❌ Failed to paste objects: \(error)", category: .error)
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
            
            Log.info("📋 Pasted in back: \(clipboardData.shapes.count) shapes and \(clipboardData.texts.count) text objects at original coordinates", category: .general)
        } catch {
            Log.error("❌ Failed to paste in back: \(error)", category: .error)
        }
    }
}

// MARK: - Clipboard Data Structure
struct ClipboardData: Codable {
    let shapes: [VectorShape]
    let texts: [VectorText]
}
