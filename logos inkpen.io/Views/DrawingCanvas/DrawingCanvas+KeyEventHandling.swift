import SwiftUI
import AppKit
import Combine

extension DrawingCanvas {
    internal func setupKeyEventMonitoring() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { (event: NSEvent) -> NSEvent? in

            print("🟡 Canvas monitor received event: \(event.charactersIgnoringModifiers ?? "nil")")

            guard let keyWindow = NSApp.keyWindow,
                  keyWindow == event.window else {
                print("🟡 Canvas monitor: Not key window")
                return event
            }

            // 1) Find the active document
            guard let activeDoc = DrawingCanvasRegistry.shared.activeDocument else {
                print("🔴 No active document in registry")
                return event
            }

            // 2) Only handle events if this canvas owns the active document
            guard activeDoc === self.document else {
                print("🟡 Canvas monitor: Not my document")
                return event
            }

            print("🟢 Canvas monitor: This is my document!")

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
                    if activeDoc.currentTool == .selection && !self.isTemporaryDirectSelectionViaCommand {
                        self.isTemporaryDirectSelectionViaCommand = true
                        self.temporaryCommandPreviousTool = activeDoc.currentTool
                    }
                    else if shapeDrawingTools.contains(activeDoc.currentTool) && !self.isTemporarySelectionViaCommand {
                        self.isTemporarySelectionViaCommand = true
                        self.temporaryCommandPreviousTool = activeDoc.currentTool
                        activeDoc.currentTool = .selection
                    }
                } else {
                    if self.isTemporaryDirectSelectionViaCommand {
                        self.isTemporaryDirectSelectionViaCommand = false
                        if activeDoc.currentTool == .directSelection {
                            activeDoc.currentTool = self.temporaryCommandPreviousTool ?? .selection
                        }
                        if activeDoc.currentTool == .selection {
                            self.selectedPoints.removeAll()
                            self.selectedHandles.removeAll()
                            self.directSelectedShapeIDs.removeAll()
                            self.syncDirectSelectionWithDocument()
                        }
                        self.temporaryCommandPreviousTool = nil
                    }
                    if self.isTemporarySelectionViaCommand {
                        self.isTemporarySelectionViaCommand = false
                        if let previousTool = self.temporaryCommandPreviousTool {
                            activeDoc.currentTool = previousTool
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

                        if !activeDoc.selectedObjectIDs.isEmpty {
                            if characters == arrowUp {
                                activeDoc.selectNextObjectUp()
                                return nil
                            } else if characters == arrowDown {
                                activeDoc.selectNextObjectDown()
                                return nil
                            }
                        } else {
                            if characters == arrowUp {
                                self.selectPreviousLayer()
                                return nil
                            } else if characters == arrowDown {
                                self.selectNextLayer()
                                return nil
                            }
                        }
                    }

                    if event.modifierFlags.contains(.option) &&
                       !event.modifierFlags.contains(.control) &&
                       !event.modifierFlags.contains(.command) &&
                       !activeDoc.selectedObjectIDs.isEmpty {

                        if characters == arrowUp {
                            activeDoc.moveSelectedObjectsUp()
                            return nil
                        } else if characters == arrowDown {
                            activeDoc.moveSelectedObjectsDown()
                            return nil
                        }
                    }

                    if !event.modifierFlags.contains(.control) &&
                       !event.modifierFlags.contains(.command) &&
                       !event.modifierFlags.contains(.option) &&
                       activeDoc.currentTool == .selection {

                        print("🟢 Arrow key nudge - tool is selection, selectedIDs: \(activeDoc.selectedObjectIDs.count)")

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
                            let gridSpacing = activeDoc.gridSpacing
                            let nudgeAmount = CGVector(dx: direction.dx * gridSpacing, dy: direction.dy * gridSpacing)
                            print("🟢 Nudging by \(nudgeAmount)")
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

            // Space and Tab are handled by AppEventMonitor

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
        guard let activeDoc = DrawingCanvasRegistry.shared.activeDocument else { return }
        guard activeDoc.currentTool != .hand && !isTemporaryHandToolActive else { return }

        temporaryToolPreviousTool = activeDoc.currentTool
        isTemporaryHandToolActive = true

        activeDoc.currentTool = .hand

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
        guard let activeDoc = DrawingCanvasRegistry.shared.activeDocument else { return }
        guard isTemporaryHandToolActive, let previousTool = temporaryToolPreviousTool else { return }

        activeDoc.currentTool = previousTool
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

    internal func selectNextLayer() {
        guard let currentIndex = document.selectedLayerIndex else {
            if document.layers.count > 2 {
                document.selectedLayerIndex = 2
            }
            return
        }

        if currentIndex > 2 {
            document.selectedLayerIndex = currentIndex - 1
        }
    }

    internal func selectPreviousLayer() {
        guard let currentIndex = document.selectedLayerIndex else {
            if document.layers.count > 2 {
                document.selectedLayerIndex = document.layers.count - 1
            }
            return
        }

        if currentIndex < document.layers.count - 1 {
            document.selectedLayerIndex = currentIndex + 1
        }
    }

    internal func nudgeSelectedObjects(by nudgeAmount: CGVector) {
        guard !document.selectedObjectIDs.isEmpty else { return }

        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []

        for objectID in document.selectedObjectIDs {
            if let shape = document.findShape(by: objectID) {
                oldShapes[objectID] = shape
                objectIDs.append(objectID)
            }
        }

        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(var shape),
                     .warp(var shape),
                     .group(var shape),
                     .clipGroup(var shape),
                     .clipMask(var shape):
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
                case .text:
                    break
                }
            }
        }

        document.objectPositionUpdateTrigger.toggle()

        for objectID in objectIDs {
            if let updatedShape = document.findShape(by: objectID) {
                newShapes[objectID] = updatedShape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }
    }
}
