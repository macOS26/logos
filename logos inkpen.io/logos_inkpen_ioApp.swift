//
//  logosApp.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI


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
            "brushPreviewStyle": AppState.BrushPreviewStyle.fill.rawValue,
            "brushPreviewIsFinal": false
        ])

        // Test Metal Compute Engine on app startup (silently)
        let metalWorking = MetalComputeEngine.testMetalEngine()
        if !metalWorking {
            Log.metal("❌ Metal Engine Failed", level: .error)
        }

        // Debug sandbox status
        print("🎁 App Sandbox Status: \(SandboxChecker.isSandboxed ? "SANDBOXED" : "NOT SANDBOXED")")
        print("🎁 Tip Jar Menu: \(SandboxChecker.isNotSandboxed ? "WILL SHOW" : "HIDDEN")")
    }
    
    fileprivate func doNotRestoreThis(_ window: NSWindow) {
        window.isRestorable = false
        window.restorationClass = nil
        window.tabbingMode = .disallowed
    }

    // Helper to determine window title with visible extensions for certain file types
    private func windowTitle(for fileURL: URL?) -> String {
        guard let fileURL = fileURL else { return "Untitled" }

        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()

        // Show extension for .inkpen, .pdf, and .svg files
        if ["inkpen", "pdf", "svg"].contains(fileExtension) {
            return fileName  // Keep the full name with extension
        } else {
            // For other files, use the name without extension
            return fileURL.deletingPathExtension().lastPathComponent
        }
    }
    
    var body: some Scene {
        // PRIMARY: DocumentGroup handles BOTH new docs AND file opening (preserves all UI)
        DocumentGroup(newDocument: InkpenDocument()) { file in
            DocumentBasedContentView(inkpenDocument: file.$document, fileURL: file.fileURL)
                .environment(appState)
                .navigationTitle(windowTitle(for: file.fileURL))
                .onAppear {
                    // Set up window management for gradient HUD
                    appState.setWindowActions(
                        openWindow: { id in openWindow(id: id) },
                        dismissWindow: { id in dismissWindow(id: id) }
                    )
                }
                .background(WindowAccessor { window in
                    if let window = window {
                        // Enable window frame autosave to remember size and position
                        window.setFrameAutosaveName("InkpenDocumentWindow")
                    }
                })
        }
        .defaultSize(width: 1400, height: 900)  // Set larger default size for document windows
        .windowResizability(.contentSize)
        .commands {
            Group {
                CommandGroup(replacing: .importExport) {
                    Button("Document Setup…") {
                        openWindow(id: "onboarding-setup")
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .help("Open Document Setup to configure document settings")
                    
                    Divider()
                    
                    Button("Import…") {
                        documentState?.showImportDialog()
                    }
                    .keyboardShortcut("i", modifiers: [.command])
                    .help("Import SVG, PDF, PNG")
                    
                    Divider()

                    Button("Export SVG…") {
                        documentState?.exportSVG()
                    }
                    .keyboardShortcut("e", modifiers: [.command])
                    .help("Export as SVG (Scalable Vector Graphics)")

                    Button("Export PDF…") {
                        documentState?.exportPDF()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .help("Export as PDF (Portable Document Format)")

                    Button("Export PNG…") {
                        documentState?.exportPNG()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .control])
                    .help("Export as PNG (Portable Network Graphics)")

                    Divider()

                    Button("Export AutoDesk SVG…") {
                        documentState?.exportAutoDeskSVG()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .option])
                    .help("Export SVG at 96 DPI for AutoDesk applications")
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
                    
                    Button {
                        documentState?.toggleRulers()
                    } label: {
                        HStack {
                            if documentState?.document?.showRulers == true {
                                Image(systemName: "checkmark")
                            }
                            Text("Toggle Rulers")
                        }
                    }
                    .keyboardShortcut("r", modifiers: [.command])

                    Button {
                        documentState?.toggleGrid()
                    } label: {
                        HStack {
                            if documentState?.document?.showGrid == true {
                                Image(systemName: "checkmark")
                            }
                            Text("Toggle Grid")
                        }
                    }
                    .keyboardShortcut("'", modifiers: [.command])

                    Button {
                        documentState?.toggleSnapToGrid()
                    } label: {
                        HStack {
                            if documentState?.document?.snapToGrid == true {
                                Image(systemName: "checkmark")
                            }
                            Text("Toggle Snap to Grid")
                        }
                    }
                    .keyboardShortcut(";", modifiers: [.command])

                    Button {
                        documentState?.toggleSnapToPoint()
                    } label: {
                        HStack {
                            if documentState?.document?.snapToPoint == true {
                                Image(systemName: "checkmark")
                            }
                            Text("Toggle Snap to Point")
                        }
                    }
                    .keyboardShortcut(".", modifiers: [.command])
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

                // Donate menu - only visible when not sandboxed
                if SandboxChecker.isNotSandboxed {
                    CommandMenu("Donate") {
                        Button(action: {
                            if let url = URL(string: "https://www.paypal.com/ncp/payment/3DTH3S7XARK98") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("Tip Jar", systemImage: "dollarsign.circle")
                        }
                        .help("Support the developer with a tip via PayPal")
                    }
         
                    CommandGroup(replacing: .help) {
                        Button(action: {
                            openLogosInkPenHelp()
                        }) {
                            Label("Logos InkPen Help", systemImage: "questionmark.circle")
                        }
                        .keyboardShortcut("?", modifiers: .command)
                        .help("Open Logos InkPen Help documentation")
                    }

                    CommandGroup(after: .help) {
                        Divider()
                        Button(action: {
                            if let url = URL(string: "https://www.paypal.com/ncp/payment/3DTH3S7XARK98") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("Tip Jar", systemImage: "dollarsign.circle")
                        }
                        .help("Support the developer with a tip via PayPal")
                    }
                }
            }

        }
        
        // Document Setup Window - Shows ONLY when:
        // 1. No document windows exist on startup
        // 2. User selects New from menu (MainView handles this)
        Window("Document Setup", id: "onboarding-setup") {
            NewDocumentSetupView(
                isPresented: .constant(true),
                onDocumentCreated: { newDoc, _ in
                    // Store the configured document settings
                    appState.pendingNewDocument = newDoc
                    
                    // Close this onboarding window
                    dismissWindow(id: "onboarding-setup")
                    
                    // Reset the flag
                    appState.shouldShowDocumentSetup = false
                    
                    // Create a new document using DocumentGroup
                    NSDocumentController.shared.newDocument(nil)
                }
            )
            .environment(appState)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
                // CRITICAL: Set isRestorable to false when window becomes key
                // This is the only reliable way to prevent restoration in SwiftUI
                if let window = notification.object as? NSWindow,
                   window.title == "Document Setup" {
                    doNotRestoreThis(window)
                }
            }
            .background(WindowAccessor { window in
                if let window {
                    // Initial setup - but the key notification handler above is what really works
                    doNotRestoreThis(window)
                }
            })
        }
        .defaultSize(width: 900, height: 700)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .handlesExternalEvents(matching: Set<String>()) // DISABLE scene restoration for this window
        
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
                        // Use ColorManager for consistent P3 colors
                        let blackComponents: [CGFloat] = [0, 0, 0, 1]
                        let blackCGColor = CGColor(colorSpace: ColorManager.shared.workingCGColorSpace, components: blackComponents) ?? CGColor(red: 0, green: 0, blue: 0, alpha: 1)
                        window.backgroundColor = NSColor(cgColor: blackCGColor) ?? NSColor.black
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
                        // Use ColorManager for consistent P3 colors
                        let blackComponents: [CGFloat] = [0, 0, 0, 1]
                        let blackCGColor = CGColor(colorSpace: ColorManager.shared.workingCGColorSpace, components: blackComponents) ?? CGColor(red: 0, green: 0, blue: 0, alpha: 1)
                        window.backgroundColor = NSColor(cgColor: blackCGColor) ?? NSColor.black
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
    private let vectorObjectsType = NSPasteboard.PasteboardType("io.logos.logos-inkpen-io.vectorObjects")
    
    private init() {}
    
    func canPaste() -> Bool {
        return pasteboard.data(forType: vectorObjectsType) != nil
    }
    
    func cut(from document: VectorDocument) {
        copy(from: document)
        // REFACTORED: Use unified objects system for deletion
        document.removeSelectedObjects()
    }
    
    func copy(from document: VectorDocument) {
        // REFACTORED: Use unified objects system for copying
        var shapesToCopy: [VectorShape] = []
        var textToCopy: [VectorText] = []
        
        // Collect selected objects from unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        // CRITICAL FIX: Convert VectorShape back to VectorText for proper copy/paste
                        if let textContent = shape.textContent {
                            // Get properties from unified system
                            let originalText = document.findText(by: objectID)
                            let originalAreaSize = originalText?.areaSize ?? shape.areaSize
                            let typography = originalText?.typography ?? shape.typography ?? TypographyProperties(strokeColor: .black, fillColor: .black)
                            
                            // DEBUG: Log what we're copying to identify the issue
                            Log.info("📋 COPY DEBUG: textContent='\(textContent)', originalAreaSize=\(originalAreaSize?.debugDescription ?? "nil"), shapeAreaSize=\(shape.areaSize?.debugDescription ?? "nil")", category: .general)
                            
                            let position = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                            let vectorText = VectorText(
                                content: textContent,
                                typography: typography,
                                position: position,
                                transform: .identity,
                                isVisible: shape.isVisible,
                                isLocked: shape.isLocked,
                                isEditing: false,  // CRITICAL FIX: Never copy editing state - paste should not be in edit mode
                                layerIndex: unifiedObject.layerIndex,
                                cursorPosition: 0,  // Reset cursor position for pasted text
                                areaSize: originalAreaSize  // Use the original text's areaSize, not the shape's
                            )
                            
                            // DEBUG: Log the created VectorText to verify areaSize is preserved
                            Log.info("📋 COPY DEBUG: Created VectorText with content='\(vectorText.content)', areaSize=\(vectorText.areaSize?.debugDescription ?? "nil")", category: .general)
                            
                            // SIZE FIX: VectorText initializer now properly handles areaSize for bounds
                            
                            // Note: VectorText.id will be different since it's let, but we'll assign new ID during paste anyway
                            textToCopy.append(vectorText)
                        }
                    } else {
                        // Regular shape
                        shapesToCopy.append(shape)
                    }
                }
            }
        }
        
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
            
            // REFACTORED: Use unified objects system for selection
            document.selectedObjectIDs.removeAll()
            
            // CRITICAL FIX: Check if target layer is locked before pasting
            if let layerIndex = document.selectedLayerIndex {
                // PROTECT LOCKED LAYERS: Don't paste into locked layers
                if layerIndex < document.layers.count && document.layers[layerIndex].isLocked {
                    Log.error("❌ Cannot paste into locked layer '\(document.layers[layerIndex].name)'", category: .error)
                    return
                }
                
                // PROTECT SYSTEM LAYERS: Don't paste into Canvas or Pasteboard layers
                if layerIndex < document.layers.count {
                    let layerName = document.layers[layerIndex].name
                    if layerName == "Canvas" || layerName == "Pasteboard" {
                        Log.error("❌ Cannot paste into system layer '\(layerName)'", category: .error)
                        return
                    }
                }
                
                for shape in clipboardData.shapes {
                    var newShape = shape
                    newShape.id = UUID()
                    // PASTE AT EXACT ORIGINAL COORDINATES - no offset
                    // Use unified system to add shape (handles both layers array and unified objects)
                    document.addShapeToUnifiedSystem(newShape, layerIndex: layerIndex)
                    document.selectedObjectIDs.insert(newShape.id)
                }
            }
            
            // Add text objects at EXACT original coordinates
            for text in clipboardData.texts {
                var newText = text
                newText.id = UUID()
                
                // DEBUG: Log what we're pasting to identify the issue
                Log.info("📋 PASTE DEBUG: Pasting text with content='\(newText.content)', areaSize=\(newText.areaSize?.debugDescription ?? "nil")", category: .general)
                
                // PASTE AT EXACT ORIGINAL COORDINATES - no offset
                // Add to unified objects system (this also adds to textObjects array)
                document.addTextToUnifiedSystem(newText, layerIndex: document.selectedLayerIndex ?? 2)
                document.selectedObjectIDs.insert(newText.id)
            }
            
            // CRITICAL FIX: Sync selection arrays for compatibility
            document.syncSelectionArrays()
            
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
            
            // REFACTORED: Use unified objects system for selection
            let originalSelectedObjectIDs = document.selectedObjectIDs
            document.selectedObjectIDs.removeAll()
            
            // CRITICAL FIX: Check if target layer is locked before pasting
            if let layerIndex = document.selectedLayerIndex {
                // PROTECT LOCKED LAYERS: Don't paste into locked layers
                if layerIndex < document.layers.count && document.layers[layerIndex].isLocked {
                    Log.error("❌ Cannot paste into locked layer '\(document.layers[layerIndex].name)'", category: .error)
                    return
                }
                
                // PROTECT SYSTEM LAYERS: Don't paste into Canvas or Pasteboard layers
                if layerIndex < document.layers.count {
                    let layerName = document.layers[layerIndex].name
                    if layerName == "Canvas" || layerName == "Pasteboard" {
                        Log.error("❌ Cannot paste into system layer '\(layerName)'", category: .error)
                        return
                    }
                }
                
                // Find the lowest orderID of any selected object (shape or text) to paste behind it
                var insertionPoint = 0
                
                if !originalSelectedObjectIDs.isEmpty {
                    // Find the lowest orderID among selected objects in this layer
                    let selectedObjectsInLayer = document.unifiedObjects.filter {
                        originalSelectedObjectIDs.contains($0.id) && $0.layerIndex == layerIndex
                    }
                    if let lowestOrderID = selectedObjectsInLayer.map({ $0.orderID }).min() {
                        insertionPoint = lowestOrderID
                    }
                }
                
                // FIXED: Properly shift existing objects to make room for new objects behind selected ones
                let numNewObjects = clipboardData.shapes.count + clipboardData.texts.count
                
                // Create new unified objects with shifted orderIDs
                var updatedUnifiedObjects: [VectorObject] = []
                for obj in document.unifiedObjects {
                    if obj.layerIndex == layerIndex && obj.orderID >= insertionPoint {
                        // Create new object with shifted orderID
                        let newOrderID = obj.orderID + numNewObjects
                        switch obj.objectType {
                        case .shape(let shape):
                            let newObj = VectorObject(shape: shape, layerIndex: obj.layerIndex, orderID: newOrderID)
                            updatedUnifiedObjects.append(newObj)
                        }
                    } else {
                        // Keep existing object unchanged
                        updatedUnifiedObjects.append(obj)
                    }
                }
                document.unifiedObjects = updatedUnifiedObjects
                
                // Insert shapes with proper orderID to place them behind selected objects
                for (offset, shape) in clipboardData.shapes.enumerated() {
                    var newShape = shape
                    newShape.id = UUID()
                    
                    // Add to unified objects system with orderID that places it behind selected objects
                    let newOrderID = insertionPoint + offset
                    let unifiedObject = VectorObject(shape: newShape, layerIndex: layerIndex, orderID: newOrderID)
                    document.unifiedObjects.append(unifiedObject)
                    document.selectedObjectIDs.insert(newShape.id)
                }
                
                // Add text objects with proper orderID to place them behind selected objects
                for text in clipboardData.texts {
                    var newText = text
                    newText.id = UUID()
                    // PASTE AT EXACT ORIGINAL COORDINATES - no offset
                    // Add to unified objects system (this handles textObjects array and orderID)
                    document.addTextToUnifiedSystem(newText, layerIndex: layerIndex)
                    
                    // Note: The orderID adjustment for paste behind would need to be handled
                    // in a separate method if needed for proper ordering
                    document.selectedObjectIDs.insert(newText.id)
                }
            }
            
            // CRITICAL FIX: Sync selection arrays for compatibility
            document.syncSelectionArrays()
            
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

// MARK: - Display Monitor for Handling Display Changes

// MARK: - Help Functions

func openLogosInkPenHelp() {
    // Try to open the help book
    let helpBookName = "LogosInkPenHelp"

    // First try to open the bundled Help Book
    if let helpBookPath = Bundle.main.path(forResource: helpBookName, ofType: "help") {
        let helpBookURL = URL(fileURLWithPath: helpBookPath)
        let indexPath = helpBookURL.appendingPathComponent("Contents/Resources/en.lproj/index.html")

        if FileManager.default.fileExists(atPath: indexPath.path) {
            NSWorkspace.shared.open(indexPath)
            Log.info("📚 Opened Help Book at: \(indexPath.path)", category: .general)
        } else {
            // Fallback to opening the help book root
            NSWorkspace.shared.open(helpBookURL)
            Log.warning("📚 Help index not found, opening Help Book root", category: .general)
        }
    } else {
        // If help book not found in bundle, try to open from project directory (for development)
        let projectHelpPath = "/Users/toddbruss/Documents/GitHub/logos/logos inkpen.io/LogosInkPenHelp.help/Contents/Resources/en.lproj/index.html"
        if FileManager.default.fileExists(atPath: projectHelpPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: projectHelpPath))
            Log.info("📚 Opened development Help Book", category: .general)
        } else {
            Log.error("📚 Help Book not found", category: .error)
            // Show an alert
            let alert = NSAlert()
            alert.messageText = "Help Not Available"
            alert.informativeText = "The help documentation could not be found."
            alert.alertStyle = .informational
            alert.runModal()
        }
    }
}

class DisplayMonitor: NSObject {
    static let shared = DisplayMonitor()
    
    private override init() {
        super.init()
        setupDisplayMonitoring()
    }
    
    private func setupDisplayMonitoring() {
        // Monitor for display configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // Monitor for display connection changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationChanged),
            name: NSWindow.didChangeScreenNotification,
            object: nil
        )
    }
    
    @objc private func displayConfigurationChanged(_ notification: Notification) {
        // Logging removed
        
        // Validate all displays after configuration change
        validateDisplays()
        
        // Reposition any floating windows that might be on invalid displays
        repositionFloatingWindows()
    }
    
    private func validateDisplays() {
        let screens = NSScreen.screens
        // Logging removed
        
        for (_, screen) in screens.enumerated() {
            let frame = screen.frame
            let isValid = frame.width > 0 && frame.height > 0 &&
                         !frame.origin.x.isNaN && !frame.origin.y.isNaN &&
                         !frame.width.isNaN && !frame.height.isNaN
            
            if isValid {
                // Logging removed
            } else {
                // Logging removed
            }
        }
    }
    
    private func repositionFloatingWindows() {
        DispatchQueue.main.async {
            // Get valid screen bounds
            guard let mainScreen = NSScreen.main else {
                // Logging removed
                return
            }
            
            let screenFrame = mainScreen.visibleFrame
            
            // Reposition gradient HUD windows
            for window in NSApplication.shared.windows {
                if let identifier = window.identifier?.rawValue, identifier.starts(with: "gradient-hud") {
                    if !screenFrame.intersects(window.frame) {
                        // Logging removed
                        let newFrame = CGRect(
                            x: screenFrame.minX + 50,
                            y: screenFrame.minY + 50,
                            width: window.frame.width,
                            height: window.frame.height
                        )
                        window.setFrame(newFrame, display: true)
                    }
                }
                
                // Reposition ink HUD windows
                if let identifier = window.identifier?.rawValue, identifier.starts(with: "ink-hud") {
                    if !screenFrame.intersects(window.frame) {
                        // Logging removed
                        let newFrame = CGRect(
                            x: screenFrame.minX + 100,
                            y: screenFrame.minY + 100,
                            width: window.frame.width,
                            height: window.frame.height
                        )
                        window.setFrame(newFrame, display: true)
                    }
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
