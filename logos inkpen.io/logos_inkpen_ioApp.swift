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
    }
    
    func setDocument(_ document: VectorDocument) {
        self.document = document
        updateAllStates()
        
        // Observe document changes for automatic updates
        setupDocumentObservers()
    }
    
    private func setupDocumentObservers() {
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

// MARK: - DocumentBasedContentView (integrates DocumentGroup with MainView)
struct DocumentBasedContentView: View {
    @Binding var inkpenDocument: InkpenDocument
    
    var body: some View {
        DocumentBasedMainView(document: inkpenDocument.document)
    }
}

// MARK: - DocumentBasedMainView (MainView that accepts external document)
struct DocumentBasedMainView: View {
    @ObservedObject var document: VectorDocument // External document from DocumentGroup
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
        VStack(spacing: 0) {
            
            // MAIN CONTENT: Using EXACT same structure as MainView
            GeometryReader { geometry in
                ZStack {
                    // Background - subtle texture
                    Color(NSColor.textBackgroundColor)
                        .zIndex(0)
                    
                    // Drawing Canvas - EXACTLY as in MainView
                    DrawingCanvas(document: document)
                        .zIndex(1) // CRITICAL: Canvas below panels but above background
                        .allowsHitTesting(true) // CRITICAL: Ensure gesture capture everywhere
                    
                    // Rulers - CRITICAL: Above canvas but below panels (EXACT MainView structure)
                    RulersView(document: document, geometry: geometry)
                        .zIndex(50) // CRITICAL: Rulers above canvas but below toolbar/panels
                        .allowsHitTesting(false) // CRITICAL: Rulers don't capture gestures
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 400, minHeight: 300) // MINIMUM: Ensure drawing area is never crushed
                
                // Left Vertical Toolbar - EXACTLY as in MainView
                HStack {
                    VerticalToolbar(document: document)
                        .frame(width: 50, alignment: .top)
                        .background(Color(NSColor.controlBackgroundColor))
                        .zIndex(100) // CRITICAL: Toolbar above canvas and rulers
                    
                    Spacer() // Push toolbar to left
                }
                
                // Right Panel - EXACTLY as in MainView
                HStack {
                    Spacer() // Push panel to right
                    
                    RightPanel(document: document)
                        .frame(width: 280) // EXACT same width as MainView
                        .background(Color(NSColor.controlBackgroundColor))
                        .zIndex(75) // CRITICAL: Panel above canvas but below toolbar
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Status Bar at bottom - EXACTLY as in MainView
            StatusBar(document: document)
                .frame(height: 30)
                .zIndex(200)
        }
        .frame(minHeight: 500)
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
                showingSVGTestHarness: $showingSVGTestHarness,
                onRunDiagnostics: runPasteboardDiagnostics
            )
        }
        .onAppear {
            // Connect document to menu system
            documentState.setDocument(document)
            
            // Fit to page after geometry is established
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                document.requestZoom(to: 0.0, mode: .fitToPage)
                print("🔍 DocumentGroup: Applied fit to page")
            }
        }
        .focusedSceneObject(documentState)
    }
    
    // MARK: - Document Operations (simplified for DocumentGroup)
    private func saveDocument() {
        print("💾 DocumentGroup: Save handled by DocumentGroup")
    }
    
    private func saveDocumentAs() {
        print("💾 DocumentGroup: Save As handled by DocumentGroup")
    }
    
    private func openDocument() {
        print("📂 DocumentGroup: Open handled by DocumentGroup")
    }
    
    private func newDocument() {
        print("📄 DocumentGroup: New document handled by DocumentGroup")
    }
    
    private func runPasteboardDiagnostics() {
        print("🔧 DocumentGroup: Running pasteboard diagnostics")
        let report = PasteboardDiagnostics.shared.runDiagnostics(on: document)
        print("📊 Pasteboard Diagnostics: \(report)")
    }
}

@main
struct logos_inken_ioApp: App {
    //@NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @FocusedObject var documentState: DocumentState?
    @State private var appState = AppState()
    
    var body: some Scene {
        // PRIMARY: DocumentGroup handles BOTH new docs AND file opening (preserves all UI)
        DocumentGroup(newDocument: InkpenDocument()) { file in
            DocumentBasedContentView(inkpenDocument: file.$document)
                .environment(appState)
        }
        
        // SECONDARY: WindowGroup for non-document windows (templates, etc.)
        WindowGroup("New Document Setup") {
            ContentView()
                .environment(appState)
        }
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
