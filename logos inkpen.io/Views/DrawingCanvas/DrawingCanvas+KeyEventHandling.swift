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
        // IMPROVED: Local monitor that prevents beeping but allows modifier key commands
        // ENHANCED: Now also tracks flagsChanged for shift key constraints in transform tools
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            // Handle modifier key changes for transform tools
            if event.type == .flagsChanged {
                DispatchQueue.main.async {
                    self.isShiftPressed = event.modifierFlags.contains(.shift)
                    self.isOptionPressed = event.modifierFlags.contains(.option)
                    self.isCommandPressed = event.modifierFlags.contains(.command)
                    
                    // Debug logging for key state changes
                    if self.isShiftPressed {
                        print("⬆️ SHIFT KEY PRESSED: Transform constraints enabled")
                    }
                    if self.isOptionPressed {
                        print("⌥ OPTION KEY PRESSED: Path-based selection enabled")
                    }
                }
                return event // Let flagsChanged pass through normally
            }
            
            // PRECISE FIX: Only allow events for NSTextView that is actually first responder
            if let window = NSApp.keyWindow,
               let firstResponder = window.firstResponder,
               firstResponder is NSTextView {
                // NSTextView is first responder - let it handle naturally
                return event
            }
            
            // ALLOW MODIFIER KEY COMBINATIONS (Cmd+Z, Cmd+C, etc.) to pass through
            if event.modifierFlags.contains(.command) || 
               event.modifierFlags.contains(.option) || 
               event.modifierFlags.contains(.control) {
                // Let modifier key combinations pass through to menu commands
                return event
            }
            
            // FOR SINGLE KEY PRESSES: Consume the event to prevent beeping
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