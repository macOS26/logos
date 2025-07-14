//
//  logosApp.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import Combine

// MARK: - AppDelegate to Remove Default Menus
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillUpdate(_ notification: Notification) {
        if let menu = NSApplication.shared.mainMenu {
            // Remove Apple's default Edit menu (grayed out and useless)
            if let edit = menu.items.first(where: { $0.title == "Edit"}) {
                menu.removeItem(edit)
            }
        }
    }
}

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
        
        print("🔄 Menu states updated automatically: undo=\(canUndo), selection=\(hasSelection)")
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
    
    func duplicate() {
        guard let document = document else { return }
        if !document.selectedShapeIDs.isEmpty {
            document.duplicateSelectedShapes()
        } else if !document.selectedTextIDs.isEmpty {
            document.duplicateSelectedText()
        }
        updateAllStates()
    }
}

@main
struct logos_inken_ioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @FocusedObject var documentState: DocumentState?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // SOLUTION: Create Custom Working Edit Menu with AUTOMATIC STATE UPDATES
            CommandMenu("Edit ") {
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
                
                // Transform Section
                Button("Duplicate") {
                    documentState?.duplicate()
                }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(documentState?.hasSelection != true)
                
                Divider()
                
                // Path Cleanup Section
                Button("Clean Duplicate Points") {
                    NotificationCenter.default.post(name: .cleanupDuplicatePoints, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .help("Remove overlapping points and merge their curve data smoothly")
                
                Button("Clean All Duplicate Points") {
                    NotificationCenter.default.post(name: .cleanupAllDuplicatePoints, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .option])
                .help("Clean duplicate points in all shapes in the document")
                
                Button("Test Duplicate Point Merger") {
                    NotificationCenter.default.post(name: .testDuplicatePointMerger, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift, .option])
                .help("Run a test to verify the duplicate point merger works correctly")
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
