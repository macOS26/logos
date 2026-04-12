import SwiftUI
import AppKit

// One LOCAL event monitor shared across the entire app (not global/system-wide)
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
        print("🎯 AppEventMonitor: activeDocument set to \(ObjectIdentifier(document))")
    }

    private func setupKeyEventMonitoring() {
        // LOCAL monitor - only monitors events in our app, not system-wide
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] (event: NSEvent) -> NSEvent? in
            guard let self = self else { return event }

            guard let keyWindow = NSApp.keyWindow,
                  keyWindow == event.window else {
                return event
            }

            // Get the active document (read fresh from property each time)
            self.lock.lock()
            let activeDoc = self.activeDocument
            self.lock.unlock()

            guard let activeDoc = activeDoc else {
                return event
            }

            // Handle the event using the active document
            return self.handleKeyEvent(event, activeDoc: activeDoc)
        }
    }

    private var temporaryTool: DrawingTool?
    private var previousTool: DrawingTool?

    // Nudge state tracking
    private var accumulatedNudgeOffset: CGVector = .zero
    private var lastNudgeTime: Date = Date.distantPast
    private var isNudging: Bool = false

    private func handleKeyEvent(_ event: NSEvent, activeDoc: VectorDocument) -> NSEvent? {

        // Don't intercept events when editing text
        if let window = NSApp.keyWindow,
           let firstResponder = window.firstResponder,
           firstResponder is NSTextView {
            return event
        }

        // Space bar - temporary hand tool (or zoom if Cmd is then pressed)
        if event.type == .keyDown,
           let characters = event.charactersIgnoringModifiers,
           characters == " " {
            // Only activate on first press, ignore repeats
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

        // Modifier key changes
        if event.type == .flagsChanged {
            let cmdPressed = event.modifierFlags.contains(.command)

            // Space + Cmd = zoom tool (classic graphics software behavior)
            // Press Space first to get hand tool, then add Cmd to switch to zoom
            if isSpacebarPressed && cmdPressed && temporaryTool == .hand {
                temporaryTool = .zoom
                activeDoc.viewState.currentTool = .zoom
            }
            // Space held but Cmd released = back to hand tool
            else if isSpacebarPressed && !cmdPressed && temporaryTool == .zoom {
                temporaryTool = .hand
                activeDoc.viewState.currentTool = .hand
            }
            // Cmd alone (no space) = temporary selection tool
            else if cmdPressed && !isSpacebarPressed && activeDoc.viewState.currentTool != .selection && temporaryTool == nil {
                previousTool = activeDoc.viewState.currentTool
                temporaryTool = .selection
                activeDoc.viewState.currentTool = .selection
            }
            // Cmd released (no space) = restore previous tool
            else if !cmdPressed && temporaryTool == .selection {
                if let previous = previousTool {
                    activeDoc.viewState.currentTool = previous
                    temporaryTool = nil
                    previousTool = nil
                }
            }
        }

        // Tab key - deselect all
        if event.type == .keyDown,
           let characters = event.charactersIgnoringModifiers,
           characters == "\t" {
            activeDoc.viewState.selectedObjectIDs = []

            // Clear text editing state
            for newVectorObject in activeDoc.snapshot.objects.values {
                if case .text(let shape) = newVectorObject.objectType, shape.isEditing == true {
                    activeDoc.setTextEditingInUnified(id: shape.id, isEditing: false)
                }
            }

            return nil
        }

        // Arrow keys - keyDown accumulates offset
        if event.type == .keyDown,
           let characters = event.charactersIgnoringModifiers {
            let arrowUp = "\u{F700}"
            let arrowDown = "\u{F701}"
            let arrowLeft = "\u{F702}"
            let arrowRight = "\u{F703}"

            if [arrowUp, arrowDown, arrowLeft, arrowRight].contains(characters) {
                // Plain, Shift, or Option+arrows: Nudge selected objects (works with any tool)
                if !event.modifierFlags.contains(.control) &&
                   !event.modifierFlags.contains(.command) {

                    // Only nudge if something is selected (objects or points), but consume the event regardless
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
                        // Reset if new nudge session (> 0.5s since last nudge)
                        let now = Date()
                        if now.timeIntervalSince(lastNudgeTime) > 0.5 {
                            accumulatedNudgeOffset = .zero
                            isNudging = false
                        }
                        lastNudgeTime = now

                        // Convert grid spacing from document units to points
                        let gridSpacingInPoints = activeDoc.settings.gridSpacing * activeDoc.settings.unit.pointsPerUnit

                        // Shift key = 10x nudge, Option key = 1/10th nudge
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

                        // Accumulate offset
                        accumulatedNudgeOffset.dx += nudgeAmount.dx
                        accumulatedNudgeOffset.dy += nudgeAmount.dy
                        isNudging = true

                        // Direct selection with points selected: only nudge points (no live shape offset)
                        // Direct selection with NO points: move whole shape (apply live offset)
                        let isDirectSelectWithPoints = activeDoc.viewState.currentTool == DrawingTool.directSelection && !activeDoc.viewState.selectedPoints.isEmpty
                        if !isDirectSelectWithPoints {
                            // Apply live offset to viewState for whole-shape nudging
                            activeDoc.viewState.liveNudgeOffset = accumulatedNudgeOffset
                        }

                        return nil
                    }
                }
            }
        }

        // Arrow keys - keyUp commits the accumulated offset
        if event.type == .keyUp,
           let characters = event.charactersIgnoringModifiers {
            let arrowUp = "\u{F700}"
            let arrowDown = "\u{F701}"
            let arrowLeft = "\u{F702}"
            let arrowRight = "\u{F703}"

            if [arrowUp, arrowDown, arrowLeft, arrowRight].contains(characters) && isNudging {
                // Commit the accumulated offset
                if accumulatedNudgeOffset != .zero {
                    activeDoc.nudgeSelectedObjects(by: accumulatedNudgeOffset)
                }

                // Reset state
                accumulatedNudgeOffset = .zero
                activeDoc.viewState.liveNudgeOffset = .zero
                isNudging = false

                return nil
            }
        }

        return event
    }
}
