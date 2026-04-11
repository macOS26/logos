import SwiftUI
import Combine

extension VectorDocument {

    func executeCommand(_ command: Command) {
        commandManager.execute(command)
    }

    // MARK: - Shape Modification with Undo/Redo

    /// Modifies selected shapes and registers a ShapeModificationCommand for undo/redo.
    @discardableResult
    func modifySelectedShapesWithUndo(
        _ modification: (inout VectorShape) -> Void
    ) -> Bool {
        let activeShapeIDs = getActiveShapeIDs()
        guard !activeShapeIDs.isEmpty else { return false }

        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        func collectAllMemberIDs(_ shapeID: UUID, into collection: inout [UUID]) {
            guard let shape = findShape(by: shapeID) else { return }

            if !collection.contains(shapeID) {
                collection.append(shapeID)
            }

            if (shape.isGroup || shape.isClippingGroup) && !shape.memberIDs.isEmpty {
                for memberID in shape.memberIDs {
                    collectAllMemberIDs(memberID, into: &collection)
                }
            }
        }

        for shapeID in activeShapeIDs {
            collectAllMemberIDs(shapeID, into: &objectIDs)
        }

        for shapeID in objectIDs {
            if let shape = findShape(by: shapeID) {
                oldShapes[shapeID] = shape
            }
        }

        for shapeID in objectIDs {
            updateShapeByID(shapeID) { shape in
                modification(&shape)
            }
        }

        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in objectIDs {
            if let shape = findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(
                objectIDs: objectIDs,
                oldShapes: oldShapes,
                newShapes: newShapes
            )
            commandManager.execute(command)
        }

        return !objectIDs.isEmpty
    }

    /// Variant that runs `preCapture` between old-state capture and new-state capture.
    @discardableResult
    func modifySelectedShapesWithUndo(
        preCapture: () -> Void,
        modification: ((inout VectorShape) -> Void)? = nil
    ) -> Bool {
        let activeShapeIDs = getActiveShapeIDs()
        guard !activeShapeIDs.isEmpty else { return false }

        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        func collectAllMemberIDs(_ shapeID: UUID, into collection: inout [UUID]) {
            guard let shape = findShape(by: shapeID) else { return }

            if !collection.contains(shapeID) {
                collection.append(shapeID)
            }

            if (shape.isGroup || shape.isClippingGroup) && !shape.memberIDs.isEmpty {
                for memberID in shape.memberIDs {
                    collectAllMemberIDs(memberID, into: &collection)
                }
            }
        }

        for shapeID in activeShapeIDs {
            collectAllMemberIDs(shapeID, into: &objectIDs)
        }

        for shapeID in objectIDs {
            if let shape = findShape(by: shapeID) {
                oldShapes[shapeID] = shape
            }
        }

        preCapture()

        if let modification = modification {
            for shapeID in objectIDs {
                updateShapeByID(shapeID) { shape in
                    modification(&shape)
                }
            }
        }

        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in objectIDs {
            if let shape = findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(
                objectIDs: objectIDs,
                oldShapes: oldShapes,
                newShapes: newShapes
            )
            commandManager.execute(command)
        }

        return !objectIDs.isEmpty
    }

    /// Modifies specific shapes by ID and registers a ShapeModificationCommand.
    @discardableResult
    func modifyShapesWithUndo(
        shapeIDs: [UUID],
        modification: (inout VectorShape) -> Void
    ) -> Bool {
        guard !shapeIDs.isEmpty else { return false }

        var oldShapes: [UUID: VectorShape] = [:]
        var validIDs: [UUID] = []

        for shapeID in shapeIDs {
            if let shape = findShape(by: shapeID) {
                oldShapes[shapeID] = shape
                validIDs.append(shapeID)
            }
        }

        for shapeID in validIDs {
            updateShapeByID(shapeID) { shape in
                modification(&shape)
            }
        }

        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in validIDs {
            if let shape = findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }

        if !validIDs.isEmpty {
            let command = ShapeModificationCommand(
                objectIDs: validIDs,
                oldShapes: oldShapes,
                newShapes: newShapes
            )
            commandManager.execute(command)
        }

        return !validIDs.isEmpty
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
