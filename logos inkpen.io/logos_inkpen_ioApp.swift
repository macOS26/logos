//
//  logosApp.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

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

// MARK: - FocusedValues for Document Integration
extension FocusedValues {
    struct DocumentFocusedValueKey: FocusedValueKey {
        typealias Value = VectorDocument
    }
    
    var document: VectorDocument? {
        get { self[DocumentFocusedValueKey.self] }
        set { self[DocumentFocusedValueKey.self] = newValue }
    }
}

@main
struct logos_inken_ioApp: App {
    @StateObject private var menuHandler = MenuCommandHandler.shared
    @FocusedValue(\.document) var focusedDocument: VectorDocument?
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(menuHandler)
        }
        .commands {
            // SOLUTION: Create Custom Working Edit Menu (NOT Apple's broken one)
            // Use "Edit " with space to prevent Apple from adding their default back
            CommandMenu("Edit ") {
                Button("Undo") {
                    menuHandler.undo()
                }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(!menuHandler.canUndo)
                
                Button("Redo") {
                    menuHandler.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!menuHandler.canRedo)
                
                Divider()
                
                Button("Cut") {
                    menuHandler.cut()
                }
                .keyboardShortcut("x", modifiers: [.command])
                .disabled(!menuHandler.canCut)
                
                Button("Copy") {
                    menuHandler.copy()
                }
                .keyboardShortcut("c", modifiers: [.command])
                .disabled(!menuHandler.canCopy)
                
                Button("Paste") {
                    menuHandler.paste()
                }
                .keyboardShortcut("v", modifiers: [.command])
                .disabled(!menuHandler.canPaste)
                
                Button("Delete") {
                    menuHandler.delete()
                }
                .keyboardShortcut(.delete)
                .disabled(!menuHandler.hasSelection)
                
                Divider()
                
                Button("Select All") {
                    menuHandler.selectAll()
                }
                .keyboardShortcut("a", modifiers: [.command])
                
                Button("Deselect All") {
                    menuHandler.deselectAll()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(!menuHandler.hasSelection)
            }
            
            // CREATE TOP-LEVEL Object Menu
            CommandMenu("Object") {
                // Arrange Section
                Button("Bring to Front") {
                    menuHandler.bringToFront()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(!menuHandler.hasSelection)
                
                Button("Bring Forward") {
                    menuHandler.bringForward()
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(!menuHandler.hasSelection)
                
                Button("Send Backward") {
                    menuHandler.sendBackward()
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!menuHandler.hasSelection)
                
                Button("Send to Back") {
                    menuHandler.sendToBack()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(!menuHandler.hasSelection)
                
                Divider()
                
                // Group Section
                Button("Group") {
                    menuHandler.groupObjects()
                }
                .keyboardShortcut("g", modifiers: [.command])
                .disabled(!menuHandler.canGroup)
                
                Button("Ungroup") {
                    menuHandler.ungroupObjects()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(!menuHandler.canUngroup)
                
                Divider()
                
                // Transform Section
                Button("Duplicate") {
                    menuHandler.duplicate()
                }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(!menuHandler.hasSelection)
                
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
        .onChange(of: focusedDocument != nil) {
            // Update menu handler when focused document changes
            if let document = focusedDocument {
                menuHandler.setDocument(document)
            }
        }
    }
}

// MARK: - Complete Menu Command Handler (All Functionality Working)
class MenuCommandHandler: ObservableObject {
    static let shared = MenuCommandHandler()
    
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var hasSelection = false
    @Published var canCut = false
    @Published var canCopy = false
    @Published var canPaste = false
    @Published var canGroup = false
    @Published var canUngroup = false
    
    private var currentDocument: VectorDocument?
    
    private init() {
        print("🎯 MenuCommandHandler initialized")
    }
    
    func setDocument(_ document: VectorDocument) {
        currentDocument = document
        updateMenuStates()
    }
    
    func updateMenuStates() {
        guard let document = currentDocument else { return }
        
        canUndo = !document.undoStack.isEmpty
        canRedo = !document.redoStack.isEmpty
        hasSelection = !document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty
        canCut = hasSelection
        canCopy = hasSelection
        canPaste = ClipboardManager.shared.canPaste()
        canGroup = document.selectedShapeIDs.count > 1
        canUngroup = document.selectedShapeIDs.contains { shapeID in
            // Check if any selected shape is a group
            document.layers.flatMap(\.shapes).first { $0.id == shapeID }?.isGroupContainer == true
        }
    }
    
    // MARK: - Edit Commands (Actually Working!)
    func undo() {
        currentDocument?.undo()
        updateMenuStates()
    }
    
    func redo() {
        currentDocument?.redo()
        updateMenuStates()
    }
    
    func cut() {
        guard let document = currentDocument else { return }
        ClipboardManager.shared.cut(from: document)
        updateMenuStates()
    }
    
    func copy() {
        guard let document = currentDocument else { return }
        ClipboardManager.shared.copy(from: document)
        updateMenuStates()
    }
    
    func paste() {
        guard let document = currentDocument else { return }
        ClipboardManager.shared.paste(to: document)
        updateMenuStates()
    }
    
    func selectAll() {
        guard let document = currentDocument else { return }
        document.selectAll()
        updateMenuStates()
    }
    
    func deselectAll() {
        guard let document = currentDocument else { return }
        document.selectedShapeIDs.removeAll()
        document.selectedTextIDs.removeAll()
        updateMenuStates()
    }
    
    func delete() {
        guard let document = currentDocument else { return }
        document.saveToUndoStack()
        
        // Delete selected shapes
        if !document.selectedShapeIDs.isEmpty {
            document.removeSelectedShapes()
        }
        
        // Delete selected text
        if !document.selectedTextIDs.isEmpty {
            document.removeSelectedText()
        }
        
        updateMenuStates()
        print("🗑️ MENU: Deleted selected objects")
    }
    
    // MARK: - Object Commands (Only custom functionality)
    func bringToFront() {
        guard let document = currentDocument else { return }
        document.bringSelectedToFront()
        updateMenuStates()
    }
    
    func bringForward() {
        guard let document = currentDocument else { return }
        document.bringSelectedForward()
        updateMenuStates()
    }
    
    func sendBackward() {
        guard let document = currentDocument else { return }
        document.sendSelectedBackward()
        updateMenuStates()
    }
    
    func sendToBack() {
        guard let document = currentDocument else { return }
        document.sendSelectedToBack()
        updateMenuStates()
    }
    
    func groupObjects() {
        guard let document = currentDocument else { return }
        document.groupSelectedObjects()
        updateMenuStates()
    }
    
    func ungroupObjects() {
        guard let document = currentDocument else { return }
        document.ungroupSelectedObjects()
        updateMenuStates()
    }
    
    func duplicate() {
        guard let document = currentDocument else { return }
        if !document.selectedShapeIDs.isEmpty {
            document.duplicateSelectedShapes()
        } else if !document.selectedTextIDs.isEmpty {
            document.duplicateSelectedText()
        }
        updateMenuStates()
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
            
            // Add shapes to current layer
            if let layerIndex = document.selectedLayerIndex {
                for shape in clipboardData.shapes {
                    var newShape = shape
                    newShape.id = UUID()
                    // Offset pasted objects slightly
                    newShape.path = offsetPath(newShape.path, by: CGPoint(x: 20, y: 20))
                    document.layers[layerIndex].shapes.append(newShape)
                    document.selectedShapeIDs.insert(newShape.id)
                }
            }
            
            // Add text objects
            for text in clipboardData.texts {
                var newText = text
                newText.id = UUID()
                // Offset pasted text slightly
                newText.position = CGPoint(
                    x: newText.position.x + 20,
                    y: newText.position.y + 20
                )
                document.textObjects.append(newText)
                document.selectedTextIDs.insert(newText.id)
            }
            
            print("📋 Pasted \(clipboardData.shapes.count) shapes and \(clipboardData.texts.count) text objects")
        } catch {
            print("❌ Failed to paste objects: \(error)")
        }
    }
    
    private func offsetPath(_ path: VectorPath, by offset: CGPoint) -> VectorPath {
        var newElements: [PathElement] = []
        
        for element in path.elements {
            switch element {
            case .move(let to):
                newElements.append(.move(to: VectorPoint(to.x + offset.x, to.y + offset.y)))
            case .line(let to):
                newElements.append(.line(to: VectorPoint(to.x + offset.x, to.y + offset.y)))
            case .curve(let to, let control1, let control2):
                newElements.append(.curve(
                    to: VectorPoint(to.x + offset.x, to.y + offset.y),
                    control1: VectorPoint(control1.x + offset.x, control1.y + offset.y),
                    control2: VectorPoint(control2.x + offset.x, control2.y + offset.y)
                ))
            case .quadCurve(let to, let control):
                newElements.append(.quadCurve(
                    to: VectorPoint(to.x + offset.x, to.y + offset.y),
                    control: VectorPoint(control.x + offset.x, control.y + offset.y)
                ))
            case .close:
                newElements.append(.close)
            }
        }
        
        return VectorPath(elements: newElements)
    }
}

// MARK: - Clipboard Data Structure
struct ClipboardData: Codable {
    let shapes: [VectorShape]
    let texts: [VectorText]
}
