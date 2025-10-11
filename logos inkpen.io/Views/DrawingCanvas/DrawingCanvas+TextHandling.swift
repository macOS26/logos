
import SwiftUI
import SwiftUI
import Combine

extension DrawingCanvas {


    func handleFontToolTap(at location: CGPoint) {
        lastTapLocation = location

        if let existingTextID = findTextAt(location: location) {
            startEditingText(textID: existingTextID, at: location)
        } else {
            createNewTextAt(location: location)
        }
    }

    func handleAggressiveBackgroundTap(at location: CGPoint) {

        let tapHitsText = document.unifiedObjects.contains { unifiedObj in
            guard case .shape(let shape) = unifiedObj.objectType else { return false }

            if shape.isGroupContainer {
                for childShape in shape.groupedShapes {
                    if childShape.isTextObject, var textObj = VectorText.from(childShape) {
                        textObj.layerIndex = unifiedObj.layerIndex
                        if !textObj.isVisible || textObj.isLocked { continue }

                        let exactBounds = CGRect(
                            x: textObj.position.x + textObj.bounds.minX,
                            y: textObj.position.y + textObj.bounds.minY,
                            width: textObj.bounds.width,
                            height: textObj.bounds.height
                        )

                        let expandedBounds = exactBounds.insetBy(dx: -30, dy: -20)

                        if expandedBounds.contains(location) {
                            return true
                        }
                    }
                }
            }

            if shape.isTextObject, var textObj = VectorText.from(shape) {
                textObj.layerIndex = unifiedObj.layerIndex
                if !textObj.isVisible || textObj.isLocked { return false }

                let exactBounds = CGRect(
                    x: textObj.position.x + textObj.bounds.minX,
                    y: textObj.position.y + textObj.bounds.minY,
                    width: textObj.bounds.width,
                    height: textObj.bounds.height
                )

                let expandedBounds = exactBounds.insetBy(dx: -30, dy: -20)

                return expandedBounds.contains(location)
            }

            return false
        }

        if !tapHitsText {
            document.selectedTextIDs.removeAll()
            document.selectedShapeIDs.removeAll()

            for unifiedObj in document.unifiedObjects {
                if case .shape(let shape) = unifiedObj.objectType {
                    if shape.isTextObject && shape.isEditing == true {
                        document.setTextEditingInUnified(id: shape.id, isEditing: false)
                    }
                    if shape.isGroupContainer {
                        for childShape in shape.groupedShapes {
                            if childShape.isTextObject && childShape.isEditing == true {
                                document.setTextEditingInUnified(id: childShape.id, isEditing: false)
                            }
                        }
                    }
                }
            }

            finishTextEditing()
        }
    }

    func findTextAt(location: CGPoint) -> UUID? {
        for unifiedObj in document.unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType {
                if shape.isGroupContainer {
                    for childShape in shape.groupedShapes {
                        if childShape.isTextObject, var textObj = VectorText.from(childShape) {
                            textObj.layerIndex = unifiedObj.layerIndex
                            if !textObj.isVisible || textObj.isLocked { continue }

                            let textBounds = CGRect(
                                x: textObj.position.x + textObj.bounds.minX,
                                y: textObj.position.y + textObj.bounds.minY,
                                width: textObj.bounds.width,
                                height: textObj.bounds.height
                            )

                            if textBounds.contains(location) {
                                return textObj.id
                            }
                        }
                    }
                }

                if shape.isTextObject, var textObj = VectorText.from(shape) {
                    textObj.layerIndex = unifiedObj.layerIndex
                    if !textObj.isVisible || textObj.isLocked { continue }


                    let textBounds = CGRect(
                        x: textObj.position.x + textObj.bounds.minX,
                        y: textObj.position.y + textObj.bounds.minY,
                        width: textObj.bounds.width,
                        height: textObj.bounds.height
                    )

                    let hitArea = textBounds


                    if hitArea.contains(location) {
                        return textObj.id
                    }
                }
            }
        }

        return nil
    }

    func startEditingText(textID: UUID, at location: CGPoint) {

        document.saveToUndoStack()

        for unifiedObj in document.unifiedObjects {
            guard case .shape(let shape) = unifiedObj.objectType,
                  shape.isTextObject,
                  shape.id != textID,
                  shape.isEditing == true else { continue }

            document.setTextEditingInUnified(id: shape.id, isEditing: false)
        }

        if let textObject = document.findText(by: textID) {


            document.setTextEditingInUnified(id: textObject.id, isEditing: true)

            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs = [textID]

            isEditingText = true
            editingTextID = textID

            let cursorPosition = calculateCursorPosition(in: textObject, at: location)
            currentCursorPosition = cursorPosition
            currentSelectionRange = NSRange(location: cursorPosition, length: 0)

            document.updateTextCursorPositionInUnified(id: textObject.id, cursorPosition: cursorPosition)


        } else {
            Log.error("❌ TEXT NOT FOUND: Could not find text with ID \(textID)", category: .error)
        }
    }

    func handleTextBoxInteraction(textID: UUID, isDoubleClick: Bool = false, isCornerClick: Bool = false) {

        guard let textObject = document.findText(by: textID) else {
            Log.error("❌ TEXT NOT FOUND: ID \(textID)", category: .error)
            return
        }
        let currentState = textObject.getState(in: document)


        if textObject.isLocked {
            return
        }

        if isDoubleClick || isCornerClick {
            switch currentState {
            case .unselected:
                document.selectedTextIDs = [textID]
                document.selectedShapeIDs.removeAll()

                if document.currentTool == .font && isCornerClick {
                    startEditingText(textID: textID, at: .zero)
                }

            case .selected:
                if isDoubleClick {
                    document.currentTool = .font

                    startEditingText(textID: textID, at: .zero)
                } else if document.currentTool == .font {
                    startEditingText(textID: textID, at: .zero)
                }


            case .editing:
                break
            }
        } else {
            switch currentState {
            case .unselected:
                document.selectedTextIDs = [textID]
                document.selectedShapeIDs.removeAll()

            case .selected:
                break

            case .editing:
                break
            }
        }
    }


    func calculateCursorPosition(in textObj: VectorText, at tapLocation: CGPoint) -> Int {
        let relativePoint = CGPoint(
            x: tapLocation.x - textObj.position.x,
            y: tapLocation.y - textObj.position.y
        )


        let nsFont = textObj.typography.nsFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .kern: textObj.typography.letterSpacing
        ]

        let attributedString = NSAttributedString(string: textObj.content, attributes: attributes)

        let textContainer = NSTextContainer(containerSize: CGSize(
            width: textObj.bounds.width,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage(attributedString: attributedString)
        textStorage.addLayoutManager(layoutManager)

        layoutManager.ensureLayout(for: textContainer)

        let characterIndex = layoutManager.characterIndex(
            for: relativePoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        let finalIndex = max(0, min(textObj.content.count, characterIndex))


        return finalIndex
    }

    private func updateTextViewModelCursorPosition(textID: UUID, position: Int, length: Int) {
        if document.findText(by: textID) != nil {


        }
    }


    func createNewTextAt(location: CGPoint) {
        createNewTextWithSize(at: location, width: 300, height: 100)
    }

    func createNewTextWithSize(at location: CGPoint, width: CGFloat, height: CGFloat) {


        document.saveToUndoStack()

        let typography = TypographyProperties(
            fontFamily: document.fontManager.selectedFontFamily,
            fontVariant: document.fontManager.selectedFontVariant,
            fontSize: document.fontManager.selectedFontSize,
            lineHeight: document.fontManager.selectedLineHeight,
            lineSpacing: document.fontManager.selectedLineSpacing,
            letterSpacing: 0.0,
            alignment: document.fontManager.selectedTextAlignment,
            hasStroke: false,
            strokeColor: document.defaultStrokeColor,
            strokeOpacity: document.defaultStrokeOpacity,
            fillColor: document.defaultFillColor,
            fillOpacity: document.defaultFillOpacity
        )


        var newText = VectorText(
            content: "",
            typography: typography,
            position: location,
            isEditing: true
        )

        newText.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        newText.areaSize = CGSize(width: width, height: height)

        document.addTextToLayer(newText, layerIndex: document.selectedLayerIndex!)

        document.selectedTextIDs = [newText.id]
        document.selectedShapeIDs.removeAll()

        document.setTextEditingInUnified(id: newText.id, isEditing: true)

        isEditingText = true
        editingTextID = newText.id

        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)

    }


    func insertTextAtCursor(_ text: String) {
        guard let editingID = editingTextID,
              var textObj = document.findText(by: editingID) else { return }

        let insertIndex = textObj.content.index(
            textObj.content.startIndex,
            offsetBy: min(currentCursorPosition, textObj.content.count)
        )
        textObj.content.insert(contentsOf: text, at: insertIndex)

        currentCursorPosition += text.count
        currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)

        textObj.updateBounds()
        document.updateTextInUnified(textObj)

    }

    func deleteBackward() {
        guard let editingID = editingTextID,
              var textObj = document.findText(by: editingID) else { return }

        if currentSelectionRange.length > 0 {
            deleteSelectedText()
        } else if currentCursorPosition > 0 {
            let deleteIndex = textObj.content.index(
                textObj.content.startIndex,
                offsetBy: currentCursorPosition - 1
            )
            textObj.content.remove(at: deleteIndex)

            currentCursorPosition -= 1
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)

            textObj.updateBounds()
            document.updateTextInUnified(textObj)

        }
    }

    func deleteSelectedText() {
        guard let editingID = editingTextID,
              var textObj = document.findText(by: editingID),
              currentSelectionRange.length > 0 else { return }

        let startIndex = textObj.content.index(
            textObj.content.startIndex,
            offsetBy: currentSelectionRange.location
        )
        let endIndex = textObj.content.index(
            startIndex,
            offsetBy: currentSelectionRange.length
        )

        textObj.content.removeSubrange(startIndex..<endIndex)

        currentCursorPosition = currentSelectionRange.location
        currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)

        textObj.updateBounds()
        document.updateTextInUnified(textObj)

    }


    func selectAll() {
        guard let editingID = editingTextID,
              let textObj = document.findText(by: editingID) else { return }
        currentSelectionRange = NSRange(location: 0, length: textObj.content.count)
        currentCursorPosition = textObj.content.count

    }


    func moveCursorLeft() {
        if currentCursorPosition > 0 {
            currentCursorPosition -= 1
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
        }
    }

    func moveCursorRight() {
        guard let editingID = editingTextID,
              let textObj = document.findText(by: editingID) else { return }
        if currentCursorPosition < textObj.content.count {
            currentCursorPosition += 1
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
        }
    }

    func moveCursorToBeginning() {
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
    }

    func moveCursorToEnd() {
        guard let editingID = editingTextID,
              let textObj = document.findText(by: editingID) else { return }
        currentCursorPosition = textObj.content.count
        currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
    }


    func finishTextEditing() {
        if let editingID = editingTextID {
            if var textObj = document.findText(by: editingID) {
                document.setTextEditingInUnified(id: textObj.id, isEditing: false)
                textObj.updateBounds()
                document.updateTextInUnified(textObj)

                if textObj.content.isEmpty {
                    document.removeTextFromUnifiedSystem(id: editingID)
                }
            }
        }

        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)

        isTextEditingMode = false
        NSCursor.arrow.set()

    }

    func cancelTextEditing() {
        if let editingID = editingTextID {
            if let textObj = document.findText(by: editingID) {
                if textObj.content.isEmpty {
                    document.removeTextFromUnifiedSystem(id: editingID)
                } else {
                    document.setTextEditingInUnified(id: textObj.id, isEditing: false)
                }
            }
        }

        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)

        isTextEditingMode = false
        NSCursor.arrow.set()

        Log.error("❌ Cancelled text editing", category: .error)
    }
}

extension DrawingCanvas {

    func handleTextKeyPress(_ key: String) {
        guard isEditingText else { return }

        switch key {
        case "\u{08}":
            deleteBackward()
        case "\u{7F}":
            deleteForward()
        case "\u{1B}":
            finishTextEditing()
        case "\u{0D}", "\u{0A}":
            finishTextEditing()
        default:
            if key.count == 1 && !key.isEmpty {
                insertTextAtCursor(key)
            }
        }
    }

    private func deleteForward() {
        guard let editingID = editingTextID,
              var textObj = document.findText(by: editingID) else { return }

        if currentSelectionRange.length > 0 {
            deleteSelectedText()
        } else if currentCursorPosition < textObj.content.count {
            let deleteIndex = textObj.content.index(
                textObj.content.startIndex,
                offsetBy: currentCursorPosition
            )
            textObj.content.remove(at: deleteIndex)

            textObj.updateBounds()
            document.updateTextInUnified(textObj)

        }
    }
}

extension DrawingCanvas {

    func handleTextSelectionChange(textID: UUID, isSelected: Bool) {
        if isSelected {
            document.selectedTextIDs.insert(textID)
            document.selectedShapeIDs.removeAll()
        } else {
            document.selectedTextIDs.remove(textID)
        }
        document.objectWillChange.send()
    }

    func handleTextEditingChange(textID: UUID, isEditing: Bool) {
        if isEditing {
            document.saveToUndoStack()
            isEditingText = true
            editingTextID = textID

            if let textObj = document.findText(by: textID) {
                document.setTextEditingInUnified(id: textObj.id, isEditing: true)
            }

            document.selectedTextIDs.insert(textID)
            document.selectedShapeIDs.removeAll()

        } else {
            if let textObj = document.findText(by: textID) {
                document.setTextEditingInUnified(id: textObj.id, isEditing: false)

                if textObj.content.isEmpty {
                    document.unifiedObjects.removeAll { $0.id == textID }
                    document.removeTextFromUnifiedSystem(id: textID)
                    document.selectedTextIDs.remove(textID)
                }
            }

            if editingTextID == textID {
                isEditingText = false
                editingTextID = nil
                currentCursorPosition = 0
                currentSelectionRange = NSRange(location: 0, length: 0)
            }

        }
        document.objectWillChange.send()
    }

    func handleTextContentChange(textID: UUID, newContent: String) {
        guard var textObj = document.findText(by: textID) else { return }

        document.updateTextContentInUnified(id: textObj.id, content: newContent)
        textObj.updateBounds()
        document.updateTextInUnified(textObj)

        document.objectWillChange.send()
    }

    func handleTextPositionChange(textID: UUID, newPosition: CGPoint) {
        guard let textObj = document.findText(by: textID) else { return }

        document.saveToUndoStack()

        document.updateTextPositionInUnified(id: textObj.id, position: newPosition)

        document.objectWillChange.send()
    }

    func handleTextBoundsChange(textID: UUID, newBounds: CGRect) {
        guard let textObj = document.findText(by: textID) else { return }

        document.saveToUndoStack()

        document.updateTextBoundsInUnified(id: textObj.id, bounds: newBounds)

        document.objectWillChange.send()
    }


    func handleCanvasBackgroundTap(at location: CGPoint) {

        let hitAnyTextBox = document.unifiedObjects.contains { unifiedObj in
            guard case .shape(let shape) = unifiedObj.objectType,
                  shape.isTextObject,
                  var textObj = VectorText.from(shape) else { return false }
            textObj.layerIndex = unifiedObj.layerIndex
            let textFrame = CGRect(
                x: textObj.position.x,
                y: textObj.position.y,
                width: 300,
                height: max(textObj.bounds.height, 100)
            )
            return textFrame.contains(location)
        }

        if !hitAnyTextBox {
            document.selectedTextIDs.removeAll()
            document.selectedShapeIDs.removeAll()

            for unifiedObj in document.unifiedObjects {
                if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject, shape.isEditing == true {
                    document.setTextEditingInUnified(id: shape.id, isEditing: false)
                }
            }

            isEditingText = false
            editingTextID = nil

        }
    }


    func handleTextBoxDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        let hasEditingTextBox = document.unifiedObjects.contains { unifiedObj in
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject {
                return shape.isEditing == true
            }
            return false
        }
        if hasEditingTextBox {
            return
        }

        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let isDraggingResizeHandle = isLocationOnTextResizeHandle(startLocation)

        if isDraggingResizeHandle {
            return
        }

        if findTextAt(location: startLocation) != nil {
            return
        }

        let currentLocation = screenToCanvas(value.location, geometry: geometry)

        if !isDrawing {
            isDrawing = true
            shapeDragStart = startLocation
            shapeStartPoint = startLocation
            drawingStartPoint = startLocation
        }

        let minX = min(shapeStartPoint.x, currentLocation.x)
        let minY = min(shapeStartPoint.y, currentLocation.y)
        let width = abs(currentLocation.x - shapeStartPoint.x)
        let height = abs(currentLocation.y - shapeStartPoint.y)

        let finalWidth = max(width, 50.0)
        let finalHeight = max(height, 30.0)

        currentPath = VectorPath(elements: [
            .move(to: VectorPoint(minX, minY)),
            .line(to: VectorPoint(minX + finalWidth, minY)),
            .line(to: VectorPoint(minX + finalWidth, minY + finalHeight)),
            .line(to: VectorPoint(minX, minY + finalHeight)),
            .close
        ])

        document.objectWillChange.send()
    }

    func finishTextBoxDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        let hasEditingTextBox = document.unifiedObjects.contains { unifiedObj in
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject {
                return shape.isEditing == true
            }
            return false
        }
        if hasEditingTextBox {
            return
        }

        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let endLocation = screenToCanvas(value.location, geometry: geometry)

        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))

        if dragDistance < 12.0 {
            createNewTextAt(location: startLocation)
            return
        }

        let minX = min(startLocation.x, endLocation.x)
        let minY = min(startLocation.y, endLocation.y)
        let maxX = max(startLocation.x, endLocation.x)
        let maxY = max(startLocation.y, endLocation.y)

        let width = maxX - minX
        let height = maxY - minY

        let finalWidth = max(width, 50.0)
        let finalHeight = max(height, 30.0)


        createNewTextWithSize(at: CGPoint(x: minX, y: minY), width: finalWidth, height: finalHeight)
    }

    func resetTextBoxDrawingState() {
        isDrawing = false
        currentPath = nil
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
        drawingStartPoint = nil
    }

    private func isLocationOnTextResizeHandle(_ location: CGPoint) -> Bool {
        let handleRadius: Double = 6.0
        let tolerance: Double = 15.0
        let totalTolerance = handleRadius + tolerance


        for unifiedObj in document.unifiedObjects {
            guard case .shape(let shape) = unifiedObj.objectType,
                  shape.isTextObject,
                  var textObj = VectorText.from(shape) else { continue }
            textObj.layerIndex = unifiedObj.layerIndex
            if !textObj.isVisible || textObj.isLocked { continue }


            let textBounds = CGRect(
                x: textObj.position.x + textObj.bounds.minX,
                y: textObj.position.y + textObj.bounds.minY,
                width: textObj.bounds.width,
                height: textObj.bounds.height
            )

            let handles = [
                CGPoint(x: textBounds.minX, y: textBounds.minY),
                CGPoint(x: textBounds.maxX, y: textBounds.minY),
                CGPoint(x: textBounds.minX, y: textBounds.maxY),
                CGPoint(x: textBounds.maxX, y: textBounds.maxY),

                CGPoint(x: textBounds.midX, y: textBounds.minY),
                CGPoint(x: textBounds.midX, y: textBounds.maxY),
                CGPoint(x: textBounds.minX, y: textBounds.midY),
                CGPoint(x: textBounds.maxX, y: textBounds.midY),
            ]

            for (_, handle) in handles.enumerated() {
                let distance = sqrt(pow(location.x - handle.x, 2) + pow(location.y - handle.y, 2))
                if distance <= totalTolerance {
                    return true
                }
            }

            let edgeTolerance: Double = 0.0
            let expandedBounds = textBounds.insetBy(dx: -edgeTolerance, dy: -edgeTolerance)

            if expandedBounds.contains(location) && !textBounds.insetBy(dx: edgeTolerance, dy: edgeTolerance).contains(location) {
                return true
            }
        }

        return false
    }
}
