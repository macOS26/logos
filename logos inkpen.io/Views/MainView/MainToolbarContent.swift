//
//  MainToolbarContent.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

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
        // Only check SELECTED paths for closing, not all paths
        return hasSelectedPathsToClose()
    }
    
    private func closeOpenPaths() {
        // Only close SELECTED paths, not all paths in document
        closeSelectedPaths()
    }
    
    private func hasSelectedPathsToClose() -> Bool {
        // REFACTORED: Use unified objects system for path closing check
        guard !document.selectedObjectIDs.isEmpty else { return false }
        
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    // Skip text objects - they don't have paths to close
                    if shape.isTextObject { continue }
                    
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
        // REFACTORED: Use unified objects system for path closing
        document.saveToUndoStack()
        
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    // Skip text objects - they don't have paths to close
                    if shape.isTextObject { continue }
                    
                    // Find the shape in the layers array and update it
                    if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if let _ = shapes.firstIndex(where: { $0.id == shape.id }) {
                        
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
                            document.updateShapePathUnified(id: shape.id, path: newPath)
                            Log.info("🎯 Closed selected path for shape \(shape.name)", category: .shapes)
                        }
                        }
                    }
                }
            }
        }
        
        // CRITICAL FIX: Refresh unified objects after path changes to trigger UI update
        document.populateUnifiedObjectsFromLayersPreservingOrder()
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
        // REFACTORED: Use unified objects system for selection bounds
        var combinedBounds: CGRect?
        
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                // Only include objects in user layers (>= 2)
                if unifiedObject.layerIndex >= 2 {
                    switch unifiedObject.objectType {
                    case .shape(let shape):
                        let shapeBounds: CGRect
                        if shape.isTextObject {
                            // Text objects use bounds directly (already positioned)
                            shapeBounds = shape.bounds.applying(shape.transform)
                        } else {
                            // Regular shapes use bounds + transform
                            shapeBounds = shape.bounds.applying(shape.transform)
                        }
                        combinedBounds = combinedBounds.map { $0.union(shapeBounds) } ?? shapeBounds
                    }
                }
            }
        }
        return combinedBounds
    }
    
    // MARK: - Professional Object Management Functions (Industry Standards)
    
    private func bringSelectedToFront() {
        document.bringSelectedToFront()
    }
    
    private func bringSelectedForward() {
        document.bringSelectedForward()
    }
    
    private func sendSelectedBackward() {
        document.sendSelectedBackward()
    }
    
    private func sendSelectedToBack() {
        document.sendSelectedToBack()
    }
    
    private func lockSelectedObjects() {
        // REFACTORED: Use unified objects system for locking
        document.saveToUndoStack()
        
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        // Use unified helper for text locking
                        document.lockTextInUnified(id: shape.id)
                    } else {
                        // Find the shape in the layers array and lock it
                        if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {
                            let shapes = document.getShapesForLayer(layerIndex)
                            if let _ = shapes.firstIndex(where: { $0.id == shape.id }) {
                                document.lockShapeInUnified(id: shape.id)
                            }
                        }
                    }
                }
            }
        }
        
        // Clear selection (locked objects can't be selected)
        document.selectedObjectIDs.removeAll()
        
        Log.info("🔒 Locked selected objects", category: .shapes)
    }
    
    private func unlockAllObjects() {
        document.saveToUndoStack()
        
        // Unlock all shapes in all layers
        for layerIndex in document.layers.indices {
            for shape in document.layers[layerIndex].shapes {
                document.unlockShapeInUnified(id: shape.id)
            }
        }
        
        // Unlock all text objects using unified helpers
        for textObject in document.getAllTextObjects() {
            document.unlockTextInUnified(id: textObject.id)
        }
        
        Log.info("🔓 Unlocked all objects", category: .shapes)
    }
    
    private func hideSelectedObjects() {
        // REFACTORED: Use unified objects system for hiding
        document.saveToUndoStack()
        
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        // Use unified helper for text hiding
                        document.hideTextInUnified(id: shape.id)
                    } else {
                        // Find the shape in the layers array and hide it
                        if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {
                            let shapes = document.getShapesForLayer(layerIndex)
                            if let _ = shapes.firstIndex(where: { $0.id == shape.id }) {
                                document.hideShapeInUnified(id: shape.id)
                            }
                        }
                    }
                }
            }
        }
        
        // Clear selection (hidden objects can't be selected)
        document.selectedObjectIDs.removeAll()
        
        Log.info("👁️‍🗨️ Hidden selected objects", category: .shapes)
    }
    
    private func showAllObjects() {
        document.saveToUndoStack()
        
        // Show all shapes in all layers
        for layerIndex in document.layers.indices {
            for shape in document.layers[layerIndex].shapes {
                document.showShapeInUnified(id: shape.id)
            }
        }
        
        // Show all text objects using unified helpers
        for textObject in document.getAllTextObjects() {
            document.showTextInUnified(id: textObject.id)
        }
        
        Log.info("👁️ Showed all objects", category: .shapes)
    }
}