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
            if case .text(let shape) = unifiedObj.objectType, shape.isEditing == true {
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
        print("🟡 handleSelectionConversion: \(oldTool.rawValue) -> \(newTool.rawValue)")
        print("🟡 selectedObjectIDs BEFORE: \(document.viewState.selectedObjectIDs)")

        if newTool == .selection {
            if !selectedObjectIDs.isEmpty {
                document.viewState.selectedObjectIDs = selectedObjectIDs
                selectedObjectIDs.removeAll()
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                syncDirectSelectionWithDocument()
            }
        }

        else if newTool == .directSelection {
            if !document.viewState.selectedObjectIDs.isEmpty {
                selectedObjectIDs = document.viewState.selectedObjectIDs
                syncDirectSelectionWithDocument()
            }
            else if oldTool == .convertAnchorPoint || oldTool == .penPlusMinus {
                selectedPoints.removeAll()
                selectedHandles.removeAll()
            }
        }

        else if newTool == .convertAnchorPoint || newTool == .penPlusMinus {
            if !document.viewState.selectedObjectIDs.isEmpty {
                selectedObjectIDs = document.viewState.selectedObjectIDs
                syncDirectSelectionWithDocument()
            }
        }

        // Maintain selection when switching to font tool
        else if newTool == .font {
            print("🟡 Switching to .font, keeping selection unchanged")

            // Find first text object in selection and set it to editing
            for selectedID in document.viewState.selectedObjectIDs {
                if let obj = document.snapshot.objects[selectedID],
                   case .text = obj.objectType {
                    print("🟡 Setting first text \(selectedID) to isEditing=true")
                    document.setTextEditingInUnified(id: selectedID, isEditing: true)
                    break
                }
            }
        }

        else if (oldTool == .directSelection || oldTool == .convertAnchorPoint || oldTool == .penPlusMinus) &&
                 newTool != .selection && newTool != .directSelection && newTool != .convertAnchorPoint && newTool != .penPlusMinus && newTool != .font {
            print("🟡 CLEARING SELECTION (directSelection/convertAnchor/penPlusMinus cleanup)")
            document.viewState.selectedObjectIDs.removeAll()
            selectedObjectIDs.removeAll()
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            syncDirectSelectionWithDocument()
        }

        print("🟡 selectedObjectIDs AFTER: \(document.viewState.selectedObjectIDs)")
    }

    internal func clearToolState() {
        if document.viewState.currentTool != .bezierPen {
            showClosePathHint = false
            showContinuePathHint = false
        }

    }
}
