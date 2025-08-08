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
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { (event: NSEvent) -> NSEvent? in
            // Handle key up events for temporary tool deactivation
            if event.type == .keyUp {
                // Handle spacebar release for temporary hand tool deactivation
                if let characters = event.charactersIgnoringModifiers,
                   characters == " " {
                    self.deactivateTemporaryHandTool()
                    return nil // Consume the event
                }
                return event // Let other keyUp events pass through
            }
            
            // Handle modifier key changes for transform tools
            if event.type == .flagsChanged {
                // FIXED: Remove async dispatch to prevent race conditions during rapid key events
                // Update modifier states immediately for reliable corner radius tool behavior
                self.isShiftPressed = event.modifierFlags.contains(.shift)
                self.isOptionPressed = event.modifierFlags.contains(.option)
                self.isCommandPressed = event.modifierFlags.contains(.command)
                self.isControlPressed = event.modifierFlags.contains(.control)
                
                // Debug logging for key state changes
                if self.isShiftPressed {
                    print("⬆️ SHIFT KEY PRESSED: Transform constraints enabled (immediate)")
                } else {
                    print("⬆️ SHIFT KEY RELEASED: Transform constraints disabled (immediate)")
                }
                if self.isOptionPressed {
                    print("⌥ OPTION KEY PRESSED: Path-based selection enabled")
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
            
            // HANDLE CONTROL+ARROW FOR CORNER RADIUS TOOL
            if event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.option) {
                if let characters = event.charactersIgnoringModifiers,
                   ["\u{63235}", "\u{63234}", "\u{63233}", "\u{63232}"].contains(characters) { // Arrow keys
                    // Activate corner radius tool
                    document.currentTool = .cornerRadius
                    print("🔧 CONTROL+ARROW: Activated corner radius tool")
                    return nil // Consume the event
                }
            }
            
            // ALLOW OTHER MODIFIER KEY COMBINATIONS (Cmd+Z, Cmd+C, etc.) to pass through
            if event.modifierFlags.contains(.command) || 
               event.modifierFlags.contains(.option) || 
               event.modifierFlags.contains(.control) {
                // Let modifier key combinations pass through to menu commands
                return event
            }
            
            // HANDLE SPACEBAR FOR TEMPORARY HAND TOOL
            if let characters = event.charactersIgnoringModifiers,
               characters == " " {
                // Handle spacebar for temporary hand tool activation
                activateTemporaryHandTool()
                return nil // Consume the event to prevent system handling
            }
            
            // ALLOW TOOL SWITCHING SHORTCUTS to pass through
            // These are single key presses that should trigger tool switching
            let toolSwitchingKeys = Set(["a", "d", "c", "s", "r", "x", "w", "p", "f", "b", "m", "t", "l", "e", "o", "i", "h", "z", "g", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
            
            if let characters = event.charactersIgnoringModifiers?.lowercased(),
               toolSwitchingKeys.contains(characters) {
                // Let tool switching shortcuts pass through to the menu system
                return event
            }
            
            // FOR OTHER SINGLE KEY PRESSES: Consume the event to prevent beeping
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
    
    // MARK: - Temporary Hand Tool (Spacebar)
    
    /// Temporarily activate hand tool when spacebar is pressed
    internal func activateTemporaryHandTool() {
        // Only activate if not already using hand tool and not in temporary mode
        guard document.currentTool != .hand && !isTemporaryHandToolActive else { return }
        
        // Store the current tool to restore later
        temporaryToolPreviousTool = document.currentTool
        isTemporaryHandToolActive = true
        
        // Switch to hand tool
        document.currentTool = .hand
        
        print("✋ SPACEBAR: Temporary Hand Tool activated from \(temporaryToolPreviousTool?.rawValue ?? "unknown")")
    }
    
    /// Deactivate temporary hand tool when spacebar is released
    internal func deactivateTemporaryHandTool() {
        // Only deactivate if in temporary mode
        guard isTemporaryHandToolActive, let previousTool = temporaryToolPreviousTool else { return }
        
        // Restore the previous tool
        document.currentTool = previousTool
        isTemporaryHandToolActive = false
        temporaryToolPreviousTool = nil
        
        print("✋ SPACEBAR: Temporary Hand Tool deactivated, restored to \(previousTool.rawValue)")
    }
} 