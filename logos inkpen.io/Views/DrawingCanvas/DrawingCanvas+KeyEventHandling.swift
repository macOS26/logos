//
//  DrawingCanvas+KeyEventHandling.swift
//  logos inkpen.io
//
//  Key event handling functionality
//

import SwiftUI
import AppKit

extension DrawingCanvas {
    // MARK: - BEEP PREVENTION - Local Monitor to Handle All Key Events
    internal func setupKeyEventMonitoring() {
        // SIMPLE FIX: Local monitor that prevents beeping by handling all key events
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // PRECISE FIX: Only allow events for NSTextView that is actually first responder
            if let window = NSApp.keyWindow,
               let firstResponder = window.firstResponder,
               firstResponder is NSTextView {
                // NSTextView is first responder - let it handle naturally
                return event
            }
            
            // FOR ALL OTHER CASES: Consume the event to prevent beeping
            // This tells macOS "we handled this event, don't make error sound"
            return nil
        }
    }
    
    internal func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    // PROFESSIONAL TOOL KEYBOARD SHORTCUTS (Adobe Illustrator Standards)
    internal func setupToolKeyboardShortcuts() {
        // DISABLED: NSEvent monitoring completely to fix text input issues
        // NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        //     // CRITICAL FIX: Don't interfere with NSTextView text input
        //     if let window = NSApp.keyWindow,
        //        let firstResponder = window.firstResponder,
        //        firstResponder is NSTextView {
        //         // Text view is active - let it handle the event naturally
        //         return event
        //     }
        //     
        //     // TEXT EDITING REMOVED - All shortcuts now active
        //     
        //     let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""
        //     let modifiers = event.modifierFlags
        //     
        //     // PROFESSIONAL COMMAND SHORTCUTS (Adobe Illustrator Standards)
        //     if modifiers.contains(.command) {
        //         switch characters {
        //         case "a": // Select All (Cmd+A)
        //             self.document.selectAll()
        //             return event
        //         case "t": // Test Coordinate System (Cmd+Shift+T) - DEBUG ONLY
        //             if modifiers.contains(.shift) {
        //                 print("🔬 RUNNING COORDINATE SYSTEM TEST:")
        //                 print("=" + String(repeating: "=", count: 58))
        //                 self.runCoordinateSystemTest()
        //                 return event
        //             }
        //         case "d": // Test Drawing Stability (Cmd+Shift+D) - DEBUG ONLY
        //             if modifiers.contains(.shift) {
        //                 self.runDrawingStabilityTest()
        //                 return event
        //             }
        //         case "r": // Real Drawing Test (Cmd+Shift+R) - DEBUG ONLY
        //             if modifiers.contains(.shift) {
        //                 self.runRealDrawingTestSimple()
        //                 return event
        //             }
        //         default:
        //             break
        //         }
        //     }
        //     
        //     return event
        // }
    }
    
    internal func updateModifierKeyStates(with event: NSEvent) {
        // DISABLED: NSEvent monitoring is turned off, so this method won't be called
        // Keeping method for future re-enabling if needed
        /*
        let modifierFlags = event.modifierFlags
        isShiftPressed = modifierFlags.contains(.shift)
        isCommandPressed = modifierFlags.contains(.command)
        isOptionPressed = modifierFlags.contains(.option)
        
        // REMOVED OLD TEXT EDITING CODE - ProfessionalTextCanvas handles text input now
        // The old manual text editing system was conflicting with NSTextView
        
        // Handle Tab key for deselection (only if not editing text)
        if event.type == .keyDown && !isEditingText {
            switch event.keyCode {
            case 48: // Tab key
                // Deselect all objects
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                directSelectedShapeIDs.removeAll()
                document.objectWillChange.send()
                print("✅ Tab pressed - deselected all objects")
            default:
                break
            }
        }
        */
    }
} 