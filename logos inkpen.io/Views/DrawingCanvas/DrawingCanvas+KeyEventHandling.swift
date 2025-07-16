//
//  DrawingCanvas+KeyEventHandling.swift
//  logos inkpen.io
//
//  Key event handling functionality
//

import SwiftUI
import AppKit

extension DrawingCanvas {
    // MARK: - Professional Multi-Selection Key Monitoring (Adobe Illustrator Standards)
    internal func setupKeyEventMonitoring() {
        // Monitor for key down/up and modifier flag changes
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            DispatchQueue.main.async {
                self.updateModifierKeyStates(with: event)
            }
            return event
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
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // TEXT EDITING REMOVED - All shortcuts now active
            
            let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""
            let modifiers = event.modifierFlags
            
            // PROFESSIONAL COMMAND SHORTCUTS (Adobe Illustrator Standards)
            if modifiers.contains(.command) {
                switch characters {
                case "a": // Select All (Cmd+A)
                    self.document.selectAll()
                    return event
                case "t": // Test Coordinate System (Cmd+Shift+T) - DEBUG ONLY
                    if modifiers.contains(.shift) {
                        print("🔬 RUNNING COORDINATE SYSTEM TEST:")
                        print("=" + String(repeating: "=", count: 58))
                        self.runCoordinateSystemTest()
                        return event
                    }
                case "d": // Test Drawing Stability (Cmd+Shift+D) - DEBUG ONLY
                    if modifiers.contains(.shift) {
                        self.runDrawingStabilityTest()
                        return event
                    }
                case "r": // Real Drawing Test (Cmd+Shift+R) - DEBUG ONLY
                    if modifiers.contains(.shift) {
                        self.runRealDrawingTestSimple()
                        return event
                    }
                default:
                    break
                }
            }
            
            return event
        }
    }
    
    internal func updateModifierKeyStates(with event: NSEvent) {
        let modifierFlags = event.modifierFlags
        isShiftPressed = modifierFlags.contains(.shift)
        isCommandPressed = modifierFlags.contains(.command)
        isOptionPressed = modifierFlags.contains(.option)
        
        // FONT TOOL TEXT EDITING
        if event.type == .keyDown && isEditingText, let editingID = editingTextID {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }) {
                var updatedText = document.textObjects[textIndex]
                
                switch event.keyCode {
                case 51: // Delete key
                    if !updatedText.content.isEmpty {
                        updatedText.content.removeLast()
                        updatedText.updateBounds() // SURGICAL FIX: Update bounds for dynamic sizing
                        document.textObjects[textIndex] = updatedText
                        document.objectWillChange.send()
                    }
                case 36, 76: // Return/Enter key
                    // Finish editing
                    finishTextEditing()
                case 53: // Escape key
                    // Cancel editing
                    cancelTextEditing()
                default:
                    // Regular character input
                    if let characters = event.characters, !characters.isEmpty {
                        // Filter out control characters
                        let filteredChars = characters.filter { $0.isLetter || $0.isNumber || $0.isPunctuation || $0.isSymbol || $0.isWhitespace }
                        if !filteredChars.isEmpty {
                            updatedText.content.append(String(filteredChars))
                            updatedText.updateBounds() // SURGICAL FIX: Update bounds for dynamic sizing
                            document.textObjects[textIndex] = updatedText
                            document.objectWillChange.send()
                        }
                    }
                }
            }
            return
        }
        
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
    }
} 