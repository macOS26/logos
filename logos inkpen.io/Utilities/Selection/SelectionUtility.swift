import SwiftUI

/// Singleton for accessing current selection without needing to pass document everywhere
class CurrentSelection {
    static let shared = CurrentSelection()

    var snapshot: DocumentSnapshot = DocumentSnapshot()
    var viewState: DocumentViewState = DocumentViewState()

    private init() {}

    /// Update the selection context with current document state
    /// Call this when document changes or at the start of operations
    func update(snapshot: DocumentSnapshot, viewState: DocumentViewState) {
        self.snapshot = snapshot
        self.viewState = viewState
    }

    // MARK: - Instance Methods with Defaults

    /// Get selected VectorObjects from snapshot using selectedObjectIDs
    /// Returns a dictionary of [UUID: VectorObject] for easy access and updates
    func getSelectedObjects(from snapshot: DocumentSnapshot? = nil, selectedObjectIDs: Set<UUID>? = nil) -> [UUID: VectorObject] {
        let actualSnapshot = snapshot ?? self.snapshot
        let actualSelectedIDs = selectedObjectIDs ?? self.viewState.selectedObjectIDs

        var selectedObjects: [UUID: VectorObject] = [:]

        for objectID in actualSelectedIDs {
            if let object = actualSnapshot.objects[objectID] {
                selectedObjects[objectID] = object
            }
        }

        return selectedObjects
    }

    /// Get first selected object (useful for UI that shows properties of first selection)
    func getFirstSelectedObject(from snapshot: DocumentSnapshot? = nil, selectedObjectIDs: Set<UUID>? = nil) -> VectorObject? {
        let actualSnapshot = snapshot ?? self.snapshot
        let actualSelectedIDs = selectedObjectIDs ?? self.viewState.selectedObjectIDs

        guard let firstID = actualSelectedIDs.first,
              let object = actualSnapshot.objects[firstID] else {
            return nil
        }
        return object
    }

    /// Get selected shapes (extracts shapes from VectorObjects)
    func getSelectedShapes(from snapshot: DocumentSnapshot? = nil, selectedObjectIDs: Set<UUID>? = nil) -> [UUID: VectorShape] {
        let actualSnapshot = snapshot ?? self.snapshot
        let actualSelectedIDs = selectedObjectIDs ?? self.viewState.selectedObjectIDs

        var selectedShapes: [UUID: VectorShape] = [:]

        for objectID in actualSelectedIDs {
            if let object = actualSnapshot.objects[objectID] {
                selectedShapes[objectID] = object.shape
            }
        }

        return selectedShapes
    }
    
    /// Get selected shapes (extracts shapes from VectorObjects)
    func getSelectedText(from snapshot: DocumentSnapshot? = nil, selectedObjectIDs: Set<UUID>? = nil) -> [UUID: VectorShape] {
        let actualSnapshot = snapshot ?? self.snapshot
        let actualSelectedIDs = selectedObjectIDs ?? self.viewState.selectedObjectIDs

        var selectedShapes: [UUID: VectorShape] = [:]

        for objectID in actualSelectedIDs {
            if let object = actualSnapshot.objects[objectID] {
                selectedShapes[objectID] = object.shape
            }
        }

        return selectedShapes
    }


    /// Create updated VectorObject with modified shape
    /// Returns new VectorObject that can be assigned back to the snapshot
    func createUpdatedObject(from originalObject: VectorObject, with newShape: VectorShape) -> VectorObject {
        return VectorObject(shape: newShape, layerIndex: originalObject.layerIndex)
    }

}
