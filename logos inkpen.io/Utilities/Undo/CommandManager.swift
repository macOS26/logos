import Foundation
import Combine

/// Manages command execution and undo/redo stacks
class CommandManager: ObservableObject {
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    private var undoStack: [Command] = []
    private var redoStack: [Command] = []
    private let maxStackSize: Int

    weak var document: VectorDocument?

    init(maxStackSize: Int = 100) {
        self.maxStackSize = maxStackSize
    }

    /// Execute a command and add it to the undo stack
    func execute(_ command: Command) {
        guard let document = document else { return }

        document.isUndoRedoOperation = true
        command.execute(on: document)
        document.rebuildLookupCache()
        document.isUndoRedoOperation = false

        // Try to merge with the last command if possible (for coalescing)
        if let lastCommand = undoStack.last,
           let mergedCommand = lastCommand.mergeWith(command) {
            undoStack[undoStack.count - 1] = mergedCommand
        } else {
            undoStack.append(command)

            // Limit stack size
            if undoStack.count > maxStackSize {
                undoStack.removeFirst()
            }
        }

        // Clear redo stack when new command is executed
        redoStack.removeAll()

        updateState()
        document.objectWillChange.send()
    }

    /// Undo the last command
    func undo() {
        guard let document = document, !undoStack.isEmpty else { return }

        document.isUndoRedoOperation = true
        let command = undoStack.removeLast()
        command.undo(on: document)
        document.rebuildLookupCache()
        redoStack.append(command)
        document.isUndoRedoOperation = false

        updateState()

        // Notify document observers
        document.objectWillChange.send()
        NotificationCenter.default.post(name: Notification.Name("ClearPreviewStates"), object: nil)
    }

    /// Redo the last undone command
    func redo() {
        guard let document = document, !redoStack.isEmpty else { return }

        document.isUndoRedoOperation = true
        let command = redoStack.removeLast()
        command.execute(on: document)
        document.rebuildLookupCache()
        undoStack.append(command)
        document.isUndoRedoOperation = false

        updateState()

        // Notify document observers
        document.objectWillChange.send()
    }

    /// Clear all undo/redo history
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateState()
    }

    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
