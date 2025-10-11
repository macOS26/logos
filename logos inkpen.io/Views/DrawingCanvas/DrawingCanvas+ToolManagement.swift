
import SwiftUI
import Combine

extension DrawingCanvas {
    internal func handleToolChange(oldTool: DrawingTool, newTool: DrawingTool) {
        if isCornerRadiusEditMode {
            isCornerRadiusEditMode = false
        }

        if (previousTool == .font || oldTool == .font) && newTool != .font {
            stopAllTextEditing()
        } else if newTool == .selection {
            stopAllTextEditing()
        }

        if previousTool == .bezierPen && newTool != .bezierPen && isBezierDrawing {
            finishBezierPath()
        }

        if previousTool == .freehand && newTool != .freehand && isFreehandDrawing {
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

        for unifiedObj in document.unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject, shape.isEditing == true {
                document.setTextEditingInUnified(id: shape.id, isEditing: false)
                stoppedCount += 1
            }
        }

        if isEditingText {
            isEditingText = false
            editingTextID = nil
            currentCursorPosition = 0
            currentSelectionRange = NSRange(location: 0, length: 0)
        }

        isTextEditingMode = false
        NSCursor.arrow.set()

    }

    private func finishTextEditingButKeepSelected(_ textID: UUID) {
        document.setTextEditingInUnified(id: textID, isEditing: false)

        document.selectedObjectIDs = [textID]

        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)

    }


    private func handleSelectionConversion(from oldTool: DrawingTool, to newTool: DrawingTool) {

        if newTool == .selection {
            if !directSelectedShapeIDs.isEmpty {
                document.selectedObjectIDs = directSelectedShapeIDs
                directSelectedShapeIDs.removeAll()
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                syncDirectSelectionWithDocument()
            }
        }

        else if newTool == .directSelection {
            if !document.selectedObjectIDs.isEmpty {
                directSelectedShapeIDs = document.selectedObjectIDs
                syncDirectSelectionWithDocument()
            }
            else if oldTool == .convertAnchorPoint || oldTool == .penPlusMinus {
                selectedPoints.removeAll()
                selectedHandles.removeAll()
            }
        }

        else if newTool == .convertAnchorPoint || newTool == .penPlusMinus {
            if !document.selectedObjectIDs.isEmpty {
                directSelectedShapeIDs = document.selectedObjectIDs
                syncDirectSelectionWithDocument()
            }
        }

        else if (oldTool == .directSelection || oldTool == .convertAnchorPoint || oldTool == .penPlusMinus) &&
                 newTool != .selection && newTool != .directSelection && newTool != .convertAnchorPoint && newTool != .penPlusMinus {
            document.selectedObjectIDs.removeAll()
            directSelectedShapeIDs.removeAll()
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            syncDirectSelectionWithDocument()
        }

        document.objectWillChange.send()
    }


    internal func clearToolState() {
        if document.currentTool != .bezierPen {
            showClosePathHint = false
            showContinuePathHint = false
        }

    }
}
