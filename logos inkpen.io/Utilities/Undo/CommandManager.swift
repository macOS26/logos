import Foundation
import Combine

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

    func execute(_ command: Command) {
        guard let document = document else { return }

        document.isUndoRedoOperation = true
        command.execute(on: document)
        document.rebuildIndexCache()
        document.changeNotifier.notifyGeneralChange()
        document.objectWillChange.send()
        document.isUndoRedoOperation = false

        if let lastCommand = undoStack.last,
           let mergedCommand = lastCommand.mergeWith(command) {
            undoStack[undoStack.count - 1] = mergedCommand
        } else {
            undoStack.append(command)

            if undoStack.count > maxStackSize {
                undoStack.removeFirst()
            }
        }

        redoStack.removeAll()

        updateState()
    }

    func undo() {
        guard let document = document, !undoStack.isEmpty else { return }

        document.isUndoRedoOperation = true
        let command = undoStack.removeLast()
        command.undo(on: document)
        document.rebuildIndexCache()
        document.changeNotifier.notifyGeneralChange()
        document.objectWillChange.send()
        redoStack.append(command)
        document.isUndoRedoOperation = false

        updateState()

        NotificationCenter.default.post(name: Notification.Name("ClearPreviewStates"), object: nil)
    }

    func redo() {
        guard let document = document, !redoStack.isEmpty else { return }

        document.isUndoRedoOperation = true
        let command = redoStack.removeLast()
        command.execute(on: document)
        document.rebuildIndexCache()
        document.changeNotifier.notifyGeneralChange()
        document.objectWillChange.send()
        undoStack.append(command)
        document.isUndoRedoOperation = false

        updateState()
    }

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
