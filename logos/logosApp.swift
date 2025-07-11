//
//  logosApp.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

@main
struct logosApp: App {
    @StateObject private var menuHandler = MenuCommandHandler.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(menuHandler)
        }
        .commands {
            // SOLUTION: Consolidated Menu System - NO DUPLICATES!
            
            // 1. REPLACE Edit Menu with Proper Implementation
            CommandGroup(replacing: .textEditing) {
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
            
            // 2. ADD Object Menu AFTER Edit Menu (not as separate CommandMenu)
            CommandGroup(after: .undoRedo) {
                Divider()
                
                Menu("Object") {
                    Group {
                        Text("Arrange")
                            .font(.headline)
                            .disabled(true)
                        
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
                    }
                    
                    Divider()
                    
                    Group {
                        Text("Group")
                            .font(.headline)
                            .disabled(true)
                        
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
                    }
                    
                    Divider()
                    
                    Group {
                        Text("Transform")
                            .font(.headline)
                            .disabled(true)
                        
                        Button("Duplicate") {
                            menuHandler.duplicate()
                        }
                        .keyboardShortcut("d", modifiers: [.command])
                        .disabled(!menuHandler.hasSelection)
                        
                        Button("Delete") {
                            menuHandler.delete()
                        }
                        .keyboardShortcut(.delete)
                        .disabled(!menuHandler.hasSelection)
                    }
                }
            }
            
            // 3. KEEP System View Menu (NO CUSTOM VIEW MENU - eliminates duplicate!)
            // System provides: Show/Hide Toolbar, Show/Hide Sidebar, etc.
            
            // 4. KEEP System Window Menu (NO CUSTOM WINDOW MENU - eliminates duplicate!)
            // System provides: Minimize, Zoom, Bring All to Front, etc.
            
            // 5. ADD Tool Selection Commands
            CommandGroup(after: .toolbar) {
                Menu("Tools") {
                    Button("Selection Tool") {
                        menuHandler.selectTool(.selection)
                    }
                    .keyboardShortcut("v")
                    
                    Button("Direct Selection Tool") {
                        menuHandler.selectTool(.directSelection)
                    }
                    .keyboardShortcut("a")
                    
                    Button("Pen Tool") {
                        menuHandler.selectTool(.bezierPen)
                    }
                    .keyboardShortcut("p")
                    
                    Button("Text Tool") {
                        menuHandler.selectTool(.text)
                    }
                    .keyboardShortcut("t")
                    
                    Button("Hand Tool") {
                        menuHandler.selectTool(.hand)
                    }
                    .keyboardShortcut("h")
                }
            }
        }
    }
}

// MARK: - Centralized Menu Command Handler
class MenuCommandHandler: ObservableObject {
    static let shared = MenuCommandHandler()
    
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var canCut = false
    @Published var canCopy = false
    @Published var canPaste = false
    @Published var hasSelection = false
    @Published var canGroup = false
    @Published var canUngroup = false
    
    private var currentDocument: VectorDocument?
    
    init() {
        // Initialize with default states - menu items start disabled
        canUndo = false
        canRedo = false
        canCut = false
        canCopy = false
        canPaste = false
        hasSelection = false
        canGroup = false
        canUngroup = false
        
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
    
    // MARK: - Edit Commands
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
    
    // MARK: - Object Commands
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
    
    func delete() {
        guard let document = currentDocument else { return }
        if !document.selectedShapeIDs.isEmpty {
            document.removeSelectedShapes()
        } else if !document.selectedTextIDs.isEmpty {
            document.removeSelectedText()
        }
        updateMenuStates()
    }
    
    // MARK: - Tool Commands
    func selectTool(_ tool: DrawingTool) {
        guard let document = currentDocument else { return }
        
        // Safe cursor management
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

// MARK: - Clipboard Manager
class ClipboardManager {
    static let shared = ClipboardManager()
    
    private let pasteboard = NSPasteboard.general
    private let vectorObjectsType = NSPasteboard.PasteboardType("com.logos.vectorobjects")
    
    func canPaste() -> Bool {
        return pasteboard.canReadItem(withDataConformingToTypes: [vectorObjectsType.rawValue])
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

// MARK: - Vector Shape Group Extension removed - group properties now in VectorShape struct
