import SwiftUI
import AppKit

// One LOCAL event monitor shared across the entire app (not global/system-wide)
final class AppEventMonitor {
    static let shared = AppEventMonitor()
    private var keyEventMonitor: Any?

    private init() {
        setupKeyEventMonitoring()
    }

    private func setupKeyEventMonitoring() {
        // LOCAL monitor - only monitors events in our app, not system-wide
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { (event: NSEvent) -> NSEvent? in

            guard let keyWindow = NSApp.keyWindow,
                  keyWindow == event.window else {
                return event
            }

            // Get the active document from registry
            guard let activeDoc = DrawingCanvasRegistry.shared.activeDocument else {
                return event
            }

            // Handle the event using the active document
            return self.handleKeyEvent(event, activeDoc: activeDoc)
        }
    }

    private var temporaryTool: DrawingTool?
    private var previousTool: DrawingTool?

    private func handleKeyEvent(_ event: NSEvent, activeDoc: VectorDocument) -> NSEvent? {

        // Don't intercept events when editing text
        if let window = NSApp.keyWindow,
           let firstResponder = window.firstResponder,
           firstResponder is NSTextView {
            return event
        }

        // Space bar - temporary hand tool
        if event.type == .keyDown,
           let characters = event.charactersIgnoringModifiers,
           characters == " " {
            if activeDoc.currentTool != .hand && temporaryTool == nil {
                previousTool = activeDoc.currentTool
                temporaryTool = .hand
                activeDoc.currentTool = .hand
            }
            return nil
        }

        if event.type == .keyUp,
           let characters = event.charactersIgnoringModifiers,
           characters == " " {
            if let previous = previousTool, temporaryTool == .hand {
                activeDoc.currentTool = previous
                temporaryTool = nil
                previousTool = nil
            }
            return nil
        }

        // Tab key - deselect all
        if event.type == .keyDown,
           let characters = event.charactersIgnoringModifiers,
           characters == "\t" {
            activeDoc.selectedObjectIDs = []
            activeDoc.syncSelectionArrays()

            // Clear text editing state
            for unifiedObj in activeDoc.unifiedObjects {
                if case .text(let shape) = unifiedObj.objectType, shape.isEditing == true {
                    activeDoc.setTextEditingInUnified(id: shape.id, isEditing: false)
                }
            }

            return nil
        }

        // Arrow keys
        if event.type == .keyDown,
           let characters = event.charactersIgnoringModifiers {
            let arrowUp = "\u{F700}"
            let arrowDown = "\u{F701}"
            let arrowLeft = "\u{F702}"
            let arrowRight = "\u{F703}"

            if [arrowUp, arrowDown, arrowLeft, arrowRight].contains(characters) {
                print("🔷 Arrow key pressed - tool: \(activeDoc.currentTool), selected: \(activeDoc.selectedObjectIDs.count)")

                // Cmd+Arrow: Z-order and selection navigation
                if event.modifierFlags.contains(.command) &&
                   !event.modifierFlags.contains(.control) &&
                   !event.modifierFlags.contains(.option) {

                    if !activeDoc.selectedObjectIDs.isEmpty {
                        if characters == arrowUp {
                            activeDoc.selectNextObjectDown()
                            return nil
                        } else if characters == arrowDown {
                            activeDoc.selectNextObjectUp()
                            return nil
                        }
                    }
                }

                // Option+Arrow: Move objects up/down in z-order
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

                // Plain or Shift+arrows: Nudge selected objects (works with any tool)
                if !event.modifierFlags.contains(.control) &&
                   !event.modifierFlags.contains(.command) &&
                   !event.modifierFlags.contains(.option) {

                    print("🔷 Plain arrow - attempting to nudge")

                    // Only nudge if something is selected, but consume the event regardless
                    if activeDoc.selectedObjectIDs.isEmpty {
                        print("🔷 No objects selected - consuming event")
                        return nil
                    }

                    print("🔷 Nudging \(activeDoc.selectedObjectIDs.count) objects")

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
                        // Convert grid spacing from document units to points
                        let gridSpacingInPoints = activeDoc.settings.gridSpacing * activeDoc.settings.unit.pointsPerUnit

                        // Shift key = 10x nudge
                        let multiplier: CGFloat = event.modifierFlags.contains(.shift) ? 10.0 : 1.0

                        let nudgeAmount = CGVector(
                            dx: direction.dx * gridSpacingInPoints * multiplier,
                            dy: direction.dy * gridSpacingInPoints * multiplier
                        )
                        activeDoc.nudgeSelectedObjects(by: nudgeAmount)
                        return nil
                    }
                }
            }
        }

        return event
    }
}
