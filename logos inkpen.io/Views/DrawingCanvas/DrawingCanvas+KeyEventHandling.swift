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
        // REMOVED: NSEvent keyboard monitoring was disabled to fix text input issues
        // All keyboard shortcuts have been removed to prevent interference with NSTextView
    }
    
    internal func updateModifierKeyStates(with event: NSEvent) {
        // REMOVED: This method is no longer used since NSEvent monitoring was disabled
        // to fix text input conflicts with NSTextView
    }
} 