//
//  MainToolbarContent.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import Combine

struct MainToolbarContent: ToolbarContent {
    @ObservedObject var document: VectorDocument
    let appState: AppState
    @Binding var currentDocumentURL: URL?
    @Binding var showingDocumentSettings: Bool
    @Binding var showingColorPicker: Bool
    @Binding var showingImportDialog: Bool
    @Binding var importResult: VectorImportResult?
    @Binding var showingImportProgress: Bool
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
            if let unifiedObject = document.findObject(by: objectID) {
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
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    // Skip text objects - they don't have paths to close
                    if shape.isTextObject { continue }
                    
                    // Find the shape in the layers array and update it
                    if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if shapes.contains(where: { $0.id == shape.id }) {

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
                                // Log.info("🎯 Closed selected path for shape \(shape.name)", category: .shapes)
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
#if DEBUG
            // Development Menu - Only shown in debug builds
            Menu {
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
                
            } label: {
                Image(systemName: "doc.text")
                    .offset(y: 1)  // Lower icon by 2px
            }
            .help("Development Tools")
#endif
            
            // ✅ CLEAN TOOLBAR: No duplicate menu functionality
            // Edit and Object commands are handled by proper menu bar menus only
            
            // Transformation Controls (leftmost position)
            TransformationControls(document: document)
            
            // Corner Radius Controls (next to transformation controls)
            CornerRadiusToolbar(document: document)
            
            // Close Path button (context-sensitive)
            Button {
                closeOpenPaths()
            } label: {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 20))  // 25% larger (was ~16)
                    .offset(y: 1)  // Lower icon by 2px
                    .frame(width: 36, height: 36)  // Larger click area
                    .contentShape(Rectangle())  // Entire frame is clickable
                    .onTapGesture {
                        // Luna Display Stylus compatibility
                        closeOpenPaths()
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Close Open Paths (⌘⇧J)")
            .disabled(!hasOpenPaths())
            
            // View Controls
            Button {
                document.viewMode = document.viewMode == .color ? .keyline : .color
            } label: {
                Image(systemName: document.viewMode.iconName)
                    .font(.system(size: 20))  // 25% larger
                    .foregroundColor(document.viewMode == .keyline ? InkPenUIColors.shared.toolOrange : .primary)
                    .offset(y: 1)  // Lower icon by 2px
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Luna Display Stylus compatibility
                        document.viewMode = document.viewMode == .color ? .keyline : .color
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help(document.viewMode.description)
            
            Button {
                document.showRulers.toggle()
            } label: {
                Image(systemName: document.showRulers ? "ruler.fill" : "ruler")
                    .font(.system(size: 20))  // 25% larger
                    .offset(y: 1)  // Lower icon by 2px
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                
                    .onTapGesture {
                        // Luna Display Stylus compatibility
                        document.showRulers.toggle()
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Toggle Rulers")
            
            Button {
                // Toggle both grid visibility and snapping together
                document.showGrid.toggle()
                document.snapToGrid = document.showGrid
            } label: {
                Image(systemName: document.showGrid ? "grid.circle.fill" : "grid.circle")
                    .font(.system(size: 20))  // 25% larger
                    .offset(y: 1)  // Lower icon by 2px
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Luna Display Stylus compatibility
                        document.showGrid.toggle()
                        document.snapToGrid = document.showGrid
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Toggle Grid")
            
            // Snap page to artwork/selection
            Button {
                onSnapPageToArtwork()
            } label: {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 20))  // 25% larger
                    .offset(y: 1)  // Lower icon by 2px
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Luna Display Stylus compatibility
                        onSnapPageToArtwork()
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Snap Page to Artwork Bounds")
            
            Button {
                onSnapPageToSelection()
            } label: {
                Image(systemName: "selection.pin.in.out")
                    .font(.system(size: 20))  // 25% larger
                    .offset(y: 1)  // Lower icon by 2px
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Luna Display Stylus compatibility
                        onSnapPageToSelection()
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Snap Page to Selection Bounds")
            
            // Document Settings
            Button {
                showingDocumentSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 20))  // 25% larger
                    .offset(y: 1)  // Lower icon by 2px
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Luna Display Stylus compatibility
                        showingDocumentSettings = true
                    }
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Document Settings")
            
            
            
            
            if showingImportProgress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: InkPenUIColors.shared.primaryBlue))
                    .scaleEffect(0.8)
            }
            
            // Performance monitor removed - not working properly
        }
    }
    
    // Performance tracking helper removed - no longer needed
    
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
            if let unifiedObject = document.findObject(by: objectID) {
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
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        // Use unified helper for text locking
                        document.lockTextInUnified(id: shape.id)
                    } else {
                        // Find the shape in the layers array and lock it
                        if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {
                            let shapes = document.getShapesForLayer(layerIndex)
                            if shapes.contains(where: { $0.id == shape.id }) {
                                document.lockShapeInUnified(id: shape.id)
                            }
                        }
                    }
                }
            }
        }
        
        // Clear selection (locked objects can't be selected)
        document.selectedObjectIDs.removeAll()
        
        // Log.info("🔒 Locked selected objects", category: .shapes)
    }
    
    private func unlockAllObjects() {
        document.saveToUndoStack()
        
        // Unlock all shapes using unified objects
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                document.unlockShapeInUnified(id: shape.id)
            }
        }
        
        // Unlock all text objects using unified helpers
        for unifiedObj in document.unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject {
                document.unlockTextInUnified(id: shape.id)
            }
        }
        
        // Log.info("🔓 Unlocked all objects", category: .shapes)
    }
    
    private func hideSelectedObjects() {
        // REFACTORED: Use unified objects system for hiding
        document.saveToUndoStack()
        
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        // Use unified helper for text hiding
                        document.hideTextInUnified(id: shape.id)
                    } else {
                        // Find the shape in the layers array and hide it
                        if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {
                            let shapes = document.getShapesForLayer(layerIndex)
                            if shapes.contains(where: { $0.id == shape.id }) {
                                document.hideShapeInUnified(id: shape.id)
                            }
                        }
                    }
                }
            }
        }
        
        // Clear selection (hidden objects can't be selected)
        document.selectedObjectIDs.removeAll()
        
        // Log.info("👁️‍🗨️ Hidden selected objects", category: .shapes)
    }
    
    private func showAllObjects() {
        document.saveToUndoStack()
        
        // Show all shapes using unified objects
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                document.showShapeInUnified(id: shape.id)
            }
        }
        
        // Show all text objects using unified helpers
        for unifiedObj in document.unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject {
                document.showTextInUnified(id: shape.id)
            }
        }
        
        // Log.info("👁️ Showed all objects", category: .shapes)
    }
}
