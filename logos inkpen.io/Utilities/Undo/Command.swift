import Foundation

/// Protocol for all undoable commands
protocol Command {
    /// Execute the command
    func execute(on document: VectorDocument)

    /// Undo the command
    func undo(on document: VectorDocument)

    /// Optional: Merge with another command if possible (for coalescing similar operations)
    func mergeWith(_ other: Command) -> Command?
}

extension Command {
    /// Default implementation - commands don't merge by default
    func mergeWith(_ other: Command) -> Command? {
        return nil
    }
}

/// Base class for commands that need to store document reference
class BaseCommand: Command {
    func execute(on document: VectorDocument) {
        fatalError("Subclasses must implement execute(on:)")
    }

    func undo(on document: VectorDocument) {
        fatalError("Subclasses must implement undo(on:)")
    }
}
