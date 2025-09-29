//
//  DocumentState.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

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
        Log.info("🎯 DocumentState initialized with automatic menu state updates")
        // Defer observer setup until document is set to prevent blocking during launch
        
        // Register with central registry (no notifications)
        DocumentStateRegistry.shared.register(self)
    }
    
    deinit {
        // CRITICAL: Clean up all subscriptions to prevent retain cycles
        cancellables.removeAll()
        Log.info("🎯 DocumentState deallocated - subscriptions cleaned up")
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
        Log.info("🎯 DocumentState cleanup completed")
    }
    
    func forceCleanup() {
        // Force cleanup called from app termination
        Log.info("🎯 DocumentState force cleanup initiated")
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
        
        Log.info("🎯 DocumentState force cleanup completed")
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
            Log.info("🎯 DocumentState: Skipping state update during termination")
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
        
        // AUTOMATIC STATE CALCULATION - REFACTORED: Use unified objects system
        canUndo = !document.undoStack.isEmpty
        canRedo = !document.redoStack.isEmpty
        hasSelection = !document.selectedObjectIDs.isEmpty
        canCut = hasSelection
        canCopy = hasSelection
        canPaste = ClipboardManager.shared.canPaste()
        
        // REFACTORED: Use unified objects system for selection-based operations
        func isShape(_ unifiedObject: VectorObject) -> Bool {
            switch unifiedObject.objectType {
            case .shape: return true
            }
        }
        
        let selectedShapes = document.unifiedObjects.filter { unifiedObject in
            document.selectedObjectIDs.contains(unifiedObject.id) && isShape(unifiedObject)
        }
        let selectedShapeCount = selectedShapes.count
        
        canGroup = selectedShapeCount > 1
        canUngroup = selectedShapes.contains { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isGroupContainer
            }
            return false
        }
        canFlatten = selectedShapeCount > 1
        canUnflatten = selectedShapeCount == 1 && selectedShapes.contains { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isGroup
            }
            return false
        }
        canMakeCompoundPath = selectedShapeCount > 1
        canReleaseCompoundPath = selectedShapeCount == 1 && selectedShapes.contains { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType {
                // Only release if it's a true compound path (even-odd fill rule)
                return shape.isTrueCompoundPath
            }
            return false
        }
        canMakeLoopingPath = selectedShapeCount > 1
        canReleaseLoopingPath = selectedShapeCount == 1 && selectedShapes.contains { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType {
                // Only release if it's a true looping path (winding fill rule)
                return shape.isTrueLoopingPath
            }
            return false
        }
        canUnwrapWarpObject = selectedShapeCount == 1 && selectedShapes.contains { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isWarpObject
            }
            return false
        }
        canExpandWarpObject = selectedShapeCount == 1 && selectedShapes.contains { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isWarpObject
            }
            return false
        }
        // Links menu enablement: any selected shape with a linked image or a raster image in registry
        canEmbedLinkedImages = {
            for unifiedObject in selectedShapes {
                if case .shape(let shape) = unifiedObject.objectType {
                    if shape.linkedImagePath != nil { return true }
                    if ImageContentRegistry.containsImage(shape) { return true }
                }
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
            .png,
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
                            var newObjectIDs: Set<UUID> = []
                            for shape in result.shapes {
                                // CRITICAL FIX: Use VectorDocument.addShape to ensure unified system is updated
                                document.addShape(shape, to: layerIndex)
                                newObjectIDs.insert(shape.id)
                            }
                            // REFACTORED: Use unified objects system for selection
                            document.selectedObjectIDs = newObjectIDs
                            document.syncSelectionArrays()
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
    
    func exportSVG() {
        guard let document = document else { return }

        let panel = NSSavePanel()
        panel.title = "Export SVG"
        panel.nameFieldStringValue = "Untitled.svg"
        panel.allowedContentTypes = [.svg]
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.isExtensionHidden = false  // Show .svg extension
        panel.message = "Export as SVG (Scalable Vector Graphics)"

        // Create accessory view for background option
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))

        // Background checkbox
        let bgCheckbox = NSButton(checkboxWithTitle: "Include background",
                                   target: nil, action: nil)
        bgCheckbox.frame = NSRect(x: 20, y: 20, width: 200, height: 20)
        bgCheckbox.state = .off // Default to no background for SVG
        accessoryView.addSubview(bgCheckbox)

        panel.accessoryView = accessoryView

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            // Get background option
            let includeBackground = bgCheckbox.state == .on

            Task {
                do {
                    // Generate SVG content with background option
                    let svgContent = try SVGExporter.shared.exportToSVG(document, includeBackground: includeBackground)

                    // Write to file
                    try svgContent.write(to: url, atomically: true, encoding: .utf8)

                    await MainActor.run {
                        Log.info("✅ Exported SVG to: \(url.path) (background: \(includeBackground))", category: .fileOperations)
                    }
                } catch {
                    await MainActor.run {
                        Log.error("❌ Failed to export SVG: \(error)", category: .error)

                        let alert = NSAlert()
                        alert.messageText = "Export Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .critical
                        alert.runModal()
                    }
                }
            }
        }
    }

    func exportPDF() {
        // FIXED: Now using the same code as Save As PDF with background toggle
        guard let document = document else { return }

        let panel = NSSavePanel()
        panel.title = "Export PDF"
        panel.nameFieldStringValue = "Untitled.pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.isExtensionHidden = false  // Show .pdf extension
        panel.message = "Export as PDF (Portable Document Format)"

        // Create accessory view for background and CMYK options
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 90))

        // CMYK checkbox
        let cmykCheckbox = NSButton(checkboxWithTitle: "Use CMYK color space",
                                     target: nil, action: nil)
        cmykCheckbox.frame = NSRect(x: 20, y: 50, width: 250, height: 20)
        cmykCheckbox.state = .off // Default to regular gradient
        accessoryView.addSubview(cmykCheckbox)

        // Background checkbox
        let bgCheckbox = NSButton(checkboxWithTitle: "Include background (Canvas layer)",
                                   target: nil, action: nil)
        bgCheckbox.frame = NSRect(x: 20, y: 20, width: 250, height: 20)
        bgCheckbox.state = .off // Default to no background for PDF export
        accessoryView.addSubview(bgCheckbox)

        panel.accessoryView = accessoryView

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            // Get export options
            let useCMYK = cmykCheckbox.state == .on
            _ = bgCheckbox.state // TODO: Update generatePDFData to support includeBackground parameter

            Task {
                do {
                    // Use appropriate PDF generation based on CMYK option
                    let pdfData = try FileOperations.generatePDFDataForExport(from: document, useCMYK: useCMYK)

                    // Write the PDF data to file
                    try pdfData.write(to: url)

                    await MainActor.run {
                        Log.info("✅ Exported PDF to: \(url.path) using Save As PDF code", category: .fileOperations)
                    }
                } catch {
                    await MainActor.run {
                        Log.error("❌ Failed to export PDF: \(error)", category: .error)

                        let alert = NSAlert()
                        alert.messageText = "Export Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .critical
                        alert.runModal()
                    }
                }
            }
        }
    }

    func exportPNG() {
        guard let document = document else { return }

        let panel = NSSavePanel()
        panel.title = "Export PNG"
        panel.nameFieldStringValue = "Untitled.png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.message = "Export as PNG (Portable Network Graphics)"

        // Create accessory view for options
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 140))

        // Icon set checkbox
        let iconCheckbox = NSButton(checkboxWithTitle: "Export as Icon Set",
                                    target: nil, action: nil)
        iconCheckbox.frame = NSRect(x: 20, y: 100, width: 200, height: 20)
        iconCheckbox.state = .off
        accessoryView.addSubview(iconCheckbox)

        // Icon sizes label (initially hidden)
        let iconSizesLabel = NSTextField(labelWithString: "Sizes: 1024×1024, 512×512, 256×256, 128×128, 64×64, 32×32, 16×16 px")
        iconSizesLabel.frame = NSRect(x: 40, y: 75, width: 300, height: 20)
        iconSizesLabel.font = NSFont.systemFont(ofSize: 10)
        iconSizesLabel.textColor = NSColor.secondaryLabelColor
        iconSizesLabel.isHidden = true
        accessoryView.addSubview(iconSizesLabel)

        // Scale control
        let scaleLabel = NSTextField(labelWithString: "Scale:")
        scaleLabel.frame = NSRect(x: 20, y: 45, width: 50, height: 20)
        accessoryView.addSubview(scaleLabel)

        let scalePopup = NSPopUpButton(frame: NSRect(x: 75, y: 43, width: 150, height: 25))

        // Check if app is sandboxed using common utility
        if SandboxChecker.isSandboxed {
            // Sandboxed: show standard scales and individual icon sizes
            scalePopup.addItems(withTitles: [
                "1x", "2x", "3x", "4x",
                "1024×1024 icon",
                "512×512 icon",
                "256×256 icon",
                "128×128 icon",
                "64×64 icon",
                "32×32 icon",
                "16×16 icon"
            ])
        } else {
            // Not sandboxed: include Icon Set option for batch export
            scalePopup.addItems(withTitles: ["1x", "2x", "3x", "4x", "Icon Set"])
        }

        scalePopup.selectItem(withTitle: "2x") // Default to 2x
        accessoryView.addSubview(scalePopup)

        // Background checkbox
        let bgCheckbox = NSButton(checkboxWithTitle: "Include background",
                                   target: nil, action: nil)
        bgCheckbox.frame = NSRect(x: 20, y: 10, width: 200, height: 20)
        bgCheckbox.state = .off // Default to transparent background
        accessoryView.addSubview(bgCheckbox)

        // Setup icon checkbox action to show/hide options
        iconCheckbox.target = iconCheckbox
        iconCheckbox.action = #selector(NSButton.performClick(_:))
        iconCheckbox.sendAction(on: .leftMouseUp)

        // Create a simple handler using objc runtime
        class IconCheckboxHandler: NSObject {
            let scaleLabel: NSTextField
            let scalePopup: NSPopUpButton
            let bgCheckbox: NSButton
            let iconSizesLabel: NSTextField
            let iconCheckbox: NSButton

            init(scaleLabel: NSTextField, scalePopup: NSPopUpButton, bgCheckbox: NSButton, iconSizesLabel: NSTextField, iconCheckbox: NSButton) {
                self.scaleLabel = scaleLabel
                self.scalePopup = scalePopup
                self.bgCheckbox = bgCheckbox
                self.iconSizesLabel = iconSizesLabel
                self.iconCheckbox = iconCheckbox
            }

            @objc func toggleIconMode(_ sender: NSButton) {
                let isIconMode = sender.state == .on
                scaleLabel.isHidden = isIconMode
                scalePopup.isHidden = isIconMode
                bgCheckbox.isHidden = isIconMode
                iconSizesLabel.isHidden = !isIconMode

                if isIconMode {
                    bgCheckbox.state = .off // Icons never have background
                    scalePopup.selectItem(withTitle: "Icon Set")
                }
            }

            @objc func scaleChanged(_ sender: NSPopUpButton) {
                let selectedItem = sender.titleOfSelectedItem ?? ""
                let isIconOption = selectedItem == "Icon Set" || selectedItem.contains("icon")

                if isIconOption {
                    iconCheckbox.state = .on
                    bgCheckbox.isHidden = true
                    bgCheckbox.state = .off
                    iconSizesLabel.isHidden = selectedItem.contains("×") // Hide for individual sizes
                } else {
                    iconCheckbox.state = .off
                    bgCheckbox.isHidden = false
                    iconSizesLabel.isHidden = true
                }
            }
        }

        let handler = IconCheckboxHandler(scaleLabel: scaleLabel, scalePopup: scalePopup,
                                         bgCheckbox: bgCheckbox, iconSizesLabel: iconSizesLabel,
                                         iconCheckbox: iconCheckbox)
        iconCheckbox.target = handler
        iconCheckbox.action = #selector(IconCheckboxHandler.toggleIconMode(_:))
        scalePopup.target = handler
        scalePopup.action = #selector(IconCheckboxHandler.scaleChanged(_:))

        // Keep handler alive
        objc_setAssociatedObject(accessoryView, "handler", handler, .OBJC_ASSOCIATION_RETAIN)

        panel.accessoryView = accessoryView

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            // Check if icon set mode is enabled (either via checkbox or dropdown)
            let selectedScale = scalePopup.titleOfSelectedItem ?? "2x"
            let isIconMode = iconCheckbox.state == .on || selectedScale == "Icon Set"

            if isIconMode {
                // For icon set, we need a folder not a file
                let folderURL = url.deletingLastPathComponent()

                Task {
                    do {
                        try FileOperations.exportIconSet(document, folderURL: folderURL)

                        await MainActor.run {
                            Log.info("✅ Exported icon set to: \(folderURL.path)",
                                    category: .fileOperations)
                        }
                    } catch {
                        await MainActor.run {
                            Log.error("❌ Failed to export icon set: \(error)", category: .error)

                            let alert = NSAlert()
                            alert.messageText = "Export Failed"
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .critical
                            alert.runModal()
                        }
                    }
                }
            } else {
                // Regular PNG export or individual icon export
                let selectedOption = scalePopup.titleOfSelectedItem ?? "2x"

                // Check if it's an individual icon size
                if selectedOption.contains("icon") {
                    // Extract size from string like "1024×1024 icon"
                    let sizeString = selectedOption.replacingOccurrences(of: " icon", with: "")
                    let pixelSize = Int(sizeString.split(separator: "×")[0]) ?? 512

                    Task {
                        do {
                            // Export single icon size with transparent background
                            try FileOperations.exportSingleIcon(document, url: url, pixelSize: pixelSize)

                            await MainActor.run {
                                Log.info("✅ Exported \(pixelSize)×\(pixelSize) icon to: \(url.path)",
                                        category: .fileOperations)
                            }
                        } catch {
                            await MainActor.run {
                                Log.error("❌ Failed to export icon: \(error)", category: .error)

                                let alert = NSAlert()
                                alert.messageText = "Export Failed"
                                alert.informativeText = error.localizedDescription
                                alert.alertStyle = .critical
                                alert.runModal()
                            }
                        }
                    }
                } else {
                    // Standard scale export (1x, 2x, 3x, 4x)
                    let scale = CGFloat(Int(selectedOption.dropLast()) ?? 2)
                    let includeBackground = bgCheckbox.state == .on

                    Task {
                        do {
                            try FileOperations.exportToPNG(document, url: url, scale: scale,
                                                            includeBackground: includeBackground)

                            await MainActor.run {
                                Log.info("✅ Exported PNG to: \(url.path) (scale: \(scale)x, background: \(includeBackground))",
                                        category: .fileOperations)
                            }
                        } catch {
                            await MainActor.run {
                                Log.error("❌ Failed to export PNG: \(error)", category: .error)

                                let alert = NSAlert()
                                alert.messageText = "Export Failed"
                                alert.informativeText = error.localizedDescription
                                alert.alertStyle = .critical
                                alert.runModal()
                            }
                        }
                    }
                }
            }
        }
    }

    func exportAutoDeskSVG() {
        guard let document = document else { return }

        let panel = NSSavePanel()
        panel.title = "Export AutoDesk SVG"
        panel.nameFieldStringValue = "Untitled.svg"
        panel.allowedContentTypes = [.svg]
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.isExtensionHidden = false  // Show .svg extension
        panel.message = "Export SVG at 96 DPI for AutoDesk applications"

        // Create accessory view for background option
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))

        // Background checkbox
        let bgCheckbox = NSButton(checkboxWithTitle: "Include background",
                                   target: nil, action: nil)
        bgCheckbox.frame = NSRect(x: 20, y: 20, width: 200, height: 20)
        bgCheckbox.state = .off // Default to no background for SVG
        accessoryView.addSubview(bgCheckbox)

        panel.accessoryView = accessoryView

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            // Get background option
            let includeBackground = bgCheckbox.state == .on

            Task {
                do {
                    // Generate SVG content with 96 DPI scaling using proper exporter
                    let svgContent = try SVGExporter.shared.exportToAutoDeskSVG(document, includeBackground: includeBackground)

                    // Write to file
                    try svgContent.write(to: url, atomically: true, encoding: .utf8)

                    await MainActor.run {
                        Log.info("✅ Exported AutoDesk SVG to: \(url.path) (background: \(includeBackground))", category: .fileOperations)
                    }
                } catch {
                    await MainActor.run {
                        Log.error("❌ Failed to export AutoDesk SVG: \(error)", category: .error)
                        
                        let alert = NSAlert()
                        alert.messageText = "Export Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .critical
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
        // REFACTORED: Use unified objects system for deselection
        document?.selectedObjectIDs.removeAll()
        updateAllStates()
    }
    
    func delete() {
        guard let document = document else { return }
        document.saveToUndoStack()
        
        // CRITICAL FIX: Use unified objects system for deletion
        document.removeSelectedObjects()
        
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

    func toggleColorKeylineView() {
        guard let doc = document else { return }
        if doc.viewMode == .color {
            doc.viewMode = .keyline
            Log.info("📝 MENU: Toggled to Keyline View", category: .general)
        } else {
            doc.viewMode = .color
            Log.info("🎨 MENU: Toggled to Color View", category: .general)
        }
    }

    func toggleRulers() {
        document?.showRulers.toggle()
        Log.info("📏 MENU: Rulers \(document?.showRulers == true ? "shown" : "hidden")", category: .general)
    }
    
    func toggleGrid() {
        // Toggle both settings.showGrid and the actual showGrid property
        document?.settings.showGrid.toggle()
        document?.showGrid = document?.settings.showGrid ?? false
        Log.info("🔲 MENU: Grid \(document?.showGrid == true ? "shown" : "hidden")", category: .general)
    }

    func toggleSnapToGrid() {
        // Toggle snap to grid
        document?.snapToGrid.toggle()
        // Also sync with settings
        document?.settings.snapToGrid = document?.snapToGrid ?? false
        Log.info("🧲 MENU: Snap to Grid \(document?.snapToGrid == true ? "enabled" : "disabled")", category: .general)
    }

    func toggleSnapToPoint() {
        // Toggle snap to point
        document?.snapToPoint.toggle()
        // Also sync with settings if needed
        document?.settings.snapToPoint = document?.snapToPoint ?? false
        Log.info("📍 MENU: Snap to Point \(document?.snapToPoint == true ? "enabled" : "disabled")", category: .general)
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
            let shapes = document.getShapesForLayer(layerIndex)
            for shapeIndex in shapes.indices {
                guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
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
                // Use unified helper to update shape with embedded image data
                document.updateEntireShapeInUnified(id: shape.id) { updatedShape in
                    updatedShape.embeddedImageData = data
                    // Keep link path for reference; user can manually clear if desired
                }
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

        // Update the shared ToolGroupManager to reflect the new tool selection
        ToolGroupManager.shared.handleKeyboardToolSwitch(tool: tool)
        
        Log.info("🛠️ MENU: Switched from \(previousTool.rawValue) to \(tool.rawValue)", category: .general)
    }
}
