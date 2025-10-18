import SwiftUI
import Combine

/// Lightweight notification system for document changes
/// Avoids copying unifiedObjects array - only sends change signals
final class DocumentChangeNotifier: ObservableObject {

    // MARK: - Change Types

    enum ChangeType {
        case objectModified(UUID)
        case objectAdded(UUID)
        case objectRemoved(UUID)
        case selectionChanged
        case layerChanged
        case multipleObjects(Set<UUID>)
    }

    // MARK: - Publishers

    /// Fires when any object changes - sends only the ID, not the object
    @Published private(set) var objectChangeID: UUID?

    /// Fires when selection changes - no data copied
    @Published private(set) var selectionChangeToken: UUID = UUID()

    /// Fires when layers change - no data copied
    @Published private(set) var layerChangeToken: UUID = UUID()

    /// General change token for UI refresh - fastest option
    @Published private(set) var changeToken: UUID = UUID()

    // MARK: - Notification Methods (O(1) - no copying)

    func notifyObjectChanged(_ id: UUID) {
        objectChangeID = id
        changeToken = UUID()
    }

    func notifySelectionChanged() {
        selectionChangeToken = UUID()
        changeToken = UUID()
    }

    func notifyLayersChanged() {
        layerChangeToken = UUID()
        changeToken = UUID()
    }

    func notifyMultipleObjectsChanged(_ ids: Set<UUID>) {
        // For bulk changes, just trigger general refresh
        changeToken = UUID()
    }

    func notifyGeneralChange() {
        changeToken = UUID()
    }
}
