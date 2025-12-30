import Foundation

class SelectionCommand: BaseCommand {
    private let oldSelectedIDs: Set<UUID>
    private let newSelectedIDs: Set<UUID>
    private let oldOrderedIDs: [UUID]
    private let newOrderedIDs: [UUID]

    init(oldSelectedIDs: Set<UUID>, newSelectedIDs: Set<UUID>,
         oldOrderedIDs: [UUID], newOrderedIDs: [UUID]) {
        self.oldSelectedIDs = oldSelectedIDs
        self.newSelectedIDs = newSelectedIDs
        self.oldOrderedIDs = oldOrderedIDs
        self.newOrderedIDs = newOrderedIDs
    }

    override func execute(on document: VectorDocument) {
        document.viewState.orderedSelectedObjectIDs = newOrderedIDs
        document.viewState.selectedObjectIDs = newSelectedIDs
    }

    override func undo(on document: VectorDocument) {
        document.viewState.orderedSelectedObjectIDs = oldOrderedIDs
        document.viewState.selectedObjectIDs = oldSelectedIDs
    }

    /// Selection commands can merge if they happen in quick succession
    func mergeWith(_ other: Command) -> Command? {
        guard let otherSelection = other as? SelectionCommand else { return nil }
        // Merge consecutive selection changes - keep original old state, use latest new state
        return SelectionCommand(
            oldSelectedIDs: self.oldSelectedIDs,
            newSelectedIDs: otherSelection.newSelectedIDs,
            oldOrderedIDs: self.oldOrderedIDs,
            newOrderedIDs: otherSelection.newOrderedIDs
        )
    }
}
