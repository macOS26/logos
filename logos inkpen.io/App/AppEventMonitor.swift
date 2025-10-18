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

    private func handleKeyEvent(_ event: NSEvent, activeDoc: VectorDocument) -> NSEvent? {

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

        return event
    }
}
