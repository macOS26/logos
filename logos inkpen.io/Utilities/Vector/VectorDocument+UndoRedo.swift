import SwiftUI
import Combine

extension VectorDocument {

    func executeCommand(_ command: Command) {
        commandManager.execute(command)
    }

    func undo() {
        if commandManager.canUndo {
            commandManager.undo()
            return
        }
        cleanupImageRegistry()
    }

    func redo() {
        if commandManager.canRedo {
            commandManager.redo()
            return
        }

        cleanupImageRegistry()
    }
}
