import SwiftUI
import Combine

extension VectorDocument {

    func executeCommand(_ command: Command) {
        commandManager.execute(command)
    }

    // MARK: - Shape Modification with Undo/Redo

    /// Executes a modification on selected shapes with automatic undo/redo support.
    ///
    /// This is the preferred way to modify selected shapes when you need undo/redo support.
    /// It automatically captures old state, applies your modification, captures new state,
    /// and registers the command with the undo manager.
    ///
    /// Example usage:
    /// ```swift
    /// document.modifySelectedShapesWithUndo { shape in
    ///     shape.fillStyle?.opacity = 0.5
    /// }
    /// ```
    ///
    /// - Parameter modification: A closure that modifies each selected shape in place
    /// - Returns: True if any shapes were modified, false if no shapes were selected
    @discardableResult
    func modifySelectedShapesWithUndo(
        _ modification: (inout VectorShape) -> Void
    ) -> Bool {
        let activeShapeIDs = getActiveShapeIDs()
        guard !activeShapeIDs.isEmpty else { return false }

        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        // Helper to recursively collect member IDs for groups
        func collectAllMemberIDs(_ shapeID: UUID, into collection: inout [UUID]) {
            guard let shape = findShape(by: shapeID) else { return }

            // Add the shape itself
            if !collection.contains(shapeID) {
                collection.append(shapeID)
            }

            // If it's a group with members, recursively collect them
            if (shape.isGroup || shape.isClippingGroup) && !shape.memberIDs.isEmpty {
                for memberID in shape.memberIDs {
                    collectAllMemberIDs(memberID, into: &collection)
                }
            }
        }

        // Capture old state (including all member shapes for groups)
        for shapeID in activeShapeIDs {
            collectAllMemberIDs(shapeID, into: &objectIDs)
        }

        for shapeID in objectIDs {
            if let shape = findShape(by: shapeID) {
                oldShapes[shapeID] = shape
            }
        }

        // Apply modification
        for shapeID in objectIDs {
            updateShapeByID(shapeID) { shape in
                modification(&shape)
            }
        }

        // Capture new state
        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in objectIDs {
            if let shape = findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }

        // Register command
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

    /// Executes a modification on selected shapes with automatic undo/redo support,
    /// with an additional action to perform after capturing old state but before capturing new state.
    ///
    /// Use this when you need to perform additional operations (like updating defaults or live updates)
    /// between capturing old/new states.
    ///
    /// Example usage:
    /// ```swift
    /// document.modifySelectedShapesWithUndo(
    ///     preCapture: {
    ///         document.defaultFillOpacity = newOpacity
    ///         PaintSelectionOperations.updateFillOpacityLive(newOpacity, document: document, isEditing: false)
    ///     },
    ///     modification: { shape in
    ///         // modification already applied by live update
    ///     }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - preCapture: Action to perform after capturing old state (e.g., update defaults, call live update)
    ///   - modification: Optional closure to modify shapes (if nil, assumes preCapture did the modifications)
    /// - Returns: True if any shapes were modified
    @discardableResult
    func modifySelectedShapesWithUndo(
        preCapture: () -> Void,
        modification: ((inout VectorShape) -> Void)? = nil
    ) -> Bool {
        let activeShapeIDs = getActiveShapeIDs()
        guard !activeShapeIDs.isEmpty else { return false }

        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        // Helper to recursively collect member IDs for groups
        func collectAllMemberIDs(_ shapeID: UUID, into collection: inout [UUID]) {
            guard let shape = findShape(by: shapeID) else { return }

            // Add the shape itself
            if !collection.contains(shapeID) {
                collection.append(shapeID)
            }

            // If it's a group with members, recursively collect them
            if (shape.isGroup || shape.isClippingGroup) && !shape.memberIDs.isEmpty {
                for memberID in shape.memberIDs {
                    collectAllMemberIDs(memberID, into: &collection)
                }
            }
        }

        // Capture old state (including all member shapes for groups)
        for shapeID in activeShapeIDs {
            collectAllMemberIDs(shapeID, into: &objectIDs)
        }

        for shapeID in objectIDs {
            if let shape = findShape(by: shapeID) {
                oldShapes[shapeID] = shape
            }
        }

        // Perform pre-capture action (updates defaults, calls live updates, etc.)
        preCapture()

        // Apply additional modification if provided
        if let modification = modification {
            for shapeID in objectIDs {
                updateShapeByID(shapeID) { shape in
                    modification(&shape)
                }
            }
        }

        // Capture new state
        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in objectIDs {
            if let shape = findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }

        // Register command
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

    /// Executes a modification on specific shape IDs with automatic undo/redo support.
    ///
    /// Use this when you need to modify specific shapes (not just the selection).
    ///
    /// - Parameters:
    ///   - shapeIDs: The IDs of shapes to modify
    ///   - modification: A closure that modifies each shape in place
    /// - Returns: True if any shapes were modified
    @discardableResult
    func modifyShapesWithUndo(
        shapeIDs: [UUID],
        modification: (inout VectorShape) -> Void
    ) -> Bool {
        guard !shapeIDs.isEmpty else { return false }

        var oldShapes: [UUID: VectorShape] = [:]
        var validIDs: [UUID] = []

        // Capture old state
        for shapeID in shapeIDs {
            if let shape = findShape(by: shapeID) {
                oldShapes[shapeID] = shape
                validIDs.append(shapeID)
            }
        }

        // Apply modification
        for shapeID in validIDs {
            updateShapeByID(shapeID) { shape in
                modification(&shape)
            }
        }

        // Capture new state
        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in validIDs {
            if let shape = findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }

        // Register command
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
