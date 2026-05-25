import SwiftUI
import AppKit

final class AppEventMonitor {
    static let shared = AppEventMonitor()

    private var keyEventMonitor: Any?

    private let lock = NSLock()
    private(set) weak var activeDocument: VectorDocument?
    private var isSpacebarPressed = false

    private init() {
        setupKeyEventMonitoring()
    }

    func setActiveDocument(_ document: VectorDocument) {
        lock.lock()
        defer { lock.unlock() }
        activeDocument = document
    }

    private func setupKeyEventMonitoring() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] (event: NSEvent) -> NSEvent? in
            guard let self = self else { return event }
            guard let keyWindow = NSApp.keyWindow,
                  keyWindow == event.window else {
                return event
            }
            self.lock.lock()
            let activeDoc = self.activeDocument
            self.lock.unlock()
            guard let activeDoc = activeDoc else {
                return event
            }
            return self.handleKeyEvent(event, activeDoc: activeDoc)
        }
    }
    private var temporaryTool: DrawingTool?
    private var previousTool: DrawingTool?
    private var accumulatedNudgeOffset: CGVector = .zero
    private var lastNudgeTime: Date = Date.distantPast
    private var isNudging: Bool = false

    private func handleKeyEvent(_ event: NSEvent, activeDoc: VectorDocument) -> NSEvent? {
        if let window = NSApp.keyWindow,
           let firstResponder = window.firstResponder,
           firstResponder is NSTextView {
            return event
        }
        if event.type == .keyDown,
           let characters = event.charactersIgnoringModifiers,
           characters == " " {
            if !isSpacebarPressed && temporaryTool == nil {
                isSpacebarPressed = true
                previousTool = activeDoc.viewState.currentTool
                temporaryTool = .hand
                activeDoc.viewState.currentTool = .hand
            }
            return nil
        }
        if event.type == .keyUp,
           let characters = event.charactersIgnoringModifiers,
           characters == " " {
            isSpacebarPressed = false
            if let previous = previousTool, (temporaryTool == .hand || temporaryTool == .zoom) {
                activeDoc.viewState.currentTool = previous
                temporaryTool = nil
                previousTool = nil
            }
            return nil
        }
        if event.type == .flagsChanged {
            let cmdPressed = event.modifierFlags.contains(.command)
            if isSpacebarPressed && cmdPressed && temporaryTool == .hand {
                temporaryTool = .zoom
                activeDoc.viewState.currentTool = .zoom
            }
            else if isSpacebarPressed && !cmdPressed && temporaryTool == .zoom {
                temporaryTool = .hand
                activeDoc.viewState.currentTool = .hand
            }
            else if cmdPressed && !isSpacebarPressed && activeDoc.viewState.currentTool != .selection && temporaryTool == nil {
                previousTool = activeDoc.viewState.currentTool
                temporaryTool = .selection
                activeDoc.viewState.currentTool = .selection
            }
            else if !cmdPressed && temporaryTool == .selection {
                if let previous = previousTool {
                    activeDoc.viewState.currentTool = previous
                    temporaryTool = nil
                    previousTool = nil
                }
            }
        }
        if event.type == .keyDown,
           let characters = event.charactersIgnoringModifiers,
           characters == "\t" {
            activeDoc.viewState.selectedObjectIDs = []
            for newVectorObject in activeDoc.snapshot.objects.values {
                if case .text(let shape) = newVectorObject.objectType, shape.isEditing == true {
                    activeDoc.setTextEditingInUnified(id: shape.id, isEditing: false)
                }
            }
            return nil
        }
        if event.type == .keyDown,

           let characters = event.charactersIgnoringModifiers {
            let arrowUp = "\u{F700}"
            let arrowDown = "\u{F701}"
            let arrowLeft = "\u{F702}"
            let arrowRight = "\u{F703}"
            if [arrowUp, arrowDown, arrowLeft, arrowRight].contains(characters) {
                if !event.modifierFlags.contains(.control) &&
                   !event.modifierFlags.contains(.command) {
                    if activeDoc.viewState.selectedObjectIDs.isEmpty && activeDoc.viewState.selectedPoints.isEmpty {
                        return nil
                    }
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
                        let now = Date()
                        if now.timeIntervalSince(lastNudgeTime) > 0.5 {
                            accumulatedNudgeOffset = .zero
                            isNudging = false
                        }
                        lastNudgeTime = now
                        let gridSpacingInPoints = activeDoc.settings.gridSpacing * activeDoc.settings.unit.pointsPerUnit
                        let multiplier: CGFloat
                        if event.modifierFlags.contains(.shift) {
                            multiplier = 10.0
                        } else if event.modifierFlags.contains(.option) {
                            multiplier = 0.1
                        } else {
                            multiplier = 1.0
                        }
                        let nudgeAmount = CGVector(
                            dx: direction.dx * gridSpacingInPoints * multiplier,
                            dy: direction.dy * gridSpacingInPoints * multiplier
                        )
                        accumulatedNudgeOffset.dx += nudgeAmount.dx
                        accumulatedNudgeOffset.dy += nudgeAmount.dy
                        isNudging = true
                        let isDirectSelectWithPoints = activeDoc.viewState.currentTool == DrawingTool.directSelection && !activeDoc.viewState.selectedPoints.isEmpty
                        if !isDirectSelectWithPoints {
                            activeDoc.viewState.liveNudgeOffset = accumulatedNudgeOffset
                        }
                        return nil
                    }
                }
            }
        }
        if event.type == .keyUp,

           let characters = event.charactersIgnoringModifiers {
            let arrowUp = "\u{F700}"
            let arrowDown = "\u{F701}"
            let arrowLeft = "\u{F702}"
            let arrowRight = "\u{F703}"
            if [arrowUp, arrowDown, arrowLeft, arrowRight].contains(characters) && isNudging {
                if accumulatedNudgeOffset != .zero {
                    activeDoc.nudgeSelectedObjects(by: accumulatedNudgeOffset)
                }
                accumulatedNudgeOffset = .zero
                activeDoc.viewState.liveNudgeOffset = .zero
                isNudging = false
                return nil
            }
        }
        return event
    }
}
