import SwiftUI
import AppKit
import Combine

extension DrawingCanvas {
    internal func setupKeyEventMonitoring() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { (event: NSEvent) -> NSEvent? in

            if event.type == .keyDown {


            }

            if self.isEditingText {
                return event
            }

            if let window = NSApp.keyWindow,
               let firstResponder = window.firstResponder,
               firstResponder is NSTextView {
                return event
            }

            if event.type == .keyUp {
                if let characters = event.charactersIgnoringModifiers,
                   characters == " " {
                    self.deactivateTemporaryHandTool()
                    return nil
                }
                return event
            }

            if event.type == .flagsChanged {
                self.isShiftPressed = event.modifierFlags.contains(.shift)
                self.isOptionPressed = event.modifierFlags.contains(.option)
                self.isCommandPressed = event.modifierFlags.contains(.command)
                self.isControlPressed = event.modifierFlags.contains(.control)

                let shapeDrawingTools: [DrawingTool] = [.rectangle, .square, .roundedRectangle, .pill,
                                                         .circle, .ellipse, .oval, .egg, .cone,
                                                         .equilateralTriangle, .rightTriangle, .acuteTriangle, .isoscelesTriangle,
                                                         .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon]

                if self.isCommandPressed {
                    if self.document.currentTool == .selection && !self.isTemporaryDirectSelectionViaCommand {
                        self.isTemporaryDirectSelectionViaCommand = true
                        self.temporaryCommandPreviousTool = self.document.currentTool
                    }
                    // Temporarily switch to selection tool when command is pressed on shape drawing tools
                    else if shapeDrawingTools.contains(self.document.currentTool) && !self.isTemporarySelectionViaCommand {
                        self.isTemporarySelectionViaCommand = true
                        self.temporaryCommandPreviousTool = self.document.currentTool
                        self.document.currentTool = .selection
                    }
                } else {
                    if self.isTemporaryDirectSelectionViaCommand {
                        self.isTemporaryDirectSelectionViaCommand = false
                        if self.document.currentTool == .directSelection {
                            self.document.currentTool = self.temporaryCommandPreviousTool ?? .selection
                        }
                        if self.document.currentTool == .selection {
                            self.selectedPoints.removeAll()
                            self.selectedHandles.removeAll()
                            self.directSelectedShapeIDs.removeAll()
                            self.syncDirectSelectionWithDocument()
                            self.document.objectWillChange.send()
                        }
                        self.temporaryCommandPreviousTool = nil
                    }
                    // Switch back from selection tool to previous shape drawing tool
                    if self.isTemporarySelectionViaCommand {
                        self.isTemporarySelectionViaCommand = false
                        if let previousTool = self.temporaryCommandPreviousTool {
                            self.document.currentTool = previousTool
                        }
                        self.temporaryCommandPreviousTool = nil
                    }
                }

                return event
            }

            if let characters = event.charactersIgnoringModifiers {
                let arrowUp = "\u{F700}"
                let arrowDown = "\u{F701}"
                let arrowLeft = "\u{F702}"
                let arrowRight = "\u{F703}"

                if [arrowUp, arrowDown, arrowLeft, arrowRight].contains(characters) {

                    if event.modifierFlags.contains(.command) &&
                       !event.modifierFlags.contains(.control) &&
                       !event.modifierFlags.contains(.option) {

                        if characters == arrowUp {
                            self.document.selectNextObjectUp()
                            return nil
                        } else if characters == arrowDown {
                            self.document.selectNextObjectDown()
                            return nil
                        }
                    }

                    if event.modifierFlags.contains(.option) &&
                       !event.modifierFlags.contains(.control) &&
                       !event.modifierFlags.contains(.command) &&
                       !self.document.selectedObjectIDs.isEmpty {

                        if characters == arrowUp {
                            self.document.moveSelectedObjectsUp()
                            return nil
                        } else if characters == arrowDown {
                            self.document.moveSelectedObjectsDown()
                            return nil
                        }
                    }

                    if !event.modifierFlags.contains(.control) &&
                       !event.modifierFlags.contains(.command) &&
                       !event.modifierFlags.contains(.option) &&
                       self.document.currentTool == .selection {

                        var nudgeDirection: CGVector? = nil
                        switch characters {
                        case arrowUp:
                            nudgeDirection = CGVector(dx: 0, dy: -1)
                        case arrowDown:
                            nudgeDirection = CGVector(dx: 0, dy: 1)
                        case arrowLeft:
                            nudgeDirection = CGVector(dx: -1, dy: 0)
                        case arrowRight:
                            nudgeDirection = CGVector(dx: 1, dy: 0)
                        default:
                            break
                        }

                        if let direction = nudgeDirection {
                            let gridSpacing = self.document.gridSpacing
                            let nudgeAmount = CGVector(dx: direction.dx * gridSpacing, dy: direction.dy * gridSpacing)
                            self.nudgeSelectedObjects(by: nudgeAmount)
                            return nil
                        }
                    }
                }
            }

            if event.modifierFlags.contains(.command) ||
               event.modifierFlags.contains(.option) ||
               event.modifierFlags.contains(.control) {
                return event
            }

            if let characters = event.charactersIgnoringModifiers,
               characters == " " {
                activateTemporaryHandTool()
                return nil
            }

            if let characters = event.charactersIgnoringModifiers,
               characters == "\t" {
                self.document.selectedObjectIDs.removeAll()

                self.document.syncSelectionArrays()

                if self.isEditingText {
                    self.finishTextEditing()
                }

                for unifiedObj in self.document.unifiedObjects {
                    if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject, shape.isEditing == true {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                    }
                }

                self.selectedPoints.removeAll()
                self.selectedHandles.removeAll()
                self.directSelectedShapeIDs.removeAll()
                self.syncDirectSelectionWithDocument()
                self.isCornerRadiusEditMode = false

                if self.document.currentTool == .bezierPen && self.isBezierDrawing {
                    self.finishBezierPath()
                }

                self.document.objectWillChange.send()

                return nil
            }

            let toolSwitchingKeys = Set(["a", "d", "c", "s", "r", "x", "w", "p", "f", "b", "m", "t", "l", "e", "o", "i", "h", "z", "g", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])

            if let characters = event.charactersIgnoringModifiers?.lowercased(),
               toolSwitchingKeys.contains(characters) {
                return event
            }

            return nil
        }
    }

    internal func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    internal func setupToolKeyboardShortcuts() {
    }

    internal func updateModifierKeyStates(with event: NSEvent) {
    }


    internal func activateTemporaryHandTool() {
        guard document.currentTool != .hand && !isTemporaryHandToolActive else { return }

        temporaryToolPreviousTool = document.currentTool
        isTemporaryHandToolActive = true

        document.currentTool = .hand

        if isCanvasHovering {
            HandOpenCursor.set()

            DispatchQueue.main.async {
                if self.isTemporaryHandToolActive && self.isCanvasHovering {
                    HandOpenCursor.set()
                }
            }
        }
    }

    internal func deactivateTemporaryHandTool() {
        guard isTemporaryHandToolActive, let previousTool = temporaryToolPreviousTool else { return }

        document.currentTool = previousTool
        isTemporaryHandToolActive = false
        temporaryToolPreviousTool = nil

        if isCanvasHovering {
            switch previousTool {
            case .hand:
                HandOpenCursor.set()
            case .eyedropper:
                EyedropperCursor.set()
            case .selectSameColor:
                EyedropperCursor.set()
            case .zoom:
                MagnifyingGlassCursor.set()
            case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                CrosshairCursor.set()
            default:
                NSCursor.arrow.set()
            }

            DispatchQueue.main.async {
                if self.isCanvasHovering && !self.isTemporaryHandToolActive {
                    switch previousTool {
                    case .hand:
                        HandOpenCursor.set()
                    case .eyedropper:
                        EyedropperCursor.set()
                    case .selectSameColor:
                        EyedropperCursor.set()
                    case .zoom:
                        MagnifyingGlassCursor.set()
                    case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                        CrosshairCursor.set()
                    default:
                        NSCursor.arrow.set()
                    }
                }
            }
        }
    }


    internal func nudgeSelectedObjects(by nudgeAmount: CGVector) {
        guard !document.selectedObjectIDs.isEmpty else { return }

        document.saveToUndoStack()

        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(var shape):
                    if shape.isGroupContainer {
                        var nudgedGroupedShapes: [VectorShape] = []
                        for var groupedShape in shape.groupedShapes {
                            var nudgedElements: [PathElement] = []
                            for element in groupedShape.path.elements {
                                switch element {
                                case .move(let to):
                                    nudgedElements.append(.move(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                                case .line(let to):
                                    nudgedElements.append(.line(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                                case .curve(let to, let c1, let c2):
                                    nudgedElements.append(.curve(
                                        to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                        control1: VectorPoint(c1.x + nudgeAmount.dx, c1.y + nudgeAmount.dy),
                                        control2: VectorPoint(c2.x + nudgeAmount.dx, c2.y + nudgeAmount.dy)
                                    ))
                                case .quadCurve(let to, let c):
                                    nudgedElements.append(.quadCurve(
                                        to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                        control: VectorPoint(c.x + nudgeAmount.dx, c.y + nudgeAmount.dy)
                                    ))
                                case .close:
                                    nudgedElements.append(.close)
                                }
                            }
                            groupedShape.path = VectorPath(elements: nudgedElements, isClosed: groupedShape.path.isClosed)
                            groupedShape.updateBounds()
                            nudgedGroupedShapes.append(groupedShape)
                        }
                        shape.groupedShapes = nudgedGroupedShapes
                        shape.updateBounds()
                    } else {
                        var nudgedElements: [PathElement] = []
                        for element in shape.path.elements {
                            switch element {
                            case .move(let to):
                                nudgedElements.append(.move(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                            case .line(let to):
                                nudgedElements.append(.line(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                            case .curve(let to, let c1, let c2):
                                nudgedElements.append(.curve(
                                    to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                    control1: VectorPoint(c1.x + nudgeAmount.dx, c1.y + nudgeAmount.dy),
                                    control2: VectorPoint(c2.x + nudgeAmount.dx, c2.y + nudgeAmount.dy)
                                ))
                            case .quadCurve(let to, let c):
                                nudgedElements.append(.quadCurve(
                                    to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                    control: VectorPoint(c.x + nudgeAmount.dx, c.y + nudgeAmount.dy)
                                ))
                            case .close:
                                nudgedElements.append(.close)
                            }
                        }
                        shape.path = VectorPath(elements: nudgedElements, isClosed: shape.path.isClosed)
                        shape.updateBounds()
                    }

                    document.updateEntireShapeInUnified(id: shape.id) { updatedShape in
                        updatedShape = shape
                    }
                }
            }
        }

        document.objectPositionUpdateTrigger.toggle()

        document.objectWillChange.send()
    }
}
