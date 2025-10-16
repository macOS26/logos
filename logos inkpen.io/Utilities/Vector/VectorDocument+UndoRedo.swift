import SwiftUI
import Combine

extension VectorDocument {

    func executeCommand(_ command: Command) {
        commandManager.execute(command)
    }

    func undo() {
        if commandManager.canUndo {
            commandManager.undo()
            objectWillChange.send()
            NotificationCenter.default.post(name: Notification.Name("ClearPreviewStates"), object: nil)
            return
        }

        objectWillChange.send()
        NotificationCenter.default.post(name: Notification.Name("ClearPreviewStates"), object: nil)

        cleanupImageRegistry()
    }

    func redo() {
        if commandManager.canRedo {
            commandManager.redo()
            objectWillChange.send()
            return
        }

        cleanupImageRegistry()
    }
}
