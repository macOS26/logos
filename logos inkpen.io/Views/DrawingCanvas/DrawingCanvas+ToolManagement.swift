import SwiftUI
import Combine

extension DrawingCanvas {
    internal func handleToolChange(oldTool: DrawingTool, newTool: DrawingTool) {
        print("🔧 Tool change: \(oldTool.rawValue) → \(newTool.rawValue), selectedPoints: \(selectedPoints.count)")

        // Track if this is a temporary Cmd-switch to selection tool
        let isCmdPressed = NSEvent.modifierFlags.contains(.command)
        if newTool == .selection && isCmdPressed {
            isTemporarySelectionViaCommand = true
        } else if oldTool == .selection && isTemporarySelectionViaCommand {
            isTemporarySelectionViaCommand = false
        }

        if isCornerRadiusEditMode {
            isCornerRadiusEditMode = false
        }

        if (previousTool == .font || oldTool == .font) && newTool != .font {
            stopAllTextEditing()
        } else if newTool == .selection && !isTemporarySelectionViaCommand {
            stopAllTextEditing()
        }

        // Don't finish paths when switching to temporary tools (hand/zoom/Cmd+selection)
        let isTemporaryTool = newTool == .hand || newTool == .zoom || (newTool == .selection && isTemporarySelectionViaCommand)
        if previousTool == .bezierPen && newTool != .bezierPen && !isTemporaryTool && isBezierDrawing {
            finishBezierPath()
        }

        // Don't finish freehand when switching to temporary tools (hand/zoom/Cmd+selection)
        if previousTool == .freehand && newTool != .freehand && !isTemporaryTool && isFreehandDrawing {
            handleFreehandDragEnd()
        }

        if previousTool == .font && newTool == .selection {
        }

        if previousTool == .selection && newTool == .font {
        }

        handleSelectionConversion(from: oldTool, to: newTool)

        previousTool = newTool
    }

    private func stopAllTextEditing() {
        var stoppedCount = 0

        // Stop top-level text objects
        for obj in document.snapshot.objects.values {
            if case .text(let shape) = obj.objectType, shape.isEditing == true {
                document.setTextEditingInUnified(id: shape.id, isEditing: false)
                stoppedCount += 1
            }
        }

        // ALSO stop text inside groups
        for obj in document.snapshot.objects.values {
            switch obj.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                if groupShape.isGroupContainer {
                    for childShape in groupShape.groupedShapes {
                        if childShape.typography != nil && childShape.isEditing == true {
                            document.setTextEditingInUnified(id: childShape.id, isEditing: false)
                            stoppedCount += 1
                        }
                    }
                }
            default:
                break
            }
        }

        if isEditingText {
            isEditingText = false
            editingTextID = nil
            currentCursorPosition = 0
            currentSelectionRange = NSRange(location: 0, length: 0)
        }

        isTextEditingMode = false
        #if os(macOS)
        NSCursor.arrow.set()
        #endif

        if let window = NSApp.keyWindow {
            window.makeFirstResponder(nil)
        }

    }

    private func finishTextEditingButKeepSelected(_ textID: UUID) {
        document.setTextEditingInUnified(id: textID, isEditing: false)

        document.viewState.selectedObjectIDs = [textID]

        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)

    }

    private func handleSelectionConversion(from oldTool: DrawingTool, to newTool: DrawingTool) {
        // print("🟡 handleSelectionConversion: \(oldTool.rawValue) -> \(newTool.rawValue)")
        // print("🟡 selectedObjectIDs BEFORE: \(document.viewState.selectedObjectIDs)")

        // Cmd+selection is temporary - preserve all state
        if newTool == .selection && isTemporarySelectionViaCommand {
            // Don't modify any selection state for temporary Cmd+selection
        }
        else if newTool == .selection {
            if !selectedObjectIDs.isEmpty {
                document.viewState.selectedObjectIDs = selectedObjectIDs
                selectedObjectIDs.removeAll()
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                // Don't call syncDirectSelectionWithDocument() here - it would clear the selection
            }
        }

        else if newTool == .directSelection {
            // Clear any leftover point/handle selections
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            visibleHandles.removeAll()

            if !document.viewState.selectedObjectIDs.isEmpty {
                selectedObjectIDs = document.viewState.selectedObjectIDs
                syncDirectSelectionWithDocument()
            }
        }

        else if newTool == .bezierPen {
            // Preserve selectedPoints when switching to bezier pen (for path continuation)
            // Don't clear selectedPoints, selectedHandles, or selectedObjectIDs
            // Keep everything as-is for path continuation feature
            print("🔧 Preserving selections for bezier pen: points=\(selectedPoints.count), handles=\(selectedHandles.count)")

            // If a point is selected, automatically load the path for continuation
            // Always reload from the path - don't rely on stale state
            if let selectedPointID = selectedPoints.first {
                if getShapeForPoint(selectedPointID) != nil,
                   let pointPosition = getPointPosition(selectedPointID) {
                    print("🔧 Auto-loading path for continuation from selected point")
                    continueExistingPath(from: pointPosition)
                }
            }
        }

        else if newTool == .convertAnchorPoint || newTool == .penPlusMinus {
            // Clear any leftover point/handle selections
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            visibleHandles.removeAll()

            if !document.viewState.selectedObjectIDs.isEmpty {
                selectedObjectIDs = document.viewState.selectedObjectIDs
                syncDirectSelectionWithDocument()
            }
        }

        // Maintain selection when switching to font tool
        else if newTool == .font {
            // print("🟡 Switching to .font, keeping selection unchanged")

            // Find first text object in selection and set it to editing
            for selectedID in document.viewState.selectedObjectIDs {
                if let obj = document.snapshot.objects[selectedID],
                   case .text = obj.objectType {
                    // print("🟡 Setting first text \(selectedID) to isEditing=true")
                    document.setTextEditingInUnified(id: selectedID, isEditing: true)
                    break
                }
            }
        }

        else if (oldTool == .directSelection || oldTool == .convertAnchorPoint || oldTool == .penPlusMinus) &&
                 newTool != .selection && newTool != .directSelection && newTool != .convertAnchorPoint && newTool != .penPlusMinus && newTool != .bezierPen && newTool != .font && newTool != .hand && newTool != .zoom && newTool != .scale && newTool != .rotate && newTool != .shear && newTool != .warp {
            print("🟡 CLEARING SELECTION (directSelection/convertAnchor/penPlusMinus cleanup) - oldTool: \(oldTool.rawValue), newTool: \(newTool.rawValue)")
            document.viewState.selectedObjectIDs.removeAll()
            selectedObjectIDs.removeAll()
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            syncDirectSelectionWithDocument()
        }

        // Preserve selection when switching to/from temporary tools (hand/zoom)
        else if newTool == .hand || oldTool == .hand || newTool == .zoom || oldTool == .zoom {
            // Temporary tools - don't modify selection state
        }

        // print("🟡 selectedObjectIDs AFTER: \(document.viewState.selectedObjectIDs)")
    }

    internal func clearToolState() {
        if document.viewState.currentTool != .bezierPen {
            showClosePathHint = false
            showContinuePathHint = false
        }

    }
}
