# logos inkpen.io - Development Guide

## Shape Modification with Undo/Redo

When modifying shapes and needing undo/redo support, use the helper methods in `VectorDocument+UndoRedo.swift`. **Do NOT manually write the old/new shape capture boilerplate.**

### Available Methods

#### 1. `modifySelectedShapesWithUndo(_ modification:)`
Use for simple modifications directly on shapes.

```swift
document.modifySelectedShapesWithUndo { shape in
    shape.fillStyle?.opacity = 0.5
}
```

#### 2. `modifySelectedShapesWithUndo(preCapture:modification:)`
Use when you need to perform additional operations (like updating defaults or calling live updates) between capturing old/new states.

```swift
document.modifySelectedShapesWithUndo(
    preCapture: {
        document.defaultFillOpacity = newOpacity
        PaintSelectionOperations.updateFillOpacityLive(newOpacity, document: document, isEditing: false)
    }
)
```

#### 3. `modifyShapesWithUndo(shapeIDs:modification:)`
Use when modifying specific shapes (not just the current selection).

```swift
document.modifyShapesWithUndo(shapeIDs: [shapeID1, shapeID2]) { shape in
    shape.transform = newTransform
}
```

### NEVER DO THIS (Old Pattern - Deprecated)

```swift
// DON'T write this boilerplate manually - it's error-prone and verbose
var oldShapes: [UUID: VectorShape] = [:]
var objectIDs: [UUID] = []
let activeShapeIDs = document.getActiveShapeIDs()

for shapeID in activeShapeIDs {
    if let shape = document.findShape(by: shapeID) {
        oldShapes[shapeID] = shape
        objectIDs.append(shapeID)
    }
}

// ... do modifications ...

var newShapes: [UUID: VectorShape] = [:]
for shapeID in objectIDs {
    if let shape = document.findShape(by: shapeID) {
        newShapes[shapeID] = shape
    }
}

if !objectIDs.isEmpty {
    let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
    document.commandManager.execute(command)
}
```

### When to Use Each Pattern

| Scenario | Method |
|----------|--------|
| Simple property change on selection | `modifySelectedShapesWithUndo { }` |
| Need to update defaults + live update | `modifySelectedShapesWithUndo(preCapture:)` |
| Modifying specific shapes by ID | `modifyShapesWithUndo(shapeIDs:)` |

### Files Refactored to Use New Pattern
- `PaintSelectionOperations.swift` - fill opacity, stroke width, stroke opacity, miter limit
- `VectorDocument+Nudging.swift` - nudge operations

### When NOT to Use the Helper

The helper is NOT appropriate for:
- Single-shape operations with complex interleaved logic (e.g., transforms in handles)
- Operations that create new shapes or modify layer structure
- Cases where old/new state must be captured at very specific points in complex logic

These files have valid reasons for manual patterns:
- Handle files (`RotateHandles`, `ShearHandles`, `ScaleHandles`, etc.) - complex transform logic
- `VectorDocument+StrokeOutlining` - creates new shapes
- `VectorDocument+PathfinderOperations` - modifies layer structure

### Good Candidates for Future Refactoring

When you touch these files, consider using the helper if the pattern is simple:
- `DrawingCanvas+CornerRadiusEditTool.swift` (line ~378)
- `DrawingCanvas+CornerRadiusTool.swift`
- `MainToolbarContent.swift` (closeSelectedPaths)
- `TransformationControls.swift`
- `CornerRadiusToolbar.swift`
- `PathOperationsPanel.swift`
- `ProfessionalOffsetPathSection.swift`
